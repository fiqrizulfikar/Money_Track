import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/transaction_model.dart';
import 'package:flutter_application_1/main.dart'; // import supabase global variable

class TransactionController extends GetxController {
  // Gunakan .obs agar reaktif
  final RxList<TransactionModel> _transactions = <TransactionModel>[].obs;
  final RxBool _isLoading = false.obs;

  // Bulan yang dipilih di halaman Laporan (default: bulan sekarang)
  var selectedReportMonth = DateTime.now().obs;

  // State untuk sensor saldo (false = terlihat, true = tersembunyi)
  var isBalanceHidden = false.obs;

  void toggleBalanceVisibility() {
    isBalanceHidden.value = !isBalanceHidden.value;
  }

  List<TransactionModel> get transactions => _transactions;
  RxBool get isLoading => _isLoading;

  // --- Getter untuk SEMUA transaksi (global) ---
  double get totalIncome {
    return _transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return _transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get currentBalance => totalIncome - totalExpense;

  // --- Getter untuk DASHBOARD: otomatis bulan berjalan ---
  double get dashboardIncome {
    final now = DateTime.now();
    return _transactions.where((t) =>
      t.date.month == now.month &&
      t.date.year == now.year &&
      !t.isExpense
    ).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get dashboardExpense {
    final now = DateTime.now();
    return _transactions.where((t) =>
      t.date.month == now.month &&
      t.date.year == now.year &&
      t.isExpense
    ).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get dashboardBalance => dashboardIncome - dashboardExpense;

  // --- Getter untuk Laporan: filter berdasarkan bulan yang dipilih ---
  double get totalIncomeByMonth {
    return _transactions.where((t) =>
      t.date.month == selectedReportMonth.value.month &&
      t.date.year == selectedReportMonth.value.year &&
      !t.isExpense
    ).fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpenseByMonth {
    return _transactions.where((t) =>
      t.date.month == selectedReportMonth.value.month &&
      t.date.year == selectedReportMonth.value.year &&
      t.isExpense
    ).fold(0.0, (sum, t) => sum + t.amount);
  }

  // Transaksi yang difilter berdasarkan bulan yang dipilih
  List<TransactionModel> get transactionsByMonth {
    return _transactions.where((t) =>
      t.date.month == selectedReportMonth.value.month &&
      t.date.year == selectedReportMonth.value.year
    ).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _transactions.clear();
      return;
    }

    _isLoading.value = true;
    update();

    try {
      final response = await supabase
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final fetchedTransactions = data
          .map((item) => TransactionModel.fromMap(item as Map<String, dynamic>))
          .toList();

      _transactions.assignAll(fetchedTransactions);
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      Get.snackbar(
        'Gagal Memuat Data',
        'Detail error: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFC62828),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }

    _isLoading.value = false;
    update();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      transaction.userId = user.id;
      final response = await supabase
          .from('transactions')
          .insert(transaction.toMap())
          .select()
          .single();

      final newTransaction = TransactionModel.fromMap(response);
      _transactions.insert(0, newTransaction);
      update();
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      Get.snackbar(
        'Error',
        'Gagal menyimpan transaksi ke server: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await supabase.from('transactions').delete().eq('id', id);
      _transactions.removeWhere((t) => t.id == id);
      update();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
    }
  }

  Future<void> deleteTransactionLocal(int id, int index) async {
    try {
      await supabase.from('transactions').delete().eq('id', id);
      _transactions.removeAt(index);
      update();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
    }
  }

  Future<void> updateTransactionLocal(TransactionModel updatedData, int index) async {
    if (updatedData.id == null) return;
    
    try {
      final response = await supabase
          .from('transactions')
          .update(updatedData.toMap())
          .eq('id', updatedData.id!)
          .select()
          .single();

      final newUpdated = TransactionModel.fromMap(response);
      _transactions[index] = newUpdated;
      update();
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui transaksi di server: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
