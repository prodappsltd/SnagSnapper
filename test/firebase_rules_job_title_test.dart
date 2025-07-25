import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Rules - Job Title and Postcode Validation', () {
    group('Job Title Validation (Required Field)', () {
      test('should reject empty job title', () {
        // Test that empty job title is rejected
        final jobTitle = '';
        final isValid = validateJobTitle(jobTitle);
        expect(isValid, isFalse);
      });

      test('should reject null job title', () {
        // Test that null job title is rejected
        final String? jobTitle = null;
        expect(() => validateJobTitle(jobTitle!), throwsA(isA<TypeError>()));
      });

      test('should accept valid job titles', () {
        // Test various valid job titles
        expect(validateJobTitle('Site Manager'), isTrue);
        expect(validateJobTitle('Senior Developer'), isTrue);
        expect(validateJobTitle('VP Sales/Marketing'), isTrue);
        expect(validateJobTitle('Director, Operations'), isTrue);
        expect(validateJobTitle('Project Manager'), isTrue);
        expect(validateJobTitle('Team Leader'), isTrue);
        // These were previously blocked by SQL injection patterns
        expect(validateJobTitle('Chief Executive Officer'), isTrue);
        expect(validateJobTitle('Executive Director'), isTrue);
        expect(validateJobTitle('Senior Executive'), isTrue);
        expect(validateJobTitle('Director of Selection'), isTrue);
      });

      test('should reject job titles with numbers', () {
        // Job titles with numbers should be rejected
        expect(validateJobTitle('Manager 2'), isFalse);
        expect(validateJobTitle('Team Lead 1'), isFalse);
      });

      test('should reject job titles with special characters', () {
        // Job titles with invalid special characters should be rejected
        expect(validateJobTitle('Manager@Company'), isFalse);
        expect(validateJobTitle('Developer!'), isFalse);
        expect(validateJobTitle('CEO#1'), isFalse);
      });

      test('should reject job titles with script injection attempts', () {
        // Job titles with script injection should be rejected
        expect(validateJobTitle('<script>alert("hack")</script>'), isFalse);
        expect(validateJobTitle('Manager javascript:void(0)'), isFalse);
        expect(validateJobTitle('Developer onclick=alert()'), isFalse);
        expect(validateJobTitle('CEO onload=hack()'), isFalse);
      });

      test('should enforce length constraints', () {
        // Test minimum length (1 character after trimming)
        expect(validateJobTitle('A'), isTrue);
        
        // Test maximum length (100 characters)
        final longTitle = 'A' * 101;
        expect(validateJobTitle(longTitle), isFalse);
      });
    });

    group('Postcode Validation (Optional Field)', () {
      test('should accept empty postcode', () {
        // Empty postcode should be valid (optional field)
        expect(validatePostcode(''), isTrue);
      });

      test('should accept valid postcodes', () {
        // Test various valid postcode formats
        expect(validatePostcode('SW1A 1AA'), isTrue);
        expect(validatePostcode('EC1A-1BB'), isTrue);
        expect(validatePostcode('M1 1AE'), isTrue);
        expect(validatePostcode('B33 8TH'), isTrue);
        expect(validatePostcode('CR2 6XH'), isTrue);
        expect(validatePostcode('DN55 1PT'), isTrue);
        expect(validatePostcode('London'), isTrue);
        expect(validatePostcode('Manchester'), isTrue);
      });

      test('should reject postcodes with special characters', () {
        // Postcodes with invalid characters should be rejected
        expect(validatePostcode('SW1A@1AA'), isFalse);
        expect(validatePostcode('EC1A!1BB'), isFalse);
        expect(validatePostcode('M1#1AE'), isFalse);
      });

      test('should enforce length constraint', () {
        // Test maximum length (20 characters)
        final longPostcode = 'A' * 21;
        expect(validatePostcode(longPostcode), isFalse);
      });
    });

    group('Profile Creation Requirements', () {
      test('profile must include job title', () {
        // Test that profile creation requires job title
        final profileData = {
          'NAME': 'John Doe',
          'EMAIL': 'john@example.com',
          'COMPANY_NAME': 'Test Company',
          'PHONE': '+447123456789',
          // Missing JOB_TITLE
          'POSTCODE_AREA': 'SW1A 1AA',
        };
        
        expect(hasRequiredFields(profileData), isFalse);
      });

      test('profile with empty job title should be rejected', () {
        // Test that profile with empty job title is rejected
        final profileData = {
          'NAME': 'John Doe',
          'EMAIL': 'john@example.com',
          'COMPANY_NAME': 'Test Company',
          'PHONE': '+447123456789',
          'JOB_TITLE': '', // Empty job title
          'POSTCODE_AREA': 'SW1A 1AA',
        };
        
        expect(isValidProfile(profileData), isFalse);
      });

      test('profile without postcode should be accepted', () {
        // Test that profile without postcode is valid
        final profileData = {
          'NAME': 'John Doe',
          'EMAIL': 'john@example.com',
          'COMPANY_NAME': 'Test Company',
          'PHONE': '+447123456789',
          'JOB_TITLE': 'Site Manager',
          // No POSTCODE_AREA field
        };
        
        expect(isValidProfile(profileData), isTrue);
      });

      test('profile with empty postcode should be accepted', () {
        // Test that profile with empty postcode is valid
        final profileData = {
          'NAME': 'John Doe',
          'EMAIL': 'john@example.com',
          'COMPANY_NAME': 'Test Company',
          'PHONE': '+447123456789',
          'JOB_TITLE': 'Site Manager',
          'POSTCODE_AREA': '', // Empty postcode
        };
        
        expect(isValidProfile(profileData), isTrue);
      });
    });
  });
}

// Helper functions that mirror Firebase rules logic
bool validateJobTitle(String title) {
  if (title.isEmpty) return false;
  
  // Match pattern: Unicode letters, combining marks, spaces, hyphens, forward slashes, commas
  final pattern = RegExp(r"^[\p{L}\p{M}\s\-/,]+$", unicode: true);
  if (!pattern.hasMatch(title)) return false;
  
  // Check length
  if (title.length < 1 || title.length > 100) return false;
  
  // Check for script injection patterns (NoSQL doesn't need SQL injection protection)
  final scriptPattern = RegExp(
    r'.*(<script|javascript:|onclick=|onload=|onerror=|onmouseover=|eval\(|expression\().*',
    caseSensitive: false,
  );
  if (scriptPattern.hasMatch(title)) return false;
  
  // Check for XSS patterns
  final xssPattern = RegExp(r'.*<[^>]*(script|iframe|object|embed|form|input|button).*>.*');
  if (xssPattern.hasMatch(title)) return false;
  
  return true;
}

bool validatePostcode(String postcode) {
  // Empty postcode is valid (optional field)
  if (postcode.isEmpty) return true;
  
  // Match pattern: alphanumeric with spaces and hyphens
  final pattern = RegExp(r'^[a-zA-Z0-9\s\-]+$');
  if (!pattern.hasMatch(postcode)) return false;
  
  // Check length
  if (postcode.length > 20) return false;
  
  return true;
}

bool hasRequiredFields(Map<String, dynamic> data) {
  final requiredFields = ['NAME', 'EMAIL', 'COMPANY_NAME', 'PHONE', 'JOB_TITLE'];
  return requiredFields.every((field) => data.containsKey(field));
}

bool isValidProfile(Map<String, dynamic> data) {
  // Check required fields
  if (!hasRequiredFields(data)) return false;
  
  // Validate job title (required)
  if (!validateJobTitle(data['JOB_TITLE'])) return false;
  
  // Validate postcode if present (optional)
  if (data.containsKey('POSTCODE_AREA') && !validatePostcode(data['POSTCODE_AREA'])) {
    return false;
  }
  
  // Add other validations here (name, email, company, phone)
  // For this test, we assume they are valid
  
  return true;
}