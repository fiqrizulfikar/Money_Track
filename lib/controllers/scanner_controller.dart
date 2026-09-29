import 'dart:io';
import 'package:get/get.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import '../models/receipt_model.dart';

class ScannerController extends GetxController {
  final ImagePicker _picker = ImagePicker();

  // API Key Gemini
  final String _apiKey = "AIzaSyDFfGE4mmxmFeW9aG5fdIXhc0FIw1VKwPQ";

  // Observable state
  var isLoading = false.obs;
  var scannedTotal = "".obs;
  var scannedMerchant = "".obs;
  var scannedCategory = "".obs;
  var scannedDate = Rxn<DateTime>();

  /// Scan struk menggunakan Gemini 2.5 Flash
  Future<void> scanReceipt({ImageSource source = ImageSource.gallery}) async {
    try {
      // 1. Ambil gambar dari kamera atau galeri
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null) return;

      isLoading.value = true;

      // 2. Inisialisasi model Gemini
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      // 3. Konversi gambar ke bytes
      final imageBytes = await File(image.path).readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      // 4. Prompt ketat agar Gemini HANYA membalas JSON
      final prompt = TextPart('''
Analyze this receipt image. Extract the following information and suggest a matching personal finance category (e.g., Food, Shopping, Transport, Bill, etc.).
You MUST respond ONLY with a single JSON object. Do not include any markdown formatting like ```json ... ``` or additional text.

Strict JSON Structure:
{
  "merchant_name": "String (Name of the store/shop)",
  "date": "String (Format: YYYY-MM-DD)",
  "total_amount": Number (The final total expense amount as a raw number, no currency symbols),
  "category": "String (Suggested category)"
}
''');

      // 5. Kirim ke Gemini API
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text != null) {
        // 6. Parse respons JSON → ReceiptModel
        final receipt = ReceiptModel.parseFromGeminiResponse(response.text!);

        // 7. Update semua observable → trigger reactive update di UI
        scannedTotal.value = receipt.totalAmount.toStringAsFixed(0);
        scannedMerchant.value = receipt.merchantName;
        scannedCategory.value = receipt.category;
        scannedDate.value = receipt.date;

        Get.snackbar(
          "Scan Berhasil ✅",
          "${receipt.merchantName} — Rp ${scannedTotal.value}",
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error Scan",
        "Gagal membaca struk: $e",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Alias untuk kompatibilitas dengan kode yang sudah ada di AddTransactionScreen
  Future<void> pickAndProcessImage(ImageSource source) =>
      scanReceipt(source: source);

  /// Reset semua hasil scan
  void clearScanResults() {
    scannedTotal.value = "";
    scannedMerchant.value = "";
    scannedCategory.value = "";
    scannedDate.value = null;
  }
}
