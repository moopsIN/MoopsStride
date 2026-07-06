import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Mode Colors (Primary)
  static const Color lightBg = Color(0xFFF5F2ED);
  static const Color lightBgAlt = Color(0xFFEDE6DA);
  static const Color lightInk = Color(0xFF0E0E0C);
  static const Color lightInkSoft = Color(0xFF2A2A26);
  static const Color lightInkMute = Color(0xFF6B6B63);
  static const Color lightLine = Color(0x1E0E0E0C); 
  static const Color lightLineSoft = Color(0x0F0E0E0C);
  static const Color lightAccent = Color(0xFFFF4D3D);
  static const Color lightAccentDeep = Color(0xFFE63B2B);

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF0E0E0C);
  static const Color darkBgAlt = Color(0xFF1A1A16);
  static const Color darkInk = Color(0xFFF5F2ED);
  static const Color darkInkSoft = Color(0xFFD8D4C8);
  static const Color darkInkMute = Color(0xFF8C8C82);
  static const Color darkLine = Color(0x1EF5F2ED);
  static const Color darkLineSoft = Color(0x0FF5F2ED);
  static const Color darkAccent = Color(0xFFFF6B5C);
  static const Color darkAccentDeep = Color(0xFFFF4D3D);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: darkAccent,
      colorScheme: const ColorScheme.dark(
        primary: darkAccent,
        secondary: darkAccentDeep,
        surface: darkBgAlt,
      ),
      dividerColor: darkLine,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(color: darkInk, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.plusJakartaSans(color: darkInk, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.plusJakartaSans(color: darkInk),
        bodyMedium: GoogleFonts.plusJakartaSans(color: darkInkSoft),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent,
          foregroundColor: darkBg,
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
      scaffoldBackgroundColor: lightBg,
      primaryColor: lightAccent,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: lightAccentDeep,
        surface: lightBgAlt,
      ),
      dividerColor: lightLine,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.light).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(color: lightInk, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.plusJakartaSans(color: lightInk, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.plusJakartaSans(color: lightInk),
        bodyMedium: GoogleFonts.plusJakartaSans(color: lightInkSoft),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightAccent,
          foregroundColor: lightBg,
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
