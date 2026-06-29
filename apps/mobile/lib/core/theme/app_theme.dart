import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F4B3A),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
