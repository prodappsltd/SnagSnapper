import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

// Mock classes for Firebase services
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}
class MockUser extends Mock implements User {}
class MockUserCredential extends Mock implements UserCredential {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}
class MockDocumentReference extends Mock implements DocumentReference {}
class MockCollectionReference extends Mock implements CollectionReference {}
class MockQuery extends Mock implements Query {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot {}
class MockDatabaseReference extends Mock implements DatabaseReference {}
class MockDataSnapshot extends Mock implements DataSnapshot {}

/// Helper to setup common Firebase mocks
class FirebaseMockSetup {
  static MockFirebaseAuth setupAuthMock({
    String? uid,
    String? email,
    bool emailVerified = true,
  }) {
    final mockAuth = MockFirebaseAuth();
    final mockUser = MockUser();
    
    when(mockUser.uid).thenReturn(uid ?? 'test-user-123');
    when(mockUser.email).thenReturn(email ?? 'test@example.com');
    when(mockUser.emailVerified).thenReturn(emailVerified);
    
    when(mockAuth.currentUser).thenReturn(mockUser);
    
    return mockAuth;
  }
  
  static MockFirebaseFirestore setupFirestoreMock() {
    return MockFirebaseFirestore();
  }
  
  static MockFirebaseDatabase setupRealtimeDatabaseMock() {
    return MockFirebaseDatabase();
  }
  
  static void setupProfileDocument(
    MockFirebaseFirestore mockFirestore,
    String userId,
    Map<String, dynamic>? data,
  ) {
    final mockCollection = MockCollectionReference();
    final mockDocument = MockDocumentReference();
    final mockSnapshot = MockDocumentSnapshot();
    
    when(mockFirestore.collection('Profile')).thenReturn(mockCollection);
    when(mockCollection.doc(userId)).thenReturn(mockDocument);
    when(mockDocument.get()).thenAnswer((_) async => mockSnapshot);
    
    if (data != null) {
      when(mockSnapshot.exists).thenReturn(true);
      when(mockSnapshot.data()).thenReturn(data);
    } else {
      when(mockSnapshot.exists).thenReturn(false);
      when(mockSnapshot.data()).thenReturn(null);
    }
  }
  
  static void setupDeviceSession(
    MockFirebaseDatabase mockDatabase,
    String userId,
    String deviceId,
  ) {
    final mockRef = MockDatabaseReference();
    
    when(mockDatabase.ref('device_sessions/$userId/current_device'))
        .thenReturn(mockRef);
    
    when(mockRef.set(any)).thenAnswer((_) async => {});
    when(mockRef.update(any)).thenAnswer((_) async => {});
  }
}