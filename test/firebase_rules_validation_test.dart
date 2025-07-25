import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper functions for validation
  bool hasNoSQLInjection(String value) {
    final sqlInjectionPattern = RegExp(
      r'.*(DROP|DELETE|INSERT|UPDATE|SELECT|UNION|EXEC|SCRIPT).*',
      caseSensitive: false,
    );
    return !sqlInjectionPattern.hasMatch(value);
  }
  
  bool hasNoXSS(String value) {
    final xssPattern = RegExp(
      r'.*<[^>]*(script|iframe|object|embed|form|input|button).*>.*',
    );
    return !xssPattern.hasMatch(value);
  }

  group('User Profile Values Test', () {
    // Test ALL Firebase validation rules
    test('Test complete Firebase validation for user profile', () {
      // User's actual values
      final Map<String, dynamic> profileData = {
        'NAME': 'D Singh',
        'EMAIL': 'dj@productiveapps.co.uk', // Using likely email
        'COMPANY_NAME': 'Productive Apps',
        'PHONE': '+447123456789',
        'JOB_TITLE': '', // Empty optional field
        'POSTCODE_AREA': '', // Empty optional field
        'DATE_FORMAT': 'dd-MM-yyyy',
        'IMAGE': '', // Empty optional field
        'SIGNATURE': '', // Empty optional field
        'LIST_OF_COLLEAGUES': [],
        'LIST_OF_SITE_PATHS': {},
        // Note: LAST_UPDATED would be FieldValue.serverTimestamp() in real usage
      };
      
      // Validate string length
      bool isValidStringLength(String field, int minLength, int maxLength) {
        return field.length >= minLength && field.length <= maxLength;
      }
      
      // Validate email format
      bool isValidEmail(String email) {
        final emailPattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
        return emailPattern.hasMatch(email);
      }
      
      // Validate phone format
      bool isValidPhone(String phone) {
        final phonePattern = RegExp(r'^\+?[0-9]{7,15}$');
        return phonePattern.hasMatch(phone);
      }
      
      // Validate name
      bool isValidName(String name) {
        final namePattern = RegExp(r"^[\p{L}\p{M}0-9\s\-']+$", unicode: true);
        return namePattern.hasMatch(name) &&
               isValidStringLength(name, 2, 100) &&
               hasNoSQLInjection(name) &&
               hasNoXSS(name);
      }
      
      // Validate company name
      bool isValidCompanyName(String company) {
        final companyPattern = RegExp(r"^[\p{L}\p{M}\p{N}\s\-&.,()\\+/]+$", unicode: true);
        return companyPattern.hasMatch(company) &&
               isValidStringLength(company, 2, 200) &&
               hasNoSQLInjection(company) &&
               hasNoXSS(company);
      }
      
      print('\nValidating all Firebase rules:');
      print('\n1. NAME: "${profileData['NAME']}"');
      print('   - Length check (2-100): ${isValidStringLength(profileData['NAME'] as String, 2, 100) ? "PASS" : "FAIL"}');
      print('   - Pattern check: ${RegExp(r"^[\p{L}\p{M}0-9\s\-']+$", unicode: true).hasMatch(profileData['NAME'] as String) ? "PASS" : "FAIL"}');
      print('   - SQL injection: ${hasNoSQLInjection(profileData['NAME'] as String) ? "PASS" : "FAIL"}');
      print('   - XSS check: ${hasNoXSS(profileData['NAME'] as String) ? "PASS" : "FAIL"}');
      print('   - Overall: ${isValidName(profileData['NAME'] as String) ? "PASS" : "FAIL"}');
      
      print('\n2. EMAIL: "${profileData['EMAIL']}"');
      print('   - Valid format: ${isValidEmail(profileData['EMAIL'] as String) ? "PASS" : "FAIL"}');
      
      print('\n3. COMPANY_NAME: "${profileData['COMPANY_NAME']}"');
      print('   - Length check (2-200): ${isValidStringLength(profileData['COMPANY_NAME'] as String, 2, 200) ? "PASS" : "FAIL"}');
      print('   - Pattern check: ${RegExp(r"^[\p{L}\p{M}\p{N}\s\-&.,()\\+/]+$", unicode: true).hasMatch(profileData['COMPANY_NAME'] as String) ? "PASS" : "FAIL"}');
      print('   - SQL injection: ${hasNoSQLInjection(profileData['COMPANY_NAME'] as String) ? "PASS" : "FAIL"}');
      print('   - XSS check: ${hasNoXSS(profileData['COMPANY_NAME'] as String) ? "PASS" : "FAIL"}');
      print('   - Overall: ${isValidCompanyName(profileData['COMPANY_NAME'] as String) ? "PASS" : "FAIL"}');
      
      print('\n4. PHONE: "${profileData['PHONE']}"');
      print('   - Valid format: ${isValidPhone(profileData['PHONE'] as String) ? "PASS" : "FAIL"}');
      
      print('\n5. Required fields check:');
      final hasAllRequired = profileData.keys.toSet().containsAll(['NAME', 'EMAIL', 'COMPANY_NAME', 'PHONE']);
      print('   - Has all required fields: ${hasAllRequired ? "PASS" : "FAIL"}');
      
      print('\n6. Field count check:');
      final allowedFields = ['NAME', 'EMAIL', 'COMPANY_NAME', 'PHONE', 'JOB_TITLE', 
                            'POSTCODE_AREA', 'DATE_FORMAT', 'IMAGE', 'SIGNATURE', 
                            'LIST_OF_COLLEAGUES', 'LIST_OF_SITE_PATHS', 'LAST_UPDATED'];
      final hasOnlyAllowed = profileData.keys.every((key) => allowedFields.contains(key));
      print('   - Only allowed fields: ${hasOnlyAllowed ? "PASS" : "FAIL"}');
      print('   - Fields present: ${profileData.keys.join(', ')}');
      
      // Overall validation
      final overallPass = isValidName(profileData['NAME'] as String) &&
                         isValidEmail(profileData['EMAIL'] as String) &&
                         isValidCompanyName(profileData['COMPANY_NAME'] as String) &&
                         isValidPhone(profileData['PHONE'] as String) &&
                         hasAllRequired &&
                         hasOnlyAllowed;
      
      print('\nOVERALL VALIDATION: ${overallPass ? "PASS" : "FAIL"}');
      
      // Additional check - simulate what happens with LAST_UPDATED
      print('\n7. LAST_UPDATED field:');
      print('   - In actual usage, this is set to FieldValue.serverTimestamp()');
      print('   - Firebase rules check: hasValidTimestamp() expects request.time');
      print('   - This cannot be tested locally but is handled by Firebase');
    });
  });
}