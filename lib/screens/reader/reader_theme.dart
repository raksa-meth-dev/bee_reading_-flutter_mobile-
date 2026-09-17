import 'package:flutter/material.dart';

enum ReaderThemeMode {
  light,
  sepia,
  dark,
}

class ReaderThemeData {
  final ReaderThemeMode mode;
  final Color backgroundColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color toolbarColor;
  final Color toolbarIconColor;
  final Color dividerColor;

  const ReaderThemeData({
    required this.mode,
    required this.backgroundColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.toolbarColor,
    required this.toolbarIconColor,
    required this.dividerColor,
  });

  static const ReaderThemeData light = ReaderThemeData(
    mode: ReaderThemeMode.light,
    backgroundColor: Color(0xFFFAF9F6),
    textColor: Color(0xFF1E1E1E),
    secondaryTextColor: Color(0xFF757575),
    toolbarColor: Color(0xFFFFFFFF),
    toolbarIconColor: Color(0xFF2C2C2C),
    dividerColor: Color(0xFFE0E0E0),
  );

  static const ReaderThemeData sepia = ReaderThemeData(
    mode: ReaderThemeMode.sepia,
    backgroundColor: Color(0xFFFBF0D9),
    textColor: Color(0xFF43301B),
    secondaryTextColor: Color(0xFF8B7355),
    toolbarColor: Color(0xFFF4E5C7),
    toolbarIconColor: Color(0xFF43301B),
    dividerColor: Color(0xFFE5D2AD),
  );

  static const ReaderThemeData dark = ReaderThemeData(
    mode: ReaderThemeMode.dark,
    backgroundColor: Color(0xFF121212),
    textColor: Color(0xFFE0E0E0),
    secondaryTextColor: Color(0xFF9E9E9E),
    toolbarColor: Color(0xFF1E1E1E),
    toolbarIconColor: Color(0xFFE0E0E0),
    dividerColor: Color(0xFF2C2C2C),
  );

  static ReaderThemeData fromMode(ReaderThemeMode mode) {
    switch (mode) {
      case ReaderThemeMode.light:
        return light;
      case ReaderThemeMode.sepia:
        return sepia;
      case ReaderThemeMode.dark:
        return dark;
    }
  }
}
