/// Form validation utilities for Profile module
/// Implements validation rules as per PRD Section 4.5.1
class Validators {
  // Error message constants
  static const String nameRequired = 'Name is required';
  static const String nameTooShort = 'Name must be at least 2 characters';
  static const String nameTooLong = 'Name must be less than 50 characters';
  
  static const String emailRequired = 'Email is required';
  static const String emailInvalid = 'Please enter a valid email';
  
  static const String phoneRequired = 'Phone is required';
  static const String phoneInvalid = 'Phone must be 7-15 digits';
  
  static const String jobTitleRequired = 'Job title is required';
  static const String jobTitleTooShort = 'Job title must be at least 2 characters';
  static const String jobTitleTooLong = 'Job title must be less than 50 characters';
  
  static const String companyNameRequired = 'Company name is required';
  static const String companyNameTooShort = 'Company name must be at least 2 characters';
  static const String companyNameTooLong = 'Company name must be less than 100 characters';
  
  static const String postcodeTooLong = 'Postcode must be less than 20 characters';

  // Regex patterns
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  static final RegExp _phoneRegex = RegExp(
    r'^\+?[0-9]{7,15}$',
  );

  /// Validate name field
  /// Required, 2-50 characters
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return nameRequired;
    }
    if (value.length < 2) {
      return nameTooShort;
    }
    if (value.length > 50) {
      return nameTooLong;
    }
    return null;
  }

  /// Validate email field
  /// Required, must be valid email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return emailRequired;
    }
    if (!_emailRegex.hasMatch(value)) {
      return emailInvalid;
    }
    return null;
  }

  /// Validate phone field
  /// Required, 7-15 digits, optional + prefix
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return phoneRequired;
    }
    if (!_phoneRegex.hasMatch(value)) {
      return phoneInvalid;
    }
    return null;
  }

  /// Validate job title field
  /// Required, 2-50 characters
  static String? validateJobTitle(String? value) {
    if (value == null || value.isEmpty) {
      return jobTitleRequired;
    }
    if (value.length < 2) {
      return jobTitleTooShort;
    }
    if (value.length > 50) {
      return jobTitleTooLong;
    }
    return null;
  }

  /// Validate company name field
  /// Required, 2-100 characters
  static String? validateCompanyName(String? value) {
    if (value == null || value.isEmpty) {
      return companyNameRequired;
    }
    if (value.length < 2) {
      return companyNameTooShort;
    }
    if (value.length > 100) {
      return companyNameTooLong;
    }
    return null;
  }

  /// Validate postcode field
  /// Optional, max 20 characters
  static String? validatePostcode(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    if (value.length > 20) {
      return postcodeTooLong;
    }
    return null;
  }

  /// Validate date format
  /// Must be one of the allowed formats
  static bool isValidDateFormat(String format) {
    return format == 'dd-MM-yyyy' || 
           format == 'MM-dd-yyyy' || 
           format == 'yyyy-MM-dd';
  }
}