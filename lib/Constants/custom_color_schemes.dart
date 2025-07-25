import 'package:flutter/material.dart';

/// Custom color schemes that maintain orange tones without Material 3's brown generation
class CustomColorSchemes {
  /// Bright construction orange theme
  static ColorScheme orangeLight = const ColorScheme(
    brightness: Brightness.light,
    // Primary colors - bright orange
    primary: Color(0xFFFF6600),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE4CC),
    onPrimaryContainer: Color(0xFF331100),
    
    // Secondary colors - complementary blue
    secondary: Color(0xFF0066CC),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFCCE4FF),
    onSecondaryContainer: Color(0xFF001133),
    
    // Tertiary colors - teal accent
    tertiary: Color(0xFF00AA88),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFCCFFEE),
    onTertiaryContainer: Color(0xFF003322),
    
    // Error colors
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    
    // Surface colors
    surface: Color(0xFFFFFBFF),
    onSurface: Color(0xFF1C1B1E),
    surfaceContainerHighest: Color(0xFFE8E2E9),
    onSurfaceVariant: Color(0xFF49454E),
    
    // Other colors
    outline: Color(0xFF7A757F),
    outlineVariant: Color(0xFFCAC4CF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF313033),
    onInverseSurface: Color(0xFFF4EFF4),
    inversePrimary: Color(0xFFFFB380),
  );
  
  /// Dark mode with orange accents
  static ColorScheme orangeDark = const ColorScheme(
    brightness: Brightness.dark,
    // Primary colors - bright orange
    primary: Color(0xFFFFB380),
    onPrimary: Color(0xFF502400),
    primaryContainer: Color(0xFF723600),
    onPrimaryContainer: Color(0xFFFFDCC5),
    
    // Secondary colors - complementary blue
    secondary: Color(0xFF99CCFF),
    onSecondary: Color(0xFF003366),
    secondaryContainer: Color(0xFF004C99),
    onSecondaryContainer: Color(0xFFCCE4FF),
    
    // Tertiary colors - teal accent
    tertiary: Color(0xFF66DDBB),
    onTertiary: Color(0xFF00442F),
    tertiaryContainer: Color(0xFF006644),
    onTertiaryContainer: Color(0xFFCCFFEE),
    
    // Error colors
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    
    // Surface colors
    surface: Color(0xFF1C1B1E),
    onSurface: Color(0xFFE6E1E6),
    surfaceContainerHighest: Color(0xFF49454E),
    onSurfaceVariant: Color(0xFFCAC4CF),
    
    // Other colors
    outline: Color(0xFF948F99),
    outlineVariant: Color(0xFF49454E),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6E1E6),
    onInverseSurface: Color(0xFF313033),
    inversePrimary: Color(0xFF914A00),
  );
  
  /// Alternative bright safety orange theme
  static ColorScheme safetyOrangeLight = const ColorScheme(
    brightness: Brightness.light,
    // Primary colors - safety orange
    primary: Color(0xFFFF7700),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE8D1),
    onPrimaryContainer: Color(0xFF3D1A00),
    
    // Secondary colors - purple contrast
    secondary: Color(0xFF7755CC),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE8D1FF),
    onSecondaryContainer: Color(0xFF1A003D),
    
    // Tertiary colors - green accent
    tertiary: Color(0xFF55CC00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD1FFCC),
    onTertiaryContainer: Color(0xFF1A3D00),
    
    // Error colors
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    
    // Surface colors
    surface: Color(0xFFFFFBFF),
    onSurface: Color(0xFF1C1B1E),
    surfaceContainerHighest: Color(0xFFE8E2E9),
    onSurfaceVariant: Color(0xFF49454E),
    
    // Other colors
    outline: Color(0xFF7A757F),
    outlineVariant: Color(0xFFCAC4CF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF313033),
    onInverseSurface: Color(0xFFF4EFF4),
    inversePrimary: Color(0xFFFFBB80),
  );
}