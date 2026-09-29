import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../controllers/transaction_controller.dart';

class ExportService {
  static Future<void> exportTransactionsToCSV() async {
    try {
      if (kIsWeb) {
        // Share_plus might have limited support on Web, or we can use standard web download.
        // For simplicity, we just print or show an alert, but let's try to export if supported.
        debugPrint('Ekspor data via Web membutuhkan implementasi khusus.');
        return;
      }

      final transactions = Get.find<TransactionController>().transactions;

      if (transactions.isEmpty) {
        throw Exception('Tidak ada data transaksi untuk diekspor.');
      }

      // Prepare CSV data
      List<List<dynamic>> rows = [];
      // Headers
      rows.add([
        'ID',
        'Judul',
        'Jumlah',
        'Kategori',
        'Tanggal',
        'Tipe',
        'Catatan'
      ]);

      // Data Rows
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      for (var tx in transactions) {
        rows.add([
          tx.id ?? '',
          tx.title,
          tx.amount,
          tx.category,
          dateFormat.format(tx.date),
          tx.isExpense ? 'Pengeluaran' : 'Pemasukan',
          tx.note,
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/moneytrack_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      final File file = File(path);
      await file.writeAsString(csv);

      // Share the file
      await Share.shareXFiles([XFile(path)], text: 'Berikut adalah data ekspor transaksi dari aplikasi MoneyTrack.');

    } catch (e) {
      debugPrint('Error during export: $e');
      rethrow;
    }
  }
}
