/// SharedSiteService - Downloads sites shared with the current user
///
/// Flow:
/// 1. Computes SHA256 hash of user's email (same as Cloud Function)
/// 2. Gets shared_access/{emailHash} document (single document per user)
/// 3. Reads sites map: { siteId: ownerUID, ... }
/// 4. Downloads each site from Profile/{ownerUID}/Sites/{siteId}
/// 5. Downloads snags under each site
/// 6. Saves to local SQLite database
///
/// Security:
/// - Firestore rules verify email field matches requesting user on get()
/// - Single document structure enables secure get() instead of list() query
/// - Only sites explicitly shared with user are discoverable

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/site.dart';
import 'package:snagsnapper/Data/models/snag.dart';

/// Result of a shared site download operation
class SharedSiteDownloadResult {
  final int sitesDownloaded;
  final int snagsDownloaded;
  final int errors;
  final List<String> errorMessages;

  SharedSiteDownloadResult({
    required this.sitesDownloaded,
    required this.snagsDownloaded,
    required this.errors,
    required this.errorMessages,
  });

  bool get hasErrors => errors > 0;
  bool get isEmpty => sitesDownloaded == 0 && snagsDownloaded == 0;

  String get summary {
    if (isEmpty && !hasErrors) {
      return 'No new shared sites found';
    }
    final parts = <String>[];
    if (sitesDownloaded > 0) {
      parts.add('$sitesDownloaded site${sitesDownloaded == 1 ? '' : 's'}');
    }
    if (snagsDownloaded > 0) {
      parts.add('$snagsDownloaded snag${snagsDownloaded == 1 ? '' : 's'}');
    }
    if (hasErrors) {
      parts.add('$errors error${errors == 1 ? '' : 's'}');
    }
    return 'Downloaded ${parts.join(', ')}';
  }
}

class SharedSiteService {
  static final SharedSiteService _instance = SharedSiteService._internal();
  factory SharedSiteService() => _instance;
  SharedSiteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppDatabase _database = AppDatabase.instance;

  /// Hash email using SHA256 (must match Cloud Function implementation)
  /// Email is normalized (lowercase, trimmed) before hashing
  String _hashEmail(String email) {
    final normalized = email.toLowerCase().trim();
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString(); // Returns 64-char hex string
  }

  /// Check and download all sites shared with the current user
  Future<SharedSiteDownloadResult> checkAndDownloadSharedSites({
    void Function(String status)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return SharedSiteDownloadResult(
        sitesDownloaded: 0,
        snagsDownloaded: 0,
        errors: 1,
        errorMessages: ['User not signed in'],
      );
    }

    final userEmail = user.email!;
    final emailHash = _hashEmail(userEmail);

    if (kDebugMode) {
      print('SharedSiteService: Checking shared sites for $userEmail');
      print('SharedSiteService: Email hash: $emailHash');
    }

    onProgress?.call('Checking for shared sites...');

    int sitesDownloaded = 0;
    int snagsDownloaded = 0;
    int errors = 0;
    final errorMessages = <String>[];

    try {
      // Get single shared_access document for this user
      final sharedAccessDoc = await _firestore
          .collection('shared_access')
          .doc(emailHash)
          .get();

      if (!sharedAccessDoc.exists) {
        if (kDebugMode) {
          print('SharedSiteService: No shared_access document found');
        }
        onProgress?.call('No shared sites found');
        return SharedSiteDownloadResult(
          sitesDownloaded: 0,
          snagsDownloaded: 0,
          errors: 0,
          errorMessages: [],
        );
      }

      final data = sharedAccessDoc.data()!;
      final sites = data['sites'] as Map<String, dynamic>? ?? {};

      if (kDebugMode) {
        print('SharedSiteService: Found ${sites.length} shared site references');
      }

      if (sites.isEmpty) {
        onProgress?.call('No shared sites found');
        return SharedSiteDownloadResult(
          sitesDownloaded: 0,
          snagsDownloaded: 0,
          errors: 0,
          errorMessages: [],
        );
      }

      // Process each shared site reference
      // sites = { "siteId1": "ownerUID1", "siteId2": "ownerUID2", ... }
      for (final entry in sites.entries) {
        final siteId = entry.key;
        final ownerUID = entry.value as String?;

        if (ownerUID == null) {
          errors++;
          errorMessages.add('Missing ownerUID for site $siteId');
          continue;
        }

        onProgress?.call('Downloading site...');

        try {
          // Download site document
          final siteDoc = await _firestore
              .collection('Profile')
              .doc(ownerUID)
              .collection('Sites')
              .doc(siteId)
              .get();

          if (!siteDoc.exists) {
            if (kDebugMode) {
              print('SharedSiteService: Site $siteId not found in Firestore');
            }
            // Site may have been deleted - remove the local copy if exists
            continue;
          }

          final siteData = siteDoc.data()!;

          // Check if user still has access
          final sharedWith = siteData['sharedWith'] as Map<String, dynamic>? ?? {};
          if (!sharedWith.containsKey(userEmail.toLowerCase())) {
            if (kDebugMode) {
              print('SharedSiteService: User no longer has access to site $siteId');
            }
            continue;
          }

          // Convert to Site model
          final site = Site.fromFirestore(siteId, siteData);

          // Save to local database
          final existingSite = await _database.siteDao.getSiteById(siteId);
          if (existingSite == null) {
            await _database.siteDao.insertSite(site);
            sitesDownloaded++;
            if (kDebugMode) {
              print('SharedSiteService: Inserted new site: ${site.name}');
            }
          } else {
            // Update if remote is newer
            if (site.firebaseVersion > existingSite.firebaseVersion) {
              await _database.siteDao.updateSite(site);
              sitesDownloaded++;
              if (kDebugMode) {
                print('SharedSiteService: Updated site: ${site.name}');
              }
            }
          }

          // Download snags for this site
          onProgress?.call('Downloading snags for ${site.name}...');

          final snagsQuery = await _firestore
              .collection('Profile')
              .doc(ownerUID)
              .collection('Sites')
              .doc(siteId)
              .collection('Snags')
              .get();

          if (kDebugMode) {
            print('SharedSiteService: Found ${snagsQuery.docs.length} snags for site $siteId');
          }

          for (final snagDoc in snagsQuery.docs) {
            try {
              final snag = Snag.fromFirestore(snagDoc.id, snagDoc.data());

              final existingSnag = await _database.snagDao.getSnagById(snagDoc.id);
              if (existingSnag == null) {
                await _database.snagDao.insertSnag(snag);
                snagsDownloaded++;
              } else {
                // Update if remote is newer
                if (snag.firebaseVersion > existingSnag.firebaseVersion) {
                  await _database.snagDao.updateSnag(snag);
                  snagsDownloaded++;
                }
              }
            } catch (e) {
              errors++;
              errorMessages.add('Failed to process snag ${snagDoc.id}: $e');
              if (kDebugMode) {
                print('SharedSiteService: Error processing snag: $e');
              }
            }
          }

        } catch (e) {
          errors++;
          errorMessages.add('Failed to download site $siteId: $e');
          if (kDebugMode) {
            print('SharedSiteService: Error downloading site $siteId: $e');
          }
        }
      }

      onProgress?.call('Download complete');

    } catch (e) {
      errors++;
      errorMessages.add('Failed to query shared sites: $e');
      if (kDebugMode) {
        print('SharedSiteService: Error querying shared_access: $e');
      }
    }

    final result = SharedSiteDownloadResult(
      sitesDownloaded: sitesDownloaded,
      snagsDownloaded: snagsDownloaded,
      errors: errors,
      errorMessages: errorMessages,
    );

    if (kDebugMode) {
      print('SharedSiteService: ${result.summary}');
    }

    return result;
  }
}
