/// SharedSiteService - Downloads sites shared with the current user
///
/// Flow:
/// 1. Computes SHA256 hash of user's email (same as Cloud Function)
/// 2. Gets shared_access/{emailHash} document (single document per user)
/// 3. Reads sites map: { siteId: { ownerUID, version }, ... }
/// 4. Compares versions - skips fetch if local >= remote (RA 4.10)
/// 5. Downloads each site from Profile/{ownerUID}/Sites/{siteId}
/// 6. Downloads snags under each site
/// 7. Cleans up orphaned local sites not in shared_access (RA 2.7)
/// 8. Saves to local SQLite database
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
  final int sitesRemoved;
  final int errors;
  final List<String> errorMessages;

  SharedSiteDownloadResult({
    required this.sitesDownloaded,
    required this.snagsDownloaded,
    required this.sitesRemoved,
    required this.errors,
    required this.errorMessages,
  });

  bool get hasErrors => errors > 0;
  bool get isEmpty =>
      sitesDownloaded == 0 && snagsDownloaded == 0 && sitesRemoved == 0;

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
    if (sitesRemoved > 0) {
      parts.add('$sitesRemoved removed');
    }
    if (hasErrors) {
      parts.add('$errors error${errors == 1 ? '' : 's'}');
    }
    if (sitesDownloaded > 0 || snagsDownloaded > 0) {
      return 'Downloaded ${parts.join(', ')}';
    }
    return parts.join(', ');
  }
}

class SharedSiteService {
  static final SharedSiteService _instance = SharedSiteService._internal();
  factory SharedSiteService() => _instance;
  SharedSiteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppDatabase _database = AppDatabase.instance;

  /// Cooldown tracking (survives tab switches)
  static const int cooldownSeconds = 30;
  DateTime? _lastSyncTime;

  /// Get remaining cooldown seconds (0 if ready to sync)
  int get cooldownRemaining {
    if (_lastSyncTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastSyncTime!).inSeconds;
    final remaining = cooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Check if sync is allowed
  bool get canSync => cooldownRemaining == 0;

  /// Record sync completion time
  void recordSyncTime() {
    _lastSyncTime = DateTime.now();
  }

  /// Hash email using SHA256 (must match Cloud Function implementation)
  /// Email is normalized (lowercase, trimmed) before hashing
  String _hashEmail(String email) {
    final normalized = email.toLowerCase().trim();
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString(); // Returns 64-char hex string
  }

  /// Check and download all sites shared with the current user
  ///
  /// Uses version-based sync to reduce Firestore reads:
  /// - Compares local vs remote versions before fetching
  /// - Skips sites where local version >= remote version
  /// - Cleans up orphaned local sites not in shared_access
  Future<SharedSiteDownloadResult> checkAndDownloadSharedSites({
    void Function(String status)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      return SharedSiteDownloadResult(
        sitesDownloaded: 0,
        snagsDownloaded: 0,
        sitesRemoved: 0,
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
    int sitesRemoved = 0;
    int errors = 0;
    final errorMessages = <String>[];

    try {
      // Get all local shared sites for orphan cleanup
      final localSharedSites = await _database.siteDao.getSharedSites(userEmail);
      final localSiteIds = localSharedSites.map((s) => s.id).toSet();

      if (kDebugMode) {
        print('SharedSiteService: Found ${localSiteIds.length} local shared sites');
      }

      // Get single shared_access document for this user
      final sharedAccessDoc = await _firestore
          .collection('shared_access')
          .doc(emailHash)
          .get();

      if (!sharedAccessDoc.exists) {
        if (kDebugMode) {
          print('SharedSiteService: No shared_access document found');
        }

        // Clean up all local shared sites - user has no remote shares
        if (localSiteIds.isNotEmpty) {
          onProgress?.call('Cleaning up removed sites...');
          for (final orphanId in localSiteIds) {
            if (kDebugMode) {
              print('SharedSiteService: Removing orphaned local site $orphanId');
            }
            await _database.snagDao.deleteSnagsBySite(orphanId);
            await _database.siteDao.deleteSite(orphanId);
            sitesRemoved++;
          }
        }

        onProgress?.call('No shared sites found');
        return SharedSiteDownloadResult(
          sitesDownloaded: 0,
          snagsDownloaded: 0,
          sitesRemoved: sitesRemoved,
          errors: 0,
          errorMessages: [],
        );
      }

      final data = sharedAccessDoc.data()!;
      final sites = data['sites'] as Map<String, dynamic>? ?? {};
      final remoteSiteIds = sites.keys.toSet();

      if (kDebugMode) {
        print('SharedSiteService: Found ${sites.length} shared site references');
      }

      if (sites.isEmpty) {
        // Clean up all local shared sites - user has no remote shares
        if (localSiteIds.isNotEmpty) {
          onProgress?.call('Cleaning up removed sites...');
          for (final orphanId in localSiteIds) {
            if (kDebugMode) {
              print('SharedSiteService: Removing orphaned local site $orphanId');
            }
            await _database.snagDao.deleteSnagsBySite(orphanId);
            await _database.siteDao.deleteSite(orphanId);
            sitesRemoved++;
          }
        }

        onProgress?.call('No shared sites found');
        return SharedSiteDownloadResult(
          sitesDownloaded: 0,
          snagsDownloaded: 0,
          sitesRemoved: sitesRemoved,
          errors: 0,
          errorMessages: [],
        );
      }

      // Process each shared site reference
      // sites = { "siteId1": { "ownerUID": "uid1", "version": 5 }, ... }
      for (final entry in sites.entries) {
        final siteId = entry.key;
        final siteData = entry.value;

        // Parse new format: { ownerUID, version }
        String? ownerUID;
        int? remoteVersion;

        if (siteData is Map) {
          ownerUID = siteData['ownerUID'] as String?;
          remoteVersion = siteData['version'] as int?;
        } else {
          errors++;
          errorMessages.add('Invalid site data format for site $siteId');
          continue;
        }

        if (ownerUID == null) {
          errors++;
          errorMessages.add('Missing ownerUID for site $siteId');
          continue;
        }

        // Check local version to skip unnecessary fetches (RA 4.10)
        final existingSite = await _database.siteDao.getSiteById(siteId);
        if (existingSite != null && remoteVersion != null) {
          if (existingSite.firebaseVersion >= remoteVersion) {
            if (kDebugMode) {
              print(
                  'SharedSiteService: Site $siteId up to date (v${existingSite.firebaseVersion})');
            }
            continue; // Skip Firestore read - no changes
          }
        }

        onProgress?.call('Downloading site...');

        try {
          // Download site document (only if new or version mismatch)
          final siteDoc = await _firestore
              .collection('Profile')
              .doc(ownerUID)
              .collection('Sites')
              .doc(siteId)
              .get();

          if (!siteDoc.exists) {
            if (kDebugMode) {
              print(
                  'SharedSiteService: Site $siteId deleted from Firestore, cleaning up local');
            }
            // Site was deleted - clean up local copy (RA 2.7: CF failure scenario)
            await _database.snagDao.deleteSnagsBySite(siteId);
            await _database.siteDao.deleteSite(siteId);
            sitesRemoved++;
            continue;
          }

          final siteDocData = siteDoc.data()!;

          // Check if user still has access
          final sharedWith =
              siteDocData['sharedWith'] as Map<String, dynamic>? ?? {};
          if (!sharedWith.containsKey(userEmail.toLowerCase())) {
            if (kDebugMode) {
              print(
                  'SharedSiteService: User no longer has access to site $siteId, cleaning up local');
            }
            // User was removed from sharedWith - CF hasn't updated shared_access yet
            // Clean up local copy (race condition handling)
            if (existingSite != null) {
              await _database.snagDao.deleteSnagsBySite(siteId);
              await _database.siteDao.deleteSite(siteId);
              sitesRemoved++;
            }
            continue;
          }

          // Convert to Site model
          final site = Site.fromFirestore(siteId, siteDocData);

          // Save to local database
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
          // TODO: Snag sync limitations (out of scope for initial release):
          // 1. No version-based sync - always fetches all snags
          // 2. No deletion sync - deleted snags remain locally
          // See: SHARING_AND_CF_DECISIONS.md TODO section
          onProgress?.call('Downloading snags for ${site.name}...');

          final snagsQuery = await _firestore
              .collection('Profile')
              .doc(ownerUID)
              .collection('Sites')
              .doc(siteId)
              .collection('Snags')
              .get();

          if (kDebugMode) {
            print(
                'SharedSiteService: Found ${snagsQuery.docs.length} snags for site $siteId');
          }

          for (final snagDoc in snagsQuery.docs) {
            try {
              final snag = Snag.fromFirestore(snagDoc.id, snagDoc.data());

              final existingSnag =
                  await _database.snagDao.getSnagById(snagDoc.id);
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

      // Cleanup: Delete local sites not in shared_access (owner removed access)
      final orphanedSiteIds = localSiteIds.difference(remoteSiteIds);
      if (orphanedSiteIds.isNotEmpty) {
        onProgress?.call('Cleaning up removed sites...');
        for (final orphanId in orphanedSiteIds) {
          if (kDebugMode) {
            print('SharedSiteService: Removing orphaned local site $orphanId');
          }
          await _database.snagDao.deleteSnagsBySite(orphanId);
          await _database.siteDao.deleteSite(orphanId);
          sitesRemoved++;
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
      sitesRemoved: sitesRemoved,
      errors: errors,
      errorMessages: errorMessages,
    );

    if (kDebugMode) {
      print('SharedSiteService: ${result.summary}');
    }

    return result;
  }
}
