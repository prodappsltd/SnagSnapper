import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Callback = void Function(MethodCall call);

class MockFirebasePlatform extends FirebasePlatform {
  MockFirebasePlatform() : super();

  static final Map<String, FirebaseAppPlatform> _apps = {};

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    final app = _MockFirebaseApp(name ?? defaultFirebaseAppName);
    _apps[app.name] = app;
    return app;
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return _apps[name] ?? _MockFirebaseApp(name);
  }

  @override
  List<FirebaseAppPlatform> get apps => _apps.values.toList();
}

class _MockFirebaseApp extends FirebaseAppPlatform {
  _MockFirebaseApp(String name) : super(name, _mockOptions);

  static final _mockOptions = const FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project',
  );

  @override
  FirebaseOptions get options => _mockOptions;

  @override
  bool get isAutomaticDataCollectionEnabled => false;

  @override
  Future<void> delete() async {
    MockFirebasePlatform._apps.remove(name);
  }

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}
}

void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up the platform instance
  FirebasePlatform.instance = MockFirebasePlatform();
}

Future<void> initializeFirebaseForTest() async {
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
}

void tearDownFirebase() {
  // Clear any Firebase apps
  MockFirebasePlatform._apps.clear();
}