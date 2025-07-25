import 'package:flutter_test/flutter_test.dart';
import 'package:snagsnapper/Constants/validation_rules.dart';

void main() {
  group('Validation Pattern Tests', () {
    group('Job Title Validation', () {
      test('should support Unicode characters', () {
        // Test various Unicode job titles
        final unicodeJobTitles = [
          'Gerente de Vendas',      // Portuguese
          'Directeur Général',       // French
          'Geschäftsführer',        // German
          'プロジェクトマネージャー',  // Japanese
          'مدير المشروع',           // Arabic
          'Προϊστάμενος',           // Greek
          '经理',                    // Chinese
          'Müdür',                  // Turkish
          'Менеджер',               // Russian
          'מנהל',                   // Hebrew
        ];
        
        for (final title in unicodeJobTitles) {
          expect(
            ValidationRules.validateJobTitle(title), 
            isNull,
            reason: 'Should accept Unicode job title: $title'
          );
        }
      });
      
      test('should reject job titles with numbers', () {
        // Current implementation rejects numbers
        expect(
          ValidationRules.validateJobTitle('Manager 2'), 
          equals('Job title contains invalid characters')
        );
        expect(
          ValidationRules.validateJobTitle('Level 3 Engineer'), 
          equals('Job title contains invalid characters')
        );
      });
      
      test('pattern should match expected Unicode format', () {
        final pattern = ValidationRules.jobTitlePattern;
        
        // Should match Unicode letters
        expect(pattern.hasMatch('Manager'), isTrue);
        expect(pattern.hasMatch('Gerente'), isTrue);
        expect(pattern.hasMatch('مدير'), isTrue);
        expect(pattern.hasMatch('経理'), isTrue);
        
        // Should match with allowed punctuation
        expect(pattern.hasMatch('VP, Sales'), isTrue);
        expect(pattern.hasMatch('Director/Manager'), isTrue);
        expect(pattern.hasMatch('Part-time Worker'), isTrue);
        
        // Should not match with numbers or invalid chars
        expect(pattern.hasMatch('Manager1'), isFalse);
        expect(pattern.hasMatch('CEO@Company'), isFalse);
        expect(pattern.hasMatch('Director!'), isFalse);
      });
    });
    
    group('Cross-validation Consistency', () {
      test('all fields should handle Unicode characters consistently', () {
        // Names - allows Unicode and numbers
        expect(ValidationRules.validateName('José García 3rd'), isNull);
        expect(ValidationRules.validateName('李明'), isNull);
        expect(ValidationRules.validateName('Müller'), isNull);
        
        // Company names - allows Unicode letters and numbers
        expect(ValidationRules.validateCompanyName('Société Générale'), isNull);
        expect(ValidationRules.validateCompanyName('Company 123'), isNull);
        expect(ValidationRules.validateCompanyName('A+ Solutions'), isNull);
        expect(ValidationRules.validateCompanyName('Tech/Media Corp'), isNull);
        
        // Job titles - allows Unicode but NOT numbers
        expect(ValidationRules.validateJobTitle('Ingénieur'), isNull);
        expect(ValidationRules.validateJobTitle('工程师'), isNull);
        expect(
          ValidationRules.validateJobTitle('Engineer 2'), 
          equals('Job title contains invalid characters')
        );
      });
    });
    
    test('IMPORTANT: Firebase rules should be manually verified to match', () {
      // This test serves as a reminder to check Firebase rules
      print('\n⚠️  REMINDER: Manually verify that Firebase rules match these patterns:');
      print('Name pattern: ${ValidationRules.namePattern.pattern}');
      print('Company pattern: ${ValidationRules.companyPattern.pattern}');
      print('Phone pattern: ${ValidationRules.phonePattern.pattern}');  
      print('Job title pattern: ${ValidationRules.jobTitlePattern.pattern}');
      print('\nFirebase rules should use the same patterns with double escapes (\\\\)');
      
      // This test always passes but prints a reminder
      expect(true, isTrue);
    });
  });
}