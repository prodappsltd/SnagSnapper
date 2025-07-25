import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';

void main() {
  group('ValidationRules Tests', () {
    group('Name Validation', () {
      test('should allow valid names without numbers', () {
        // Test various valid names
        expect(ValidationRules.validateName('John Smith'), isNull);
        expect(ValidationRules.validateName('Mary-Jane'), isNull);
        expect(ValidationRules.validateName("O'Connor"), isNull);
        expect(ValidationRules.validateName('François'), isNull);
        expect(ValidationRules.validateName('José María'), isNull);
        expect(ValidationRules.validateName('李明'), isNull); // Chinese
        expect(ValidationRules.validateName('محمد'), isNull); // Arabic
        expect(ValidationRules.validateName('Владимир'), isNull); // Russian
      });

      test('should allow names with numbers (new requirement)', () {
        // Test names with numbers - these should pass with new validation
        expect(ValidationRules.validateName('John III'), isNull);
        expect(ValidationRules.validateName('Mary 2nd'), isNull);
        expect(ValidationRules.validateName('Henry VIII'), isNull);
        expect(ValidationRules.validateName('Louis XIV'), isNull);
        expect(ValidationRules.validateName('John 3rd'), isNull);
      });

      test('should reject empty or whitespace-only names', () {
        expect(ValidationRules.validateName(''), equals('Name is required'));
        expect(ValidationRules.validateName('   '), equals('Name is required'));
        expect(ValidationRules.validateName(null), equals('Name is required'));
      });

      test('should reject names that are too short', () {
        expect(ValidationRules.validateName('J'), 
            equals('Name must be at least 2 characters'));
      });

      test('should reject names that are too long', () {
        final longName = 'A' * 101;
        expect(ValidationRules.validateName(longName), 
            equals('Name must be less than 100 characters'));
      });

      test('should reject names with invalid characters', () {
        expect(ValidationRules.validateName('John@Smith'), 
            equals('Name can only contain letters, numbers, spaces, hyphens, and apostrophes'));
        expect(ValidationRules.validateName('Mary!Jane'), 
            equals('Name can only contain letters, numbers, spaces, hyphens, and apostrophes'));
        expect(ValidationRules.validateName('Test#Name'), 
            equals('Name can only contain letters, numbers, spaces, hyphens, and apostrophes'));
      });

      test('should trim whitespace before validation', () {
        expect(ValidationRules.validateName('  John Smith  '), isNull);
        expect(ValidationRules.validateName('  J  '), 
            equals('Name must be at least 2 characters'));
      });
    });

    group('Company Name Validation', () {
      test('should allow valid company names', () {
        expect(ValidationRules.validateCompanyName('ABC Corporation'), isNull);
        expect(ValidationRules.validateCompanyName('Smith & Jones Ltd.'), isNull);
        expect(ValidationRules.validateCompanyName('Tech Solutions (UK)'), isNull);
        expect(ValidationRules.validateCompanyName('Company, Inc.'), isNull);
        expect(ValidationRules.validateCompanyName('123 Industries'), isNull);
      });

      test('should allow company names with / and + (new requirement)', () {
        expect(ValidationRules.validateCompanyName('ABC/DEF Solutions'), isNull);
        expect(ValidationRules.validateCompanyName('A+ Construction'), isNull);
        expect(ValidationRules.validateCompanyName('Smith/Jones Partners'), isNull);
        expect(ValidationRules.validateCompanyName('Tech+ Innovations'), isNull);
      });

      test('should allow Unicode numbers in company names', () {
        expect(ValidationRules.validateCompanyName('Company ١٢٣'), isNull); // Arabic
        expect(ValidationRules.validateCompanyName('会社 一二三'), isNull); // Japanese
        expect(ValidationRules.validateCompanyName('कंपनी १२३'), isNull); // Hindi
      });

      test('should reject empty company names', () {
        expect(ValidationRules.validateCompanyName(''), 
            equals('Company name is required'));
        expect(ValidationRules.validateCompanyName(null), 
            equals('Company name is required'));
      });

      test('should enforce length constraints', () {
        expect(ValidationRules.validateCompanyName('A'), 
            equals('Company name must be at least 2 characters'));
        
        final longName = 'A' * 201;
        expect(ValidationRules.validateCompanyName(longName), 
            equals('Company name must be less than 200 characters'));
      });

      test('should reject invalid characters', () {
        expect(ValidationRules.validateCompanyName('Company@email'), 
            equals('Company name contains invalid characters'));
        expect(ValidationRules.validateCompanyName('Test<Script>'), 
            equals('Company name contains invalid characters'));
      });
    });

    group('Phone Validation', () {
      test('should allow valid international phone formats', () {
        expect(ValidationRules.validatePhone('1234567'), isNull);
        expect(ValidationRules.validatePhone('+447123456789'), isNull);
        expect(ValidationRules.validatePhone('07123456789'), isNull);
        expect(ValidationRules.validatePhone('+12025551234'), isNull);
        expect(ValidationRules.validatePhone('123456789012345'), isNull); // 15 digits
      });

      test('should reject invalid phone numbers', () {
        expect(ValidationRules.validatePhone(''), 
            equals('Phone number is required'));
        expect(ValidationRules.validatePhone('123'), 
            equals('Please enter a valid phone number (7-15 digits)'));
        expect(ValidationRules.validatePhone('1234567890123456'), 
            equals('Please enter a valid phone number (7-15 digits)')); // 16 digits
        expect(ValidationRules.validatePhone('abc123'), 
            equals('Please enter a valid phone number (7-15 digits)'));
        expect(ValidationRules.validatePhone('+44-7123-456789'), 
            equals('Please enter a valid phone number (7-15 digits)')); // No dashes allowed
      });
    });

    group('Job Title Validation', () {
      test('should allow valid job titles', () {
        expect(ValidationRules.validateJobTitle('Site Manager'), isNull);
        expect(ValidationRules.validateJobTitle('Senior Developer'), isNull);
        expect(ValidationRules.validateJobTitle('VP Sales/Marketing'), isNull);
        expect(ValidationRules.validateJobTitle('Director, Operations'), isNull);
      });

      test('should allow empty job title (validation logic handles empty strings)', () {
        // The ValidationRules.validateJobTitle method still allows empty strings
        // The required check is done in the UI validator
        expect(ValidationRules.validateJobTitle(''), isNull);
        expect(ValidationRules.validateJobTitle(null), isNull);
      });

      test('should reject job titles with numbers', () {
        expect(ValidationRules.validateJobTitle('Manager 2'), 
            equals('Job title contains invalid characters'));
      });

      test('should enforce length constraint', () {
        final longTitle = 'A' * 101;
        expect(ValidationRules.validateJobTitle(longTitle), 
            equals('Job title must be less than 100 characters'));
      });
    });

    group('Pattern Tests', () {
      test('name pattern should match expected format', () {
        // Test the regex directly
        final pattern = ValidationRules.namePattern;
        
        // Should match
        expect(pattern.hasMatch('John Smith'), isTrue);
        expect(pattern.hasMatch('Mary-Jane'), isTrue);
        expect(pattern.hasMatch("O'Connor"), isTrue);
        expect(pattern.hasMatch('José María'), isTrue);
        expect(pattern.hasMatch('李明'), isTrue);
        expect(pattern.hasMatch('John 123'), isTrue); // Numbers allowed
        
        // Should not match
        expect(pattern.hasMatch('John@Smith'), isFalse);
        expect(pattern.hasMatch('Test!'), isFalse);
      });

      test('company pattern should match expected format', () {
        final pattern = ValidationRules.companyPattern;
        
        // Should match
        expect(pattern.hasMatch('ABC Corp'), isTrue);
        expect(pattern.hasMatch('Smith & Jones'), isTrue);
        expect(pattern.hasMatch('Company (UK)'), isTrue);
        expect(pattern.hasMatch('Tech, Inc.'), isTrue);
        expect(pattern.hasMatch('ABC/DEF'), isTrue); // Forward slash
        expect(pattern.hasMatch('A+ Solutions'), isTrue); // Plus sign
        
        // Should not match
        expect(pattern.hasMatch('Company@email'), isFalse);
        expect(pattern.hasMatch('Test!'), isFalse);
      });

      test('phone pattern should match expected format', () {
        final pattern = ValidationRules.phonePattern;
        
        // Should match
        expect(pattern.hasMatch('+447123456789'), isTrue);
        expect(pattern.hasMatch('07123456789'), isTrue);
        expect(pattern.hasMatch('1234567'), isTrue);
        
        // Should not match
        expect(pattern.hasMatch('123'), isFalse);
        expect(pattern.hasMatch('abc123'), isFalse);
        expect(pattern.hasMatch('+44-7123-456789'), isFalse);
      });
    });
  });
}