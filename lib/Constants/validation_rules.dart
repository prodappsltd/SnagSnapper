/// Validation Rules Constants class for SnagSnapper app.
/// Contains all validation patterns and rules that must match Firebase Security Rules.
class ValidationRules {
  /// VALIDATION RULES CONFIGURATION
  /// 
  /// IMPORTANT: These validations are used across the app for Profile data
  /// 
  /// SYNCHRONIZATION REQUIRED:
  /// When updating validations here, also update:
  /// 1. /firestore.rules - Firebase Security Rules (if using Firebase validation)
  /// 2. Profile screen UI validators
  /// 3. Local database constraints
  /// 
  /// For complete requirements, see: /Claude/PRD.md Section 4.5
  ///
  /// ============================================================================
  /// Last Updated: 2025-01-10
  /// 
  /// VALIDATION SPECIFICATIONS:
  /// - Name: 2-50 characters, letters/numbers/spaces/hyphens/apostrophes
  /// - Company: 2-100 characters, business punctuation allowed
  /// - Phone: 7-15 digits, optional country code
  /// - Job Title: 2-50 characters, letters/spaces/hyphens
  /// - Email: Standard RFC format
  /// - Postcode: Optional, alphanumeric with spaces/hyphens
  /// 
  /// SECURITY MEASURES:
  /// - Length validations on all fields
  /// - Pattern matching for valid characters
  /// - Type checking for all inputs
  /// - No HTML/script injection allowed
  /// ============================================================================
  // Prevent instantiation
  ValidationRules._();
  
  // Name validation
  static const int nameMinLength = 2;
  static const int nameMaxLength = 50;
  // Matches Unicode letters, combining marks, numbers, spaces, hyphens, apostrophes
  // UPDATED: Now allows numbers per user decision (supports "John III", "Mary 2nd", etc.)
  static final RegExp namePattern = RegExp(r"^[\p{L}\p{M}0-9\s\-']+$", unicode: true);
  
  // Company name validation  
  static const int companyMinLength = 2;
  static const int companyMaxLength = 100;
  // Matches Unicode letters, numbers (including Unicode), business punctuation
  // UPDATED: Added / and + per user decision, allows Unicode numbers (١٢٣, 一二三, etc.)
  static final RegExp companyPattern = RegExp(r"^[\p{L}\p{M}\p{N}\s\-&.,()\+/]+$", unicode: true);
  
  // Phone validation
  static const int phoneMinLength = 7;
  static const int phoneMaxLength = 15;
  // International phone format
  static final RegExp phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
  
  // Job title validation
  static const int jobTitleMinLength = 2;
  static const int jobTitleMaxLength = 50;
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