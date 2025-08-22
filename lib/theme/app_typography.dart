import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized typography configuration for the app
/// Using Google Fonts that support multiple languages and scripts
class AppTypography {
  // Primary font for headings - supports Latin, Cyrillic, Greek, Vietnamese
  static TextStyle montserrat({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Secondary font for body text - excellent multi-language support
  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Display font - good for headings, supports extended Latin
  static TextStyle poppins({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.poppins(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Fallback font with extensive language support
  // Noto Sans supports almost all languages including CJK
  static TextStyle notoSans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.notoSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // App-wide text styles
  static TextStyle displayLarge = poppins(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static TextStyle displayMedium = poppins(
    fontSize: 28,
    fontWeight: FontWeight.w600,
  );

  static TextStyle displaySmall = poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static TextStyle headlineLarge = montserrat(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static TextStyle headlineMedium = montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w500,
  );

  static TextStyle headlineSmall = montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  static TextStyle titleLarge = inter(
    fontSize: 20,
    fontWeight: FontWeight.w500,
  );

  static TextStyle titleMedium = inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static TextStyle titleSmall = inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle bodyLarge = inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static TextStyle bodyMedium = inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static TextStyle bodySmall = inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  static TextStyle labelLarge = inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle labelMedium = inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static TextStyle labelSmall = inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // Button text style
  static TextStyle button = inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.25,
  );

  // Caption text style
  static TextStyle caption = inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  // Overline text style
  static TextStyle overline = inter(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.5,
  );
}

/// Font recommendations for internationalization:
/// 
/// 1. **Noto Sans Family** - Best for true international support
///    - Supports: All languages including Arabic, Hebrew, CJK (Chinese, Japanese, Korean)
///    - Use: GoogleFonts.notoSans() for Latin, GoogleFonts.notoSansArabic() for Arabic, etc.
/// 
/// 2. **Inter** - Excellent for Latin-based languages
///    - Supports: Latin, Cyrillic, Greek, Vietnamese
///    - Very readable at all sizes
/// 
/// 3. **Roboto** - Good general purpose
///    - Supports: Latin, Cyrillic, Greek
///    - Material Design standard
/// 
/// 4. **Source Sans Pro** - Professional and clean
///    - Supports: Extended Latin, Cyrillic, Greek, Vietnamese
/// 
/// For RTL languages (Arabic, Hebrew):
/// - Use GoogleFonts.notoSansArabic() or GoogleFonts.notoSansHebrew()
/// - Wrap content in Directionality widget
/// 
/// For CJK languages:
/// - GoogleFonts.notoSansSC() for Simplified Chinese
/// - GoogleFonts.notoSansTC() for Traditional Chinese  
/// - GoogleFonts.notoSansJP() for Japanese
/// - GoogleFonts.notoSansKR() for Korean