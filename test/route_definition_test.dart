import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Constants/initialization_state.dart';

void main() {
  group('Route Definition Tests', () {
    test('all InitializationState routes are correctly defined', () {
      // This test documents the expected route mapping for InitializationState
      // Without instantiating the full app
      
      // Test each state's route mapping
      expect(InitializationState.goToLogin.routeName, equals('/login'));
      expect(InitializationState.emailNotVerified.routeName, equals('/login'));
      expect(InitializationState.profileFound.routeName, equals('/mainMenu'));
      expect(InitializationState.profileNotFound.routeName, equals('/profileSetup'));
      
      // Error states should not have routes
      expect(InitializationState.noInternet.routeName, isNull);
      expect(InitializationState.contextError.routeName, isNull);
      expect(InitializationState.revCatError.routeName, isNull);
      expect(InitializationState.firebaseError.routeName, isNull);
      expect(InitializationState.firebaseErrorOwnedSites.routeName, isNull);
      expect(InitializationState.firebaseErrorSharedSites.routeName, isNull);
      expect(InitializationState.initializationError.routeName, isNull);
      expect(InitializationState.unknownError.routeName, isNull);
    });
    
    test('navigation states are correctly identified', () {
      // Test shouldNavigate property
      expect(InitializationState.goToLogin.shouldNavigate, isTrue);
      expect(InitializationState.emailNotVerified.shouldNavigate, isTrue);
      expect(InitializationState.profileFound.shouldNavigate, isTrue);
      expect(InitializationState.profileNotFound.shouldNavigate, isTrue);
      
      // Error states should not navigate
      expect(InitializationState.noInternet.shouldNavigate, isFalse);
      expect(InitializationState.contextError.shouldNavigate, isFalse);
      expect(InitializationState.revCatError.shouldNavigate, isFalse);
      expect(InitializationState.firebaseError.shouldNavigate, isFalse);
    });
    
    test('error states have appropriate error messages', () {
      // Test error messages
      expect(InitializationState.noInternet.errorMessage, equals('No internet connection'));
      expect(InitializationState.contextError.errorMessage, 
          equals('App initialization error. Please try again.'));
      expect(InitializationState.revCatError.errorMessage, 
          contains('RevCat initialization error'));
      expect(InitializationState.firebaseError.errorMessage, 
          contains('Error loading profile'));
      
      // Non-error states should not have error messages
      expect(InitializationState.goToLogin.errorMessage, isNull);
      expect(InitializationState.profileFound.errorMessage, isNull);
      expect(InitializationState.profileNotFound.errorMessage, isNull);
    });
    
    test('string to InitializationState conversion works correctly', () {
      // Test the extension method
      expect('Goto Login'.toInitializationState(), equals(InitializationState.goToLogin));
      expect('Email Not Verified'.toInitializationState(), equals(InitializationState.emailNotVerified));
      expect('Profile Found'.toInitializationState(), equals(InitializationState.profileFound));
      expect('Profile Not Found'.toInitializationState(), equals(InitializationState.profileNotFound));
      expect('No internet'.toInitializationState(), equals(InitializationState.noInternet));
      expect('Context Error'.toInitializationState(), equals(InitializationState.contextError));
      expect('RevCat Error'.toInitializationState(), equals(InitializationState.revCatError));
      expect('Firebase Error'.toInitializationState(), equals(InitializationState.firebaseError));
      expect('Firebase Error Owned Sites'.toInitializationState(), equals(InitializationState.firebaseErrorOwnedSites));
      expect('Firebase Error Shared Sites'.toInitializationState(), equals(InitializationState.firebaseErrorSharedSites));
      expect('Initialization Error'.toInitializationState(), equals(InitializationState.initializationError));
      expect('Unknown String'.toInitializationState(), equals(InitializationState.unknownError));
    });
    
    test('expected routes match app requirements', () {
      // Document the routes that should exist in the app
      final expectedRoutes = <String>{
        '/login',
        '/mainMenu', 
        '/profileSetup',
        '/forgotPassword',
        '/checkEmail',
        '/moreOptions',
        '/profile',
        '/mySites',
        '/reportFormat',
        '/upgradeScreen',
        '/upSellSiteSharing',
        '/pdfViewer',
        '/shareScreen',
        '/themeSelector',
      };
      
      // Routes that should NOT exist (deprecated)
      final deprecatedRoutes = <String>{
        '/signUp',    // Replaced by /profileSetup
        '/signUp2',   // Replaced by /profileSetup  
        '/signIn',    // Replaced by /login (UnifiedAuthScreen)
      };
      
      // Verify no overlap between expected and deprecated
      for (final route in deprecatedRoutes) {
        expect(expectedRoutes.contains(route), isFalse,
            reason: 'Deprecated route $route should not be in expected routes');
      }
      
      // Verify all InitializationState routes are in expected routes
      for (final state in InitializationState.values) {
        final routeName = state.routeName;
        if (routeName != null) {
          expect(expectedRoutes.contains(routeName), isTrue,
              reason: 'InitializationState.$state route "$routeName" should be in expected routes');
        }
      }
    });
  });
}