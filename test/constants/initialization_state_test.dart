import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Constants/initialization_state.dart';

void main() {
  group('InitializationState Tests', () {
    group('Error Message Tests', () {
      test('should return correct error messages for error states', () {
        // Test each error state
        expect(InitializationState.noInternet.errorMessage, 
               equals('No internet connection'));
        expect(InitializationState.contextError.errorMessage, 
               equals('App initialization error. Please try again.'));
        expect(InitializationState.revCatError.errorMessage, 
               equals('RevCat initialization error. If this persists, contact developer@productiveapps.co.uk'));
        expect(InitializationState.firebaseError.errorMessage, 
               equals('Error loading profile. If this persists, contact developer@productiveapps.co.uk'));
        expect(InitializationState.firebaseErrorOwnedSites.errorMessage, 
               equals('Error loading owned sites. If this persists, contact developer@productiveapps.co.uk'));
        expect(InitializationState.firebaseErrorSharedSites.errorMessage, 
               equals('Error loading shared sites. If this persists, contact developer@productiveapps.co.uk'));
        expect(InitializationState.initializationError.errorMessage, 
               equals('Unexpected error during startup. Please try again.'));
        expect(InitializationState.unknownError.errorMessage, 
               equals('An unknown error occurred. Please restart the app.'));
      });

      test('should return null for non-error states', () {
        // Test non-error states
        expect(InitializationState.goToLogin.errorMessage, isNull);
        expect(InitializationState.emailNotVerified.errorMessage, isNull);
        expect(InitializationState.profileFound.errorMessage, isNull);
      });
    });

    group('Navigation Tests', () {
      test('should identify navigation states correctly', () {
        // States that should navigate
        expect(InitializationState.goToLogin.shouldNavigate, isTrue);
        expect(InitializationState.emailNotVerified.shouldNavigate, isTrue);
        expect(InitializationState.profileFound.shouldNavigate, isTrue);
        
        // States that should not navigate
        expect(InitializationState.noInternet.shouldNavigate, isFalse);
        expect(InitializationState.contextError.shouldNavigate, isFalse);
        expect(InitializationState.revCatError.shouldNavigate, isFalse);
        expect(InitializationState.firebaseError.shouldNavigate, isFalse);
        expect(InitializationState.firebaseErrorOwnedSites.shouldNavigate, isFalse);
        expect(InitializationState.firebaseErrorSharedSites.shouldNavigate, isFalse);
        expect(InitializationState.initializationError.shouldNavigate, isFalse);
        expect(InitializationState.unknownError.shouldNavigate, isFalse);
      });

      test('should return correct route names', () {
        // Login routes
        expect(InitializationState.goToLogin.routeName, equals('/login'));
        expect(InitializationState.emailNotVerified.routeName, equals('/login'));
        
        // Main menu route
        expect(InitializationState.profileFound.routeName, equals('/mainMenu'));
        
        // Non-navigation states
        expect(InitializationState.noInternet.routeName, isNull);
        expect(InitializationState.contextError.routeName, isNull);
        expect(InitializationState.revCatError.routeName, isNull);
        expect(InitializationState.firebaseError.routeName, isNull);
        expect(InitializationState.firebaseErrorOwnedSites.routeName, isNull);
        expect(InitializationState.firebaseErrorSharedSites.routeName, isNull);
        expect(InitializationState.initializationError.routeName, isNull);
        expect(InitializationState.unknownError.routeName, isNull);
      });
    });

    group('Error State Tests', () {
      test('should identify error states correctly', () {
        // Error states
        expect(InitializationState.noInternet.isError, isTrue);
        expect(InitializationState.contextError.isError, isTrue);
        expect(InitializationState.revCatError.isError, isTrue);
        expect(InitializationState.firebaseError.isError, isTrue);
        expect(InitializationState.firebaseErrorOwnedSites.isError, isTrue);
        expect(InitializationState.firebaseErrorSharedSites.isError, isTrue);
        expect(InitializationState.initializationError.isError, isTrue);
        expect(InitializationState.unknownError.isError, isTrue);
        
        // Non-error states
        expect(InitializationState.goToLogin.isError, isFalse);
        expect(InitializationState.emailNotVerified.isError, isFalse);
        expect(InitializationState.profileFound.isError, isFalse);
      });
    });
  });

  group('InitializationStateParser Extension Tests', () {
    test('should parse all valid legacy strings correctly', () {
      // Test all known string mappings
      expect('Goto Login'.toInitializationState(), 
             equals(InitializationState.goToLogin));
      expect('Email Not Verified'.toInitializationState(), 
             equals(InitializationState.emailNotVerified));
      expect('Profile Found'.toInitializationState(), 
             equals(InitializationState.profileFound));
      expect('No internet'.toInitializationState(), 
             equals(InitializationState.noInternet));
      expect('Context Error'.toInitializationState(), 
             equals(InitializationState.contextError));
      expect('RevCat Error'.toInitializationState(), 
             equals(InitializationState.revCatError));
      expect('Firebase Error'.toInitializationState(), 
             equals(InitializationState.firebaseError));
      expect('Firebase Error Owned Sites'.toInitializationState(), 
             equals(InitializationState.firebaseErrorOwnedSites));
      expect('Firebase Error Shared Sites'.toInitializationState(), 
             equals(InitializationState.firebaseErrorSharedSites));
      expect('Initialization Error'.toInitializationState(), 
             equals(InitializationState.initializationError));
    });

    test('should return unknownError for unrecognized strings', () {
      // Test various unknown strings
      expect('Unknown State'.toInitializationState(), 
             equals(InitializationState.unknownError));
      expect(''.toInitializationState(), 
             equals(InitializationState.unknownError));
      expect('Random String'.toInitializationState(), 
             equals(InitializationState.unknownError));
      expect('null'.toInitializationState(), 
             equals(InitializationState.unknownError));
    });

    test('should be case sensitive', () {
      // Test that parsing is case sensitive
      expect('goto login'.toInitializationState(), 
             equals(InitializationState.unknownError));
      expect('GOTO LOGIN'.toInitializationState(), 
             equals(InitializationState.unknownError));
      expect('profile found'.toInitializationState(), 
             equals(InitializationState.unknownError));
    });
  });

  group('State Consistency Tests', () {
    test('all error states should have error messages', () {
      // Verify that isError and errorMessage are consistent
      for (final state in InitializationState.values) {
        if (state.isError) {
          expect(state.errorMessage, isNotNull,
              reason: 'Error state ${state.name} should have an error message');
        } else {
          expect(state.errorMessage, isNull,
              reason: 'Non-error state ${state.name} should not have an error message');
        }
      }
    });

    test('all navigation states should have route names', () {
      // Verify that shouldNavigate and routeName are consistent
      for (final state in InitializationState.values) {
        if (state.shouldNavigate) {
          expect(state.routeName, isNotNull,
              reason: 'Navigation state ${state.name} should have a route name');
        } else {
          expect(state.routeName, isNull,
              reason: 'Non-navigation state ${state.name} should not have a route name');
        }
      }
    });

    test('no state should be both error and navigation', () {
      // Verify mutual exclusion of error and navigation states
      for (final state in InitializationState.values) {
        if (state.isError) {
          expect(state.shouldNavigate, isFalse,
              reason: 'State ${state.name} should not be both error and navigation');
        }
      }
    });
  });
}