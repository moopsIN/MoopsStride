import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color accentColor = Color(0xFF00E5FF); // Electric Cyan
  static const Color backgroundDark = Color(0xFF0B0D17); // Deep near-black
  static const Color surfaceDark = Color(0xFF151828); // Slightly lighter for cards
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFF9E9EA7);

  // Light Mode Colors (Secondary)
  static const Color backgroundLight = Color(0xFFF4F5F7);
  static const Color surfaceLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF0B0D17);
  static const Color textSecondaryLight = Color(0xFF6B6C7E);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: accentColor,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor,
        surface: surfaceDark,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(color: textPrimaryDark, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.plusJakartaSans(color: textPrimaryDark, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.plusJakartaSans(color: textPrimaryDark),
        bodyMedium: GoogleFonts.plusJakartaSans(color: textSecondaryDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: backgroundDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundLight,
      primaryColor: accentColor,
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        secondary: accentColor,
        surface: surfaceLight,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.light).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.plusJakartaSans(color: textPrimaryLight, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.plusJakartaSans(color: textPrimaryLight),
        bodyMedium: GoogleFonts.plusJakartaSans(color: textSecondaryLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: textPrimaryLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
