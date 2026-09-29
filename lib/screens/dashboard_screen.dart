import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/transaction_controller.dart';
import '../controllers/theme_controller.dart';
import 'history_screen.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_card.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../controllers/scanner_controller.dart';
import '../controllers/user_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScannerController scannerCtrl = Get.put(ScannerController());


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
        title: Obx(() {
          final userController = Get.find<UserController>();
          return Text('Halo, ${userController.name.value} 👋');
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => scannerCtrl.scanReceipt(),
          ),
          Obx(() {
            final themeController = Get.find<ThemeController>();
            return IconButton(
              icon: Icon(
                themeController.isDarkMode.value
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round,
              ),
              onPressed: () => themeController.switchTheme(),
            );
          }),
        ],
      ),
      body: Obx(() {
        final controller = Get.find<TransactionController>();

        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final recentTransactions = controller.transactions.take(4).toList();

        return RefreshIndicator(
          onRefresh: controller.loadTransactions,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              SummaryCard(
                balance: controller.dashboardBalance,
                income: controller.dashboardIncome,
                expense: controller.dashboardExpense,
                isBalanceHidden: controller.isBalanceHidden.value,
                onToggleVisibility: () => controller.toggleBalanceVisibility(),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaksi Terakhir',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Get.to(() => const HistoryScreen());
                    },
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (recentTransactions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Belum ada transaksi.'),
                  ),
                )
              else
                ...recentTransactions.map((tx) {
                  return Slidable(
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
                  );
                }),
            ],
          ),
        );
      }),
    );
  }
}
