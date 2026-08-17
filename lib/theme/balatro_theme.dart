import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BalatroTheme {
  // Core Balatro-inspired color palette
  static const Color deepPurple = Color(0xFF1a0d2e);
  static const Color darkPurple = Color(0xFF16213e);
  static const Color mediumPurple = Color(0xFF0f3460);
  static const Color lightPurple = Color(0xFF533483);
  static const Color neonPink = Color(0xFFe94560);
  static const Color neonBlue = Color(0xFF0f4c75);
  static const Color neonGreen = Color(0xFF16c79a);
  static const Color neonOrange = Color(0xFFf39019);
  static const Color neonYellow = Color(0xFFf7d794);
  static const Color cardBackground = Color(0xFF2c1810);
  static const Color cardBorder = Color(0xFF8b4513);
  static const Color glowColor = Color(0xFF64ffda);

  // Text colors
  static const Color primaryText = Color(0xFFffffff);
  static const Color secondaryText = Color(0xFFb0bec5);
  static const Color accentText = Color(0xFF64ffda);

  // Card suit colors - bright and visible on dark backgrounds
  static const Color heartsColor = Color(0xFFe91e63); // Bright pink/red
  static const Color diamondsColor = Color(0xFFff5722); // Bright orange
  static const Color clubsColor = Color(
    0xFF81c784,
  ); // Light green (for visibility)
  static const Color spadesColor = Color(
    0xFF90caf9,
  ); // Light blue (for visibility)

  /// Production theme with Google Fonts (use in main app)
  static ThemeData get darkTheme {
    return _buildTheme(useGoogleFonts: true);
  }

  /// Test-safe theme without Google Fonts (use in e2e tests)
  static ThemeData get testTheme {
    return _buildTheme(useGoogleFonts: false);
  }

  /// Build theme with optional Google Fonts
  static ThemeData _buildTheme({required bool useGoogleFonts}) {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.purple,
      scaffoldBackgroundColor: deepPurple,
      appBarTheme: AppBarTheme(
        backgroundColor: darkPurple,
        elevation: 8,
        shadowColor: glowColor.withValues(alpha: 0.3),
        titleTextStyle: const TextStyle(
          color: primaryText,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonPink,
          foregroundColor: primaryText,
          elevation: 6,
          shadowColor: neonPink.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        shadowColor: glowColor.withValues(alpha: 0.2),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cardBorder.withValues(alpha: 0.6), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: glowColor.withValues(alpha: 0.3), width: 2),
        ),
        titleTextStyle: const TextStyle(
          color: primaryText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(color: secondaryText, fontSize: 14),
      ),
      // M3 defaults use onInverseSurface (dark text for a light bar). Our snackbars
      // use dark neon backgrounds, so force light content text for contrast.
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(
          color: primaryText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: glowColor,
        behavior: SnackBarBehavior.floating,
      ),
      textTheme:
          (useGoogleFonts ? GoogleFonts.arimoTextTheme() : const TextTheme())
              .copyWith(
                displayLarge: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 48, // Game title size
                ),
                displayMedium: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 24, // Dialog titles, subtitles
                ),
                displaySmall: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w300,
                  fontSize: 24, // Card game subtitle
                ),
                headlineLarge: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 20, // Section headers, dialog headers
                ),
                headlineMedium: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18, // Large buttons, melds headers
                ),
                headlineSmall: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Action buttons, status text
                ),
                titleLarge: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Small buttons, round indicators
                ),
                titleMedium: const TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 18, // Scoreboard totals
                ),
                titleSmall: TextStyle(
                  color: secondaryText,
                  fontWeight: FontWeight.w600,
                ),
                bodyLarge: TextStyle(color: primaryText),
                bodyMedium: TextStyle(color: secondaryText),
                bodySmall: TextStyle(color: secondaryText),
                labelLarge: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                ),
                labelMedium: TextStyle(color: secondaryText),
                labelSmall: TextStyle(color: secondaryText),
              ),
    );
  }

  // Glow effect decoration
  static BoxDecoration glowDecoration({
    Color glowColor = BalatroTheme.glowColor,
    double blurRadius = 8.0,
    Color backgroundColor = BalatroTheme.cardBackground,
    double borderRadius = 12.0,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.3),
          blurRadius: blurRadius,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: glowColor.withValues(alpha: 0.1),
          blurRadius: blurRadius * 2,
          spreadRadius: 4,
        ),
      ],
      border: Border.all(color: glowColor.withValues(alpha: 0.4), width: 1),
    );
  }

  // Gradient backgrounds
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepPurple, darkPurple, mediumPurple],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardBackground, Color(0xFF3d2817)],
  );

  static const LinearGradient neonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [neonPink, neonBlue],
  );
}
