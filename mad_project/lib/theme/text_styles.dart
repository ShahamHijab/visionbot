import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extension to ensure all TextStyles use Ubuntu font
extension UbuntuTextStyle on TextStyle {
  /// Returns a copy of this TextStyle with Ubuntu font applied
  TextStyle get ubuntu {
    return copyWith(fontFamily: GoogleFonts.ubuntu().fontFamily);
  }
}

/// Predefined Ubuntu text styles (like CSS utilities)
class AppTextStyles {
  static TextStyle get heading1 => GoogleFonts.ubuntu(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );

  static TextStyle get heading2 => GoogleFonts.ubuntu(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static TextStyle get heading3 =>
      GoogleFonts.ubuntu(fontSize: 24, fontWeight: FontWeight.w700);

  static TextStyle get body =>
      GoogleFonts.ubuntu(fontSize: 16, fontWeight: FontWeight.w500);

  static TextStyle get bodySmall =>
      GoogleFonts.ubuntu(fontSize: 14, fontWeight: FontWeight.w500);

  static TextStyle get caption =>
      GoogleFonts.ubuntu(fontSize: 12, fontWeight: FontWeight.w400);

  static TextStyle get button => GoogleFonts.ubuntu(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}
