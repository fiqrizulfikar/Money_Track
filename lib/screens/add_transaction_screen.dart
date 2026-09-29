import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction_model.dart';
import '../controllers/transaction_controller.dart';
import '../controllers/scanner_controller.dart';
import '../utils/constants.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  final ScannerController _scannerController = Get.put(ScannerController());
  
  late Worker _totalWorker;
  late Worker _merchantWorker;
  late Worker _categoryWorker;
  late Worker _dateWorker;

  bool _isExpense = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Makan & Minum';

  final List<String> _expenseCategories = [
    'Makan & Minum',
    'Transportasi',
    'Belanja',
    'Lainnya',
  ];

  final List<String> _incomeCategories = [
    'Gaji Bulanan',
    'Freelance',
    'Pemberian',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();

    // Auto-fill nominal dan set ke Pengeluaran otomatis
    _totalWorker = ever(_scannerController.scannedTotal, (String value) {
      if (value.isNotEmpty && mounted) {
        setState(() {
          _amountController.text = value;
          _isExpense = true; // Struk selalu pengeluaran
        });
      }
    });

    // Auto-fill catatan dengan nama merchant
    _merchantWorker = ever(_scannerController.scannedMerchant, (String value) {
      if (value.isNotEmpty && mounted) {
        _noteController.text = value;
      }
    });

    // Auto-fill kategori
    _categoryWorker = ever(_scannerController.scannedCategory, (String value) {
      if (value.isNotEmpty && mounted) {
        final categories = _isExpense ? _expenseCategories : _incomeCategories;
        if (categories.contains(value)) {
          setState(() {
            _selectedCategory = value;
          });
        }
      }
    });

    // Auto-fill tanggal
    _dateWorker = ever(_scannerController.scannedDate, (DateTime? value) {
      if (value != null && mounted) {
        setState(() {
          _selectedDate = value;
        });
      }
    });
  }

  @override
  void dispose() {
    _totalWorker.dispose();
    _merchantWorker.dispose();
    _categoryWorker.dispose();
    _dateWorker.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showScanOptions() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan Struk',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () {
                Get.back();
                _scannerController.pickAndProcessImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Get.back();
                _scannerController.pickAndProcessImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveTransaction() {
    if (_formKey.currentState!.validate()) {
      final String note = _noteController.text.isEmpty ? _selectedCategory : _noteController.text;
      
      final newTx = TransactionModel(
        title: note, // Using note as title for simplicity, or we could add a title field
        amount: double.parse(_amountController.text),
        category: _selectedCategory,
        date: _selectedDate,
        isExpense: _isExpense,
        note: _noteController.text,
      );

      Get.find<TransactionController>().addTransaction(newTx);

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil disimpan!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _isExpense ? _expenseCategories : _incomeCategories;
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = categories.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toggle Pemasukan / Pengeluaran
              Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      title: 'Pemasukan',
                      isSelected: !_isExpense,
                      color: AppColors.primary,
                      onTap: () => setState(() => _isExpense = false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildToggleButton(
                      title: 'Pengeluaran',
                      isSelected: _isExpense,
                      color: AppColors.expense,
                      onTap: () => setState(() => _isExpense = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Nominal Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nominal', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: _showScanOptions,
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Scan Struk'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Obx(() => Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Masukkan nominal';
                          if (double.tryParse(val) == null) return 'Nominal tidak valid';
                          return null;
                        },
                      ),
                      if (_scannerController.isLoading.value)
                        const Padding(
                          padding: EdgeInsets.only(right: 12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  )),
              const SizedBox(height: 16),

              // Kategori Dropdown
              const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Tanggal Picker
              const Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                      const Icon(Icons.calendar_today, color: AppColors.textLight),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Catatan Input
              const Text('Catatan (Opsional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'Misal: Makan siang',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
              ),
              const SizedBox(height: 32),

              // Simpan Button
              ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'SIMPAN',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
