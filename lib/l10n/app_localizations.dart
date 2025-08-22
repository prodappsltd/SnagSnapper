import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// App Localization Setup Guide
/// 
/// To add internationalization support to SnagSnapper:
/// 
/// 1. Add dependencies to pubspec.yaml:
/// ```yaml
/// dependencies:
///   flutter_localizations:
///     sdk: flutter
///   intl: ^0.18.0
/// 
/// dev_dependencies:
///   flutter_gen: ^5.3.2
/// ```
/// 
/// 2. Configure localization in pubspec.yaml:
/// ```yaml
/// flutter:
///   generate: true
/// ```
/// 
/// 3. Create l10n.yaml in project root:
/// ```yaml
/// arb-dir: lib/l10n
/// template-arb-file: app_en.arb
/// output-localization-file: app_localizations.dart
/// ```
/// 
/// 4. Create ARB files for each language in lib/l10n/:
/// - app_en.arb (English)
/// - app_es.arb (Spanish)
/// - app_fr.arb (French)
/// - app_de.arb (German)
/// - app_zh.arb (Chinese)
/// - app_ar.arb (Arabic)
/// - app_hi.arb (Hindi)
/// - app_ja.arb (Japanese)
/// 
/// 5. Update main.dart:
/// ```dart
/// import 'package:flutter_localizations/flutter_localizations.dart';
/// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
/// 
/// MaterialApp(
///   localizationsDelegates: [
///     AppLocalizations.delegate,
///     GlobalMaterialLocalizations.delegate,
///     GlobalWidgetsLocalizations.delegate,
///     GlobalCupertinoLocalizations.delegate,
///   ],
///   supportedLocales: [
///     Locale('en'), // English
///     Locale('es'), // Spanish
///     Locale('fr'), // French
///     Locale('de'), // German
///     Locale('zh'), // Chinese
///     Locale('ar'), // Arabic
///     Locale('hi'), // Hindi
///     Locale('ja'), // Japanese
///   ],
///   locale: _currentLocale, // User selected locale
/// )
/// ```

/// Sample ARB file structure (app_en.arb):
const String sampleArbFile = '''
{
  "@@locale": "en",
  "appTitle": "SnagSnapper",
  "@appTitle": {
    "description": "The title of the application"
  },
  
  "welcomeMessage": "Welcome to SnagSnapper",
  "@welcomeMessage": {
    "description": "Welcome message shown on home screen"
  },
  
  "signIn": "Sign In",
  "@signIn": {
    "description": "Sign in button text"
  },
  
  "signUp": "Sign Up",
  "@signUp": {
    "description": "Sign up button text"
  },
  
  "email": "Email",
  "@email": {
    "description": "Email field label"
  },
  
  "password": "Password",
  "@password": {
    "description": "Password field label"
  },
  
  "forgotPassword": "Forgot Password?",
  "@forgotPassword": {
    "description": "Forgot password link text"
  },
  
  "profile": "Profile",
  "@profile": {
    "description": "Profile screen title"
  },
  
  "settings": "Settings",
  "@settings": {
    "description": "Settings screen title"
  },
  
  "language": "Language",
  "@language": {
    "description": "Language selection label"
  },
  
  "save": "Save",
  "@save": {
    "description": "Save button text"
  },
  
  "cancel": "Cancel",
  "@cancel": {
    "description": "Cancel button text"
  },
  
  "delete": "Delete",
  "@delete": {
    "description": "Delete button text"
  },
  
  "confirmDelete": "Are you sure you want to delete?",
  "@confirmDelete": {
    "description": "Delete confirmation message"
  },
  
  "loading": "Loading...",
  "@loading": {
    "description": "Loading indicator text"
  },
  
  "error": "Error",
  "@error": {
    "description": "Error title"
  },
  
  "success": "Success",
  "@success": {
    "description": "Success title"
  },
  
  "retry": "Retry",
  "@retry": {
    "description": "Retry button text"
  }
}
''';

/// Language model for app
class Language {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final TextDirection textDirection;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.textDirection = TextDirection.ltr,
  });
}

/// Supported languages
class AppLanguages {
  static const List<Language> supportedLanguages = [
    Language(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
    ),
    Language(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    Language(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
    ),
    Language(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
    ),
    Language(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
    ),
    Language(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
      textDirection: TextDirection.rtl,
    ),
    Language(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      flag: '🇮🇳',
    ),
    Language(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
    ),
    Language(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇵🇹',
    ),
    Language(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
    ),
  ];

  static Language getLanguageByCode(String code) {
    return supportedLanguages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => supportedLanguages.first,
    );
  }
}

/// Locale storage helper
class LocaleStorage {
  static const String _localeKey = 'selected_locale';

  static Future<void> saveLocale(String languageCode) async {
    // Save to shared preferences
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString(_localeKey, languageCode);
  }

  static Future<String?> getLocale() async {
    // Get from shared preferences
    // final prefs = await SharedPreferences.getInstance();
    // return prefs.getString(_localeKey);
    return null;
  }
}