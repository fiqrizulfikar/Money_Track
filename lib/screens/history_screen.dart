import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/transaction_controller.dart';
import '../utils/constants.dart';
import '../widgets/transaction_card.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'Semua'; // 'Semua', 'Pemasukan', 'Pengeluaran'

  void _showEditForm(BuildContext context, dynamic tx, int originalIndex, TransactionController controller) {
    final titleController = TextEditingController(text: tx.title);
    final amountController = TextEditingController(text: tx.amount.toString());

    Get.bottomSheet(
      Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Transaksi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Keterangan'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Nominal'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final newAmount = double.tryParse(amountController.text);
                  if (newAmount != null && titleController.text.isNotEmpty) {
                    tx.title = titleController.text;
                    tx.amount = newAmount;
                    controller.updateTransactionLocal(tx, originalIndex);
                    Get.back();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaksi diperbarui')),
                    );
                  }
                },
                child: const Text('Simpan Perubahan'),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Obx(() {
        final controller = Get.find<TransactionController>();
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        var transactions = controller.transactions;
        if (_filter == 'Pemasukan') {
          transactions = transactions.where((t) => !t.isExpense).toList();
        } else if (_filter == 'Pengeluaran') {
          transactions = transactions.where((t) => t.isExpense).toList();
        }

        return Column(
          children: [
            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _buildFilterChip('Semua'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pemasukan'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pengeluaran'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: transactions.isEmpty
                  ? const Center(child: Text('Tidak ada riwayat transaksi.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        
                        // --- LOGIKA PEMBATAS BULAN ---
                        bool showMonthHeader = false;

                        if (index == 0) {
                          showMonthHeader = true; // Item pertama selalu memunculkan bulan
                        } else {
                          final previousTransaction = transactions[index - 1];
                          // Jika bulan atau tahunnya berbeda dengan transaksi sebelumnya, nyalakan pembatas
                          if (tx.date.month != previousTransaction.date.month ||
                              tx.date.year != previousTransaction.date.year) {
                            showMonthHeader = true;
                          }
                        }

                        // Format tanggal untuk nama pembatas (Contoh: "Mei 2026")
                        String monthTitle = DateFormat('MMMM yyyy', 'id_ID').format(tx.date);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showMonthHeader) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
                                child: Text(
                                  monthTitle,
                                  style: TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold, 
                                    color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7) ?? Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                            Slidable(
                              key: Key(tx.id.toString()),
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (context) {
                                      final originalIndex = controller.transactions.indexOf(tx);
                                      if (originalIndex != -1) {
                                        _showEditForm(context, tx, originalIndex, controller);
                                      }
                                    },
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit,
                                    label: 'Edit',
                                  ),
                                  SlidableAction(
                                    onPressed: (context) {
                                      final originalIndex = controller.transactions.indexOf(tx);
                                      if (originalIndex != -1) {
                                        controller.deleteTransactionLocal(tx.id!, originalIndex);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Transaksi dihapus')),
                                        );
                                      }
                                    },
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: 'Hapus',
                                  ),
                                ],
                              ),
                              child: TransactionCard(transaction: tx),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filter = label;
          });
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Theme.of(context).dividerColor,
        ),
      ),
    );
  }
}
