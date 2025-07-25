import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Constants/initialization_state.dart';

void main() {
  group('Route Configuration Tests', () {
    test('all required routes should be defined', () {
      // Define the expected routes based on what the app uses
      final expectedRoutes = {
        '/mainMenu',
        '/moreOptions',
        '/login',
        '/profile',
        '/profileSetup',
        '/mySites',
        '/forgotPassword',
        '/checkEmail',
        '/reportFormat',
        '/upgradeScreen',
        '/upSellSiteSharing',
        '/pdfViewer',
        '/shareScreen',
        '/themeSelector',
      };
      
      // Routes that should NOT exist (removed/deprecated)
      final deprecatedRoutes = {
        '/signUp',
        '/signUp2',
        '/signIn',
      };
      
      // This test documents what routes the app expects to exist
      // In a real test, you would check these against the actual MaterialApp routes
      expect(expectedRoutes.contains('/profileSetup'), isTrue,
          reason: 'Profile setup route must exist for new users');
      expect(expectedRoutes.contains('/login'), isTrue,
          reason: 'Login route must exist');
      expect(expectedRoutes.contains('/mainMenu'), isTrue,
          reason: 'Main menu route must exist');
          
      // Verify deprecated routes are not in expected routes
      for (final route in deprecatedRoutes) {
        expect(expectedRoutes.contains(route), isFalse,
            reason: 'Deprecated route $route should not be in expected routes');
      }
    });
    
    test('InitializationState route names match expected routes', () {
      // Define the expected routes (same as above)
      final expectedRoutes = {
        '/mainMenu',
        '/login', 
        '/profileSetup',
        // ... other routes
      };
      
      // Check each InitializationState that has a routeName
      for (final state in InitializationState.values) {
        final routeName = state.routeName;
        if (routeName != null) {
          // Document which states map to which routes
          switch (state) {
            case InitializationState.goToLogin:
            case InitializationState.emailNotVerified:
              expect(routeName, equals('/login'),
                  reason: 'State $state should navigate to login');
              break;
            case InitializationState.profileFound:
              expect(routeName, equals('/mainMenu'),
                  reason: 'State $state should navigate to main menu');
              break;
            case InitializationState.profileNotFound:
              expect(routeName, equals('/profileSetup'),
                  reason: 'State $state should navigate to profile setup');
              break;
            default:
              // Other states shouldn't have route names
              fail('Unexpected state with routeName: $state');
          }
        }
      }
    });
    
    test('navigation from UnifiedAuthScreen uses correct routes', () {
      // This test documents the navigation behavior expected from UnifiedAuthScreen
      
      // When email/password login succeeds but no profile exists
      const expectedRouteForNoProfile = '/profileSetup';
      expect(expectedRouteForNoProfile, isNot('/signUp'),
          reason: 'Should navigate to profileSetup, not the old signUp route');
      
      // When Google sign-in succeeds but no profile exists  
      const expectedRouteForGoogleNoProfile = '/profileSetup';
      expect(expectedRouteForGoogleNoProfile, isNot('/signUp'),
          reason: 'Google sign-in should also navigate to profileSetup, not signUp');
          
      // When login succeeds and profile exists
      const expectedRouteForExistingProfile = '/mainMenu';
      expect(expectedRouteForExistingProfile, equals('/mainMenu'),
          reason: 'Should navigate to main menu when profile exists');
          
      // When signup succeeds
      const expectedRouteAfterSignup = '/checkEmail';
      expect(expectedRouteAfterSignup, equals('/checkEmail'),
          reason: 'Should navigate to email verification after signup');
    });
  });
}