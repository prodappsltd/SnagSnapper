import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:snagsnapper/services/sync_service.dart';
import 'package:snagsnapper/services/sync/handlers/profile_sync_handler.dart';
import 'package:snagsnapper/services/sync/network_monitor.dart';
import 'package:snagsnapper/services/sync/queue_manager.dart';
import 'package:snagsnapper/services/sync/device_manager.dart';
import 'package:snagsnapper/services/sync/conflict_resolver.dart';
import 'package:snagsnapper/Data/database/app_database.dart';
import 'package:snagsnapper/Data/models/app_user.dart';
import 'package:snagsnapper/Data/models/sync_result.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Sync Service Integration Tests', () {
    late AppDatabase database;
    late SyncService syncService;
    late FirebaseAuth auth;
    late FirebaseFirestore firestore;
    late FirebaseStorage storage;
    late String testUserId;

    setUpAll(() async {
      // Initialize Firebase for testing
      await Firebase.initializeApp();
      
      // Set up test environment
      auth = FirebaseAuth.instance;
      firestore = FirebaseFirestore.instance;
      storage = FirebaseStorage.instance;
      
      // Clear any existing test data
      await clearTestData();
      
      // Create test user
      final credential = await auth.createUserWithEmailAndPassword(
        email: 'test@snagsnapper.com',
        password: 'TestPassword123!',
      );
      testUserId = credential.user!.uid;
    });

    tearDownAll(() async {
      // Clean up test user and data
      await auth.currentUser?.delete();
      await clearTestData();
    });

    setUp(() async {
      // Initialize database
      database = await AppDatabase.getInstance();
      
      // Initialize sync service
      syncService = SyncService.instance;
      await syncService.initialize(testUserId);
    });

    tearDown(() async {
      // Dispose services
      syncService.dispose();
      await database.close();
    });

    group('End-to-End Sync Flow', () {
      test('should sync profile from local to Firebase', () async {
        // Create local profile
        final localUser = AppUser(
          id: testUserId,
          name: 'Test User',
          email: 'test@snagsnapper.com',
          phone: '1234567890',
          jobTitle: 'Developer',
          companyName: 'Test Corp',
          postcodeOrArea: '12345',
          dateFormat: 'dd-MM-yyyy',
          needsProfileSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Save to local database
        await database.profileDao.insertProfile(localUser);

        // Trigger sync
        final result = await syncService.syncNow();

        // Verify sync success
        expect(result.success, isTrue);
        expect(result.syncedItems, contains('profile'));

        // Verify data in Firebase
        final firebaseDoc = await firestore
            .collection('profiles')
            .doc(testUserId)
            .get();
        
        expect(firebaseDoc.exists, isTrue);
        expect(firebaseDoc.data()?['name'], equals('Test User'));
        expect(firebaseDoc.data()?['email'], equals('test@snagsnapper.com'));

        // Verify local flags cleared
        final updatedUser = await database.profileDao.getProfile(testUserId);
        expect(updatedUser?.needsProfileSync, isFalse);
      });

      test('should sync profile from Firebase to local', () async {
        // Create profile in Firebase
        await firestore.collection('profiles').doc(testUserId).set({
          'name': 'Firebase User',
          'email': 'firebase@snagsnapper.com',
          'companyName': 'Firebase Corp',
          'phone': '9876543210',
          'jobTitle': 'Engineer',
          'postcodeOrArea': '54321',
          'dateFormat': 'MM-dd-yyyy',
          'version': 1,
          'updatedAt': Timestamp.now(),
        });

        // Trigger sync (download)
        final result = await syncService.syncNow();

        expect(result.success, isTrue);

        // Verify data in local database
        final localUser = await database.profileDao.getProfile(testUserId);
        expect(localUser, isNotNull);
        expect(localUser!.name, equals('Firebase User'));
        expect(localUser.email, equals('firebase@snagsnapper.com'));
        expect(localUser.companyName, equals('Firebase Corp'));
      });

      test('should handle profile image sync', () async {
        // Create local profile with image
        final localUser = AppUser(
          id: testUserId,
          name: 'Test User',
          email: 'test@snagsnapper.com',
          companyName: 'Test Corp',
          imageLocalPath: 'test_image.jpg',
          needsImageSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Create test image file
        final testImageFile = File('test_image.jpg');
        await testImageFile.writeAsBytes([1, 2, 3, 4, 5]); // Simple test data

        // Save profile to local database
        await database.profileDao.insertProfile(localUser);

        // Trigger sync
        final result = await syncService.syncNow();

        expect(result.success, isTrue);
        expect(result.syncedItems, contains('profile_image'));

        // Verify image uploaded to Firebase Storage
        final storageRef = storage.ref('users/$testUserId/profile.jpg');
        final metadata = await storageRef.getMetadata();
        expect(metadata.size, isNotNull);

        // Verify URL saved in profile
        final updatedUser = await database.profileDao.getProfile(testUserId);
        expect(updatedUser!.imageFirebaseUrl, isNotNull);
        expect(updatedUser.needsImageSync, isFalse);

        // Clean up
        await testImageFile.delete();
      });
    });

    group('Conflict Resolution Integration', () {
      test('should resolve version conflicts correctly', () async {
        // Create local profile with version 2
        final localUser = AppUser(
          id: testUserId,
          name: 'Local User V2',
          email: 'local@snagsnapper.com',
          companyName: 'Local Corp',
          localVersion: 2,
          firebaseVersion: 1,
          needsProfileSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Create Firebase profile with version 1
        await firestore.collection('profiles').doc(testUserId).set({
          'name': 'Firebase User V1',
          'email': 'firebase@snagsnapper.com',
          'companyName': 'Firebase Corp',
          'version': 1,
          'updatedAt': Timestamp.now(),
        });

        // Save local profile
        await database.profileDao.insertProfile(localUser);

        // Trigger sync
        final result = await syncService.syncNow();

        expect(result.success, isTrue);

        // Local version should win (v2 > v1)
        final firebaseDoc = await firestore
            .collection('profiles')
            .doc(testUserId)
            .get();
        
        expect(firebaseDoc.data()?['name'], equals('Local User V2'));
        expect(firebaseDoc.data()?['version'], equals(2));
      });

      test('should merge fields when versions are equal', () async {
        final now = DateTime.now();
        
        // Create local profile with recent name update
        final localUser = AppUser(
          id: testUserId,
          name: 'Recent Local Name',
          email: 'old@snagsnapper.com',
          companyName: 'Old Company',
          localVersion: 2,
          firebaseVersion: 2,
          needsProfileSync: true,
          createdAt: now.subtract(Duration(days: 7)),
          updatedAt: now.subtract(Duration(minutes: 5)), // Recent
        );

        // Create Firebase profile with recent email update
        await firestore.collection('profiles').doc(testUserId).set({
          'name': 'Old Firebase Name',
          'email': 'recent@snagsnapper.com',
          'companyName': 'Recent Company',
          'version': 2,
          'updatedAt': Timestamp.fromDate(now.subtract(Duration(hours: 1))),
          'nameUpdatedAt': Timestamp.fromDate(now.subtract(Duration(days: 1))),
          'emailUpdatedAt': Timestamp.fromDate(now.subtract(Duration(minutes: 10))),
          'companyNameUpdatedAt': Timestamp.fromDate(now.subtract(Duration(minutes: 30))),
        });

        // Save local profile
        await database.profileDao.insertProfile(localUser);

        // Trigger sync with merge
        final result = await syncService.syncNow();

        expect(result.success, isTrue);

        // Check merged result
        final mergedUser = await database.profileDao.getProfile(testUserId);
        expect(mergedUser!.name, equals('Recent Local Name')); // Local is more recent
        expect(mergedUser.email, equals('recent@snagsnapper.com')); // Firebase field
        expect(mergedUser.companyName, equals('Recent Company')); // Firebase field
      });
    });

    group('Device Management Integration', () {
      test('should enforce single device restriction', () async {
        // Register current device
        final deviceManager = DeviceManager();
        await deviceManager.registerDevice(testUserId);

        // Simulate another device trying to sync
        await firestore
            .doc('device_sessions/$testUserId/current_device')
            .set({
          'device_id': 'different_device_123',
          'device_name': 'Other Phone',
          'last_active': DateTime.now().millisecondsSinceEpoch,
          'force_logout': false,
        });

        // Try to sync from current device
        final result = await syncService.syncNow();

        expect(result.success, isFalse);
        expect(result.message, contains('device'));
        expect(result.requiresDeviceSwitch, isTrue);
      });

      test('should handle force logout from another device', () async {
        final logoutCompleter = Completer<bool>();
        
        // Set up force logout listener
        syncService.onForceLogout(() {
          logoutCompleter.complete(true);
        });

        // Simulate force logout from another device
        await firestore
            .doc('device_sessions/$testUserId/force_logout')
            .set(true);

        // Wait for force logout
        final wasLoggedOut = await logoutCompleter.future
            .timeout(Duration(seconds: 5), onTimeout: () => false);

        expect(wasLoggedOut, isTrue);
      });
    });

    group('Queue Processing Integration', () {
      test('should process queued items when online', () async {
        // Go offline
        await syncService.simulateOffline();

        // Create profile update while offline
        final localUser = AppUser(
          id: testUserId,
          name: 'Offline Update',
          email: 'offline@snagsnapper.com',
          companyName: 'Offline Corp',
          needsProfileSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await database.profileDao.insertProfile(localUser);

        // Try to sync while offline (should queue)
        final offlineResult = await syncService.syncNow();
        expect(offlineResult.success, isFalse);
        expect(offlineResult.wasQueued, isTrue);

        // Go back online
        await syncService.simulateOnline();

        // Wait for auto-sync to process queue
        await Future.delayed(Duration(seconds: 2));

        // Verify data synced to Firebase
        final firebaseDoc = await firestore
            .collection('profiles')
            .doc(testUserId)
            .get();
        
        expect(firebaseDoc.exists, isTrue);
        expect(firebaseDoc.data()?['name'], equals('Offline Update'));
      });

      test('should batch multiple queued operations', () async {
        // Queue multiple operations
        final queue = SyncQueueManager();
        
        for (int i = 0; i < 5; i++) {
          await queue.addToQueue(SyncQueueItem(
            id: 'queue_$i',
            userId: testUserId,
            type: SyncType.profile,
            action: SyncAction.upload,
            data: {'field_$i': 'value_$i'},
            priority: SyncPriority.normal,
            createdAt: DateTime.now(),
          ));
        }

        // Process queue
        await queue.processQueue();

        // Verify all items processed
        final status = await queue.getQueueStatus();
        expect(status.isEmpty, isTrue);
        expect(status.processedCount, equals(5));
      });

      test('should handle retry with exponential backoff', () async {
        final queue = SyncQueueManager();
        
        // Add item that will fail
        await queue.addToQueue(SyncQueueItem(
          id: 'retry_test',
          userId: testUserId,
          type: SyncType.profile,
          action: SyncAction.upload,
          data: {'invalid': true}, // Will cause validation error
          priority: SyncPriority.high,
          createdAt: DateTime.now(),
        ));

        // Process queue (should fail and retry)
        await queue.processQueue();

        // Check retry scheduled
        final items = await queue.getPendingItems();
        expect(items.first.retryCount, equals(1));
        expect(items.first.nextRetryAt, isNotNull);
        expect(items.first.nextRetryAt!.isAfter(DateTime.now()), isTrue);
      });
    });

    group('Network Monitoring Integration', () {
      test('should detect connectivity changes', () async {
        final networkMonitor = NetworkMonitor();
        final connectivityChanges = <ConnectivityResult>[];
        
        // Listen for changes
        networkMonitor.connectivityStream.listen(connectivityChanges.add);

        // Simulate connectivity changes
        await networkMonitor.simulateConnectivityChange(ConnectivityResult.none);
        await Future.delayed(Duration(milliseconds: 100));
        await networkMonitor.simulateConnectivityChange(ConnectivityResult.wifi);
        await Future.delayed(Duration(milliseconds: 100));

        expect(connectivityChanges, contains(ConnectivityResult.none));
        expect(connectivityChanges, contains(ConnectivityResult.wifi));
      });

      test('should trigger auto-sync on reconnect', () async {
        final syncCompleter = Completer<bool>();
        
        // Set up auto-sync
        syncService.setupAutoSync();
        syncService.onSyncComplete(() {
          syncCompleter.complete(true);
        });

        // Create pending sync
        final localUser = AppUser(
          id: testUserId,
          name: 'Auto Sync Test',
          email: 'auto@snagsnapper.com',
          companyName: 'Auto Corp',
          needsProfileSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await database.profileDao.insertProfile(localUser);

        // Simulate reconnect
        await syncService.simulateReconnect();

        // Wait for auto-sync
        final didSync = await syncCompleter.future
            .timeout(Duration(seconds: 5), onTimeout: () => false);

        expect(didSync, isTrue);

        // Verify synced to Firebase
        final firebaseDoc = await firestore
            .collection('profiles')
            .doc(testUserId)
            .get();
        expect(firebaseDoc.data()?['name'], equals('Auto Sync Test'));
      });

      test('should respect WiFi-only sync setting', () async {
        // Enable WiFi-only sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('wifi_only_sync', true);

        // Simulate mobile connection
        final networkMonitor = NetworkMonitor();
        await networkMonitor.simulateConnectivityChange(ConnectivityResult.mobile);

        // Try to sync
        final result = await syncService.syncNow();

        expect(result.success, isFalse);
        expect(result.message, contains('WiFi'));

        // Switch to WiFi
        await networkMonitor.simulateConnectivityChange(ConnectivityResult.wifi);

        // Try again
        final wifiResult = await syncService.syncNow();
        expect(wifiResult.success, isTrue);
      });
    });

    group('Performance and Optimization', () {
      test('should compress images before upload', () async {
        // Create large image
        final largeImageData = List.generate(2000000, (i) => i % 256);
        final imageFile = File('large_test_image.jpg');
        await imageFile.writeAsBytes(largeImageData);

        // Create profile with image
        final localUser = AppUser(
          id: testUserId,
          name: 'Test User',
          email: 'test@snagsnapper.com',
          companyName: 'Test Corp',
          imageLocalPath: imageFile.path,
          needsImageSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await database.profileDao.insertProfile(localUser);

        // Sync (should compress)
        final result = await syncService.syncNow();
        expect(result.success, isTrue);

        // Verify compressed size in Firebase Storage
        final storageRef = storage.ref('users/$testUserId/profile.jpg');
        final metadata = await storageRef.getMetadata();
        
        // Compressed size should be less than original
        expect(metadata.size, lessThan(largeImageData.length));

        // Clean up
        await imageFile.delete();
      });

      test('should cache Firebase data to reduce reads', () async {
        // First sync - should read from Firebase
        final result1 = await syncService.syncNow();
        expect(result1.success, isTrue);
        final reads1 = result1.firebaseReads;

        // Second sync immediately after - should use cache
        final result2 = await syncService.syncNow();
        expect(result2.success, isTrue);
        final reads2 = result2.firebaseReads;

        // Cache should reduce reads
        expect(reads2, lessThan(reads1));
      });

      test('should batch Firestore operations', () async {
        // Create multiple profiles to sync
        final profiles = List.generate(10, (i) => AppUser(
          id: '${testUserId}_$i',
          name: 'User $i',
          email: 'user$i@snagsnapper.com',
          companyName: 'Company $i',
          needsProfileSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));

        // Save all to local database
        for (final profile in profiles) {
          await database.profileDao.insertProfile(profile);
        }

        // Sync all (should batch)
        final startTime = DateTime.now();
        final result = await syncService.syncBatch(profiles.map((p) => p.id).toList());
        final duration = DateTime.now().difference(startTime);

        expect(result.success, isTrue);
        expect(result.batchedOperations, isTrue);
        expect(duration.inSeconds, lessThan(5)); // Should be fast due to batching
      });
    });

    group('Error Recovery Integration', () {
      test('should recover from partial sync failure', () async {
        // Create profile with invalid data that will fail
        final localUser = AppUser(
          id: testUserId,
          name: 'Test User',
          email: 'invalid-email', // Invalid format
          companyName: '',  // Empty required field
          needsProfileSync: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await database.profileDao.insertProfile(localUser);

        // First sync attempt (should fail validation)
        final result1 = await syncService.syncNow();
        expect(result1.success, isFalse);
        expect(result1.hasValidationErrors, isTrue);

        // Fix the data
        final fixedUser = localUser.copyWith(
          email: 'fixed@snagsnapper.com',
          companyName: 'Fixed Corp',
        );
        await database.profileDao.updateProfile(testUserId, fixedUser);

        // Retry sync (should succeed)
        final result2 = await syncService.syncNow();
        expect(result2.success, isTrue);
      });

      test('should handle Firebase service outage', () async {
        // Simulate Firebase being down
        await syncService.simulateFirebaseOutage();

        // Try to sync
        final result = await syncService.syncNow();

        expect(result.success, isFalse);
        expect(result.wasQueued, isTrue);
        expect(result.message, contains('service'));

        // Restore Firebase
        await syncService.restoreFirebaseService();

        // Queue should be processed automatically
        await Future.delayed(Duration(seconds: 2));

        final queueStatus = await syncService.getQueueStatus();
        expect(queueStatus.isEmpty, isTrue);
      });

      test('should handle corrupted local data', () async {
        // Corrupt local database entry
        await database.profileDao.corruptProfile(testUserId);

        // Try to sync (should detect corruption)
        final result = await syncService.syncNow();

        expect(result.success, isFalse);
        expect(result.hasCorruption, isTrue);

        // Should attempt recovery from Firebase
        expect(result.recoveryAttempted, isTrue);

        // Verify recovered data
        final recoveredUser = await database.profileDao.getProfile(testUserId);
        expect(recoveredUser, isNotNull);
        expect(recoveredUser!.isValid(), isTrue);
      });
    });
  });
}

// Helper function to clear test data
Future<void> clearTestData() async {
  // Clear Firestore
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();
  
  final profiles = await firestore.collection('profiles').get();
  for (final doc in profiles.docs) {
    batch.delete(doc.reference);
  }
  
  final deviceSessions = await firestore.collection('device_sessions').get();
  for (final doc in deviceSessions.docs) {
    batch.delete(doc.reference);
  }
  
  await batch.commit();
  
  // Clear Storage
  try {
    final storage = FirebaseStorage.instance;
    final ref = storage.ref('users');
    final result = await ref.listAll();
    for (final item in result.items) {
      await item.delete();
    }
  } catch (e) {
    // Storage might be empty
  }
  
  // Clear local database
  final database = await AppDatabase.getInstance();
  await database.clearAllTables();
}