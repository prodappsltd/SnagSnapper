import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snagsnapper/services/image_service.dart';
import 'package:snagsnapper/Data/user.dart';

/// Service to preload images on app start for better performance
/// Preloads profile, signature, and all site images (but not snag images)
class ImagePreloadService {
  static final ImagePreloadService _instance = ImagePreloadService._internal();
  factory ImagePreloadService() => _instance;
  ImagePreloadService._internal();
  
  final ImageService _imageService = ImageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Track preload status
  bool _isPreloading = false;
  bool _hasPreloaded = false;
  
  /// Get preload status
  bool get isPreloading => _isPreloading;
  bool get hasPreloaded => _hasPreloaded;
  
  /// Reset preload status (call on logout)
  void resetPreloadStatus() {
    _hasPreloaded = false;
  }
  
  /// Preload all user images (profile, signature, and sites)
  /// Call this after successful login
  Future<void> preloadUserImages() async {
    // Avoid duplicate preloading
    if (_isPreloading || _hasPreloaded) {
      if (kDebugMode) print('ImagePreloadService: Already preloading or preloaded');
      return;
    }
    
    _isPreloading = true;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) print('ImagePreloadService: No user logged in');
        return;
      }
      
      if (kDebugMode) print('ImagePreloadService: Starting preload for user ${user.uid}');
      
      // Get user document
      final userDoc = await _firestore
          .collection('Profile')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        if (kDebugMode) print('ImagePreloadService: User document not found');
        return;
      }
      
      final userData = userDoc.data()!;
      final appUser = AppUser.fromJson(userData);
      
      // List to track all preload tasks
      final preloadTasks = <Future<void>>[];
      
      // Preload profile image
      if (appUser.image.isNotEmpty && appUser.image.startsWith('http')) {
        if (kDebugMode) print('ImagePreloadService: Preloading profile image');
        preloadTasks.add(
          _imageService.getImage(url: appUser.image).then((data) {
            if (data != null && kDebugMode) {
              print('ImagePreloadService: Profile image preloaded (${data.length} bytes)');
            }
          }).catchError((e) {
            if (kDebugMode) print('ImagePreloadService: Error preloading profile: $e');
          })
        );
      }
      
      // Preload signature image
      if (appUser.signature.isNotEmpty && appUser.signature.startsWith('http')) {
        if (kDebugMode) print('ImagePreloadService: Preloading signature image');
        preloadTasks.add(
          _imageService.getImage(url: appUser.signature).then((data) {
            if (data != null && kDebugMode) {
              print('ImagePreloadService: Signature image preloaded (${data.length} bytes)');
            }
          }).catchError((e) {
            if (kDebugMode) print('ImagePreloadService: Error preloading signature: $e');
          })
        );
      }
      
      // Preload all site images
      if (appUser.mapOfSitePaths != null && appUser.mapOfSitePaths!.isNotEmpty) {
        if (kDebugMode) {
          print('ImagePreloadService: Preloading ${appUser.mapOfSitePaths!.length} site images');
        }
        
        for (final entry in appUser.mapOfSitePaths!.entries) {
          final siteId = entry.key;
          final ownerId = entry.value;
          
          // Get site document
          preloadTasks.add(
            _firestore
                .collection('Profile')
                .doc(ownerId)
                .collection('Sites')
                .doc(siteId)
                .get()
                .then((siteDoc) async {
              if (siteDoc.exists) {
                final siteData = siteDoc.data()!;
                final siteImage = siteData['image'] as String?;
                
                if (siteImage != null && siteImage.isNotEmpty && siteImage.startsWith('http')) {
                  if (kDebugMode) print('ImagePreloadService: Preloading site $siteId image');
                  
                  await _imageService.getImage(url: siteImage).then((data) {
                    if (data != null && kDebugMode) {
                      print('ImagePreloadService: Site $siteId image preloaded (${data.length} bytes)');
                    }
                  }).catchError((e) {
                    if (kDebugMode) print('ImagePreloadService: Error preloading site $siteId: $e');
                  });
                }
              }
            }).catchError((e) {
              if (kDebugMode) print('ImagePreloadService: Error getting site $siteId: $e');
            })
          );
        }
      }
      
      // Wait for all preload tasks to complete
      await Future.wait(preloadTasks);
      
      _hasPreloaded = true;
      if (kDebugMode) print('ImagePreloadService: Preload complete');
      
    } catch (e) {
      if (kDebugMode) print('ImagePreloadService: Error during preload: $e');
    } finally {
      _isPreloading = false;
    }
  }
  
  /// Preload snag images for a specific site
  /// Call this when user taps on a site
  Future<void> preloadSnagImagesForSite(String siteId, String ownerId) async {
    try {
      if (kDebugMode) print('ImagePreloadService: Preloading snag images for site $siteId');
      
      // Get all snags for the site
      final snagsSnapshot = await _firestore
          .collection('Profile')
          .doc(ownerId)
          .collection('Sites')
          .doc(siteId)
          .collection('Snags')
          .get();
      
      final preloadTasks = <Future<void>>[];
      
      for (final snagDoc in snagsSnapshot.docs) {
        final snagData = snagDoc.data();
        
        // Check for snag images (snag1 through snag8)
        for (int i = 1; i <= 8; i++) {
          final imageUrl = snagData['snag$i'] as String?;
          
          if (imageUrl != null && imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
            if (kDebugMode) {
              print('ImagePreloadService: Preloading snag ${snagDoc.id} image $i');
            }
            
            preloadTasks.add(
              _imageService.getImage(url: imageUrl).then((data) {
                if (data != null && kDebugMode) {
                  print('ImagePreloadService: Snag ${snagDoc.id} image $i preloaded');
                }
              }).catchError((e) {
                if (kDebugMode) {
                  print('ImagePreloadService: Error preloading snag ${snagDoc.id} image $i: $e');
                }
              })
            );
          }
        }
      }
      
      // Wait for all snag images to preload
      await Future.wait(preloadTasks);
      
      if (kDebugMode) {
        print('ImagePreloadService: Snag preload complete for site $siteId');
      }
      
    } catch (e) {
      if (kDebugMode) print('ImagePreloadService: Error preloading snag images: $e');
    }
  }
}