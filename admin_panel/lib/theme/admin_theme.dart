import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTheme {
  // Brand Palette
  static const Color bgDark = Color(0xFF0B0F19);
  static const Color surfaceDark = Color(0xFF131C2E);
  static const Color surfaceCard = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF2E3D52);

  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentPurple = Color(0xFF8B5CF6);

  // Status Badges
  static const Color statusOnline = Color(0xFF10B981); // Emerald
  static const Color statusPending = Color(0xFFF59E0B); // Amber
  static const Color statusVerified = Color(0xFF3B82F6); // Blue
  static const Color statusDanger = Color(0xFFEF4444); // Red
  static const Color textMuted = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlassGradient = LinearGradient(
    colors: [Color(0x1F1E293B), Color(0x0F0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    final baseText = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentCyan,
        surface: surfaceDark,
        error: statusDanger,
      ),
      textTheme: baseText.copyWith(
        displayLarge: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.inter(
          color: Colors.white70,
        ),
        bodySmall: GoogleFonts.inter(
          color: textMuted,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderDark),
        ),
      ),
      dividerColor: borderDark,
    );
  }
}
