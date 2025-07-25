/// Validation Rules Constants class for SnagSnapper app.
/// Contains all validation patterns and rules that must match Firebase Security Rules.
class ValidationRules {
  /// SESSION CONTEXT FILE - Read this for quick understanding
  /// 
  /// IMPORTANT: These validations MUST match Firebase Security Rules in firestore.rules
  /// When updating validations here, also update:
  /// 1. /firestore.rules (in project root)
  /// 2. Any UI validators in profile_setup_screen.dart
  /// 
  /// Keep all validation logic synchronized across the app!
  ///
  /// ============================================================================
  /// Last Updated: 2025-07-20
  /// 
  /// RELATED FILES TO REVIEW:
  /// 1. /firestore.rules - Contains matching Firebase security rules (in project root)
  /// 2. /lib/Screens/SignUp_SignIn/profile_setup_screen.dart - UI implementation
  /// 3. /lib/Data/user.dart - User data model
  /// 4. /Planning/PROJECT_RULES.md - General project guidelines
  /// 
  /// DECISIONS MADE:
  /// - International language support: YES (Unicode patterns with \p{L} and \p{M})
  /// - Phone format: International flexible format (+country code optional)
  /// - Special characters in names: Limited to space, hyphen, apostrophe
  /// - Company names: Allow business punctuation (&.,())
  /// - Email validation: Standard RFC format
  /// - Profile images: Must be from Firebase Storage only
  /// 
  /// VALIDATION DECISIONS - CONFIRMED BY USER:
  /// 1. Names: ALLOW numbers (supports "John III", "Mary 2nd", etc.)
  /// 2. Phone: KEEP flexible international format (no country-specific validation)
  /// 3. Company names: ADD / and + only (final set: letters, numbers, &.,()/ +)
  /// 4. Profile images: 5MB maximum file size (enforced via dimension limits: 2000x2000px for profiles)
  /// 5. Unicode numbers: ALLOW in company names (supports ١٢٣, 一二三, १२३, etc.)
  /// 
  /// SECURITY MEASURES IMPLEMENTED:
  /// - SQL injection protection (checking for SQL keywords)
  /// - XSS protection (blocking HTML/script tags)
  /// - Length validations on all fields
  /// - Type checking for all inputs
  /// - Rate limiting (5 second cooldown between updates)
  /// - Email immutability after profile creation
  /// 
  /// IMPLEMENTATION NOTES:
  /// - Firebase rules use Unicode regex (\p{L}, \p{M}) - test thoroughly
  /// - If business names need additional characters, add to company pattern only
  /// - All changes must be synchronized between UI and Firebase rules
  /// - Rate limiting prevents updates more frequent than 5 seconds
  /// ============================================================================
  // Prevent instantiation
  ValidationRules._();
  
  // Name validation
  static const int nameMinLength = 2;
  static const int nameMaxLength = 100;
  // Matches Unicode letters, combining marks, numbers, spaces, hyphens, apostrophes
  // UPDATED: Now allows numbers per user decision (supports "John III", "Mary 2nd", etc.)
  static final RegExp namePattern = RegExp(r"^[\p{L}\p{M}0-9\s\-']+$", unicode: true);
  
  // Company name validation  
  static const int companyMinLength = 2;
  static const int companyMaxLength = 200;
  // Matches Unicode letters, numbers (including Unicode), business punctuation
  // UPDATED: Added / and + per user decision, allows Unicode numbers (١٢٣, 一二三, etc.)
  static final RegExp companyPattern = RegExp(r"^[\p{L}\p{M}\p{N}\s\-&.,()\+/]+$", unicode: true);
  
  // Phone validation
  static const int phoneMinLength = 7;
  static const int phoneMaxLength = 15;
  // International phone format
  static final RegExp phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
  
  // Job title validation
  static const int jobTitleMinLength = 0;
  static const int jobTitleMaxLength = 100;
  // Matches Unicode letters, spaces, hyphens, slashes, commas
  static final RegExp jobTitlePattern = RegExp(r"^[\p{L}\p{M}\s\-/,]+$", unicode: true);
  
  // Postcode validation
  static const int postcodeMinLength = 0;
  static const int postcodeMaxLength = 20;
  // Alphanumeric with spaces and hyphens
  static final RegExp postcodePattern = RegExp(r'^[a-zA-Z0-9\s\-]+$');
  
  // Email validation
  static final RegExp emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  // Image URL validation
  static const int imageUrlMaxLength = 500;
  static const String firebaseStoragePrefix = 'https://firebasestorage.googleapis.com/';
  
  // Signature validation
  static const int signatureMaxLength = 50000;
  
  // Date formats allowed
  static const List<String> allowedDateFormats = [
    'dd-MM-yyyy',
    'MM-dd-yyyy', 
    'yyyy-MM-dd'
  ];
  
  // Validation helper methods with specific error messages
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < nameMinLength) {
      return 'Name must be at least $nameMinLength characters';
    }
    if (trimmed.length > nameMaxLength) {
      return 'Name must be less than $nameMaxLength characters';
    }
    if (!namePattern.hasMatch(trimmed)) {
      return 'Name can only contain letters, numbers, spaces, hyphens, and apostrophes';
    }
    return null;
  }
  
  static String? validateCompanyName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Company name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < companyMinLength) {
      return 'Company name must be at least $companyMinLength characters';
    }
    if (trimmed.length > companyMaxLength) {
      return 'Company name must be less than $companyMaxLength characters';
    }
    if (!companyPattern.hasMatch(trimmed)) {
      return 'Company name contains invalid characters';
    }
    return null;
  }
  
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final trimmed = value.trim();
    if (!phonePattern.hasMatch(trimmed)) {
      return 'Please enter a valid phone number (7-15 digits)';
    }
    return null;
  }
  
  static String? validateJobTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    final trimmed = value.trim();
    if (trimmed.length > jobTitleMaxLength) {
      return 'Job title must be less than $jobTitleMaxLength characters';
    }
    if (!jobTitlePattern.hasMatch(trimmed)) {
      return 'Job title contains invalid characters';
    }
    return null;
  }
}