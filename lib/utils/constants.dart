import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppColors {
  static const Color primary = Color(0xFF0B7A42);
  static const Color background = Color(0xFFF8F9FA);
  static const Color expense = Color(0xFFE53935);
  static const Color income = Color(0xFF4CAF50);
  static const Color textMain = Color(0xFF333333);
  static const Color textLight = Color(0xFF757575);
  static const Color cardShadow = Color(0x1A000000);
}

class AppStyles {
  static final formatCurrency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
}
