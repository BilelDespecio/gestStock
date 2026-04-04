import 'package:flutter/material.dart';
import 'package:gest_stock/newVersion/menu/theme_controller.dart';

class AppColors {
  static Color get backgroundColor => themeController.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FC);
  static Color get cardColor => themeController.isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFFFFFFFF);
  static Color get primaryTextColor => themeController.isDarkMode ? const Color(0xFFF3F4F6) : const Color(0xFF1F2937);
  static Color get secondaryTextColor => themeController.isDarkMode ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  static Color get accentColor => const Color(0xFF2563EB); // Common for both
  static Color get priceColor => themeController.isDarkMode ? const Color(0xFF34D399) : const Color(0xFF16A34A);
  static Color get criticalColor => themeController.isDarkMode ? const Color(0xFFF87171) : const Color(0xFFEF4444);
  static Color get alertColor => Colors.orange;
}
