import 'dart:convert';

class ReceiptModel {
  final String merchantName;
  final DateTime date;
  final double totalAmount;
  final String category;

  ReceiptModel({
    required this.merchantName,
    required this.date,
    required this.totalAmount,
    required this.category,
  });

  /// Mengubah JSON dari Gemini menjadi Objek Dart
  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      merchantName: json['merchant_name'] ?? 'Merchant Tidak Diketahui',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      category: _mapCategory(json['category'] ?? ''),
    );
  }

  /// Mapping kategori bahasa Inggris dari Gemini → kategori Indonesia di app
  static String _mapCategory(String geminiCategory) {
    final lower = geminiCategory.toLowerCase();

    if (lower.contains('food') ||
        lower.contains('dining') ||
        lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('makan') ||
        lower.contains('minum')) {
      return 'Makan & Minum';
    }
    if (lower.contains('transport') ||
        lower.contains('travel') ||
        lower.contains('fuel') ||
        lower.contains('gas') ||
        lower.contains('parking')) {
      return 'Transportasi';
    }
    if (lower.contains('shop') ||
        lower.contains('retail') ||
        lower.contains('grocery') ||
        lower.contains('supermarket') ||
        lower.contains('belanja') ||
        lower.contains('minimarket')) {
      return 'Belanja';
    }
    return 'Lainnya';
  }

  /// Helper: Parse JSON string dari respons Gemini (membersihkan markdown fences jika ada)
  static ReceiptModel parseFromGeminiResponse(String responseText) {
    String cleaned = responseText.trim();

    // Hapus markdown code fences jika Gemini menambahkannya
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
      cleaned = cleaned.trim();
    }

    final Map<String, dynamic> decoded = json.decode(cleaned);
    return ReceiptModel.fromJson(decoded);
  }
}
