/// Enum representing all possible states during app initialization
/// Used to provide type-safe state management during startup flow
/// 
/// Each state corresponds to a specific initialization outcome:
/// - Navigation states: Direct the app to appropriate screens
/// - Error states: Display error messages with retry options
/// - Success states: Indicate successful completion of initialization
enum InitializationState {
  /// User is not authenticated, navigate to login screen
  goToLogin,
  
  /// User is authenticated but email is not verified
  emailNotVerified,
  
  /// User profile successfully loaded, navigate to main menu
  profileFound,
  
  /// User authenticated but profile not found, navigate to profile screen
  profileNotFound,
  
  /// No internet connection detected
  noInternet,
  
  /// Widget context became invalid during async operations
  contextError,
  
  /// RevenueCat initialization failed
  revCatError,
  
  /// Failed to load user profile from Firebase
  firebaseError,
  
  /// Failed to load user's owned sites from Firebase
  firebaseErrorOwnedSites,
  
  /// Failed to load sites shared with user from Firebase
  firebaseErrorSharedSites,
  
  /// Unexpected error during initialization
  initializationError,
  
  /// Unknown error state (fallback)
  unknownError;
  
  /// Returns user-friendly error message for error states
  /// Returns null for non-error states
  String? get errorMessage {
    switch (this) {
      case InitializationState.noInternet:
        return 'No internet connection';
      case InitializationState.contextError:
        return 'App initialization error. Please try again.';
      case InitializationState.revCatError:
        return 'RevCat initialization error. If this persists, contact developer@productiveapps.co.uk';
      case InitializationState.firebaseError:
        return 'Error loading profile. If this persists, contact developer@productiveapps.co.uk';
      case InitializationState.firebaseErrorOwnedSites:
        return 'Error loading owned sites. If this persists, contact developer@productiveapps.co.uk';
      case InitializationState.firebaseErrorSharedSites:
        return 'Error loading shared sites. If this persists, contact developer@productiveapps.co.uk';
      case InitializationState.initializationError:
        return 'Unexpected error during startup. Please try again.';
      case InitializationState.unknownError:
        return 'An unknown error occurred. Please restart the app.';
      default:
        return null; // Non-error states
    }
  }
  
  /// Indicates if this state should trigger navigation
  bool get shouldNavigate {
    return this == InitializationState.goToLogin ||
           this == InitializationState.emailNotVerified ||
           this == InitializationState.profileFound ||
           this == InitializationState.profileNotFound;
  }
  
  /// Indicates if this state represents an error
  bool get isError {
    return errorMessage != null;
  }
  
  /// Gets the route name for navigation states
  /// Returns null for non-navigation states
  String? get routeName {
    switch (this) {
      case InitializationState.goToLogin:
      case InitializationState.emailNotVerified:
        return '/login';
      case InitializationState.profileFound:
        return '/mainMenu';
      case InitializationState.profileNotFound:
        return '/profile';
      default:
        return null;
    }
  }
}

/// Extension to parse string responses from legacy code
/// This maintains backward compatibility while migrating to enum
extension InitializationStateParser on String {
  InitializationState toInitializationState() {
    switch (this) {
      case 'Goto Login':
        return InitializationState.goToLogin;
      case 'Email Not Verified':
        return InitializationState.emailNotVerified;
      case 'Profile Found':
        return InitializationState.profileFound;
      case 'Profile Not Found':
        return InitializationState.profileNotFound;
      case 'No internet':
        return InitializationState.noInternet;
      case 'Context Error':
        return InitializationState.contextError;
      case 'RevCat Error':
        return InitializationState.revCatError;
      case 'Firebase Error':
        return InitializationState.firebaseError;
      case 'Firebase Error Owned Sites':
        return InitializationState.firebaseErrorOwnedSites;
      case 'Firebase Error Shared Sites':
        return InitializationState.firebaseErrorSharedSites;
      case 'Initialization Error':
        return InitializationState.initializationError;
      default:
        return InitializationState.unknownError;
    }
  }
}