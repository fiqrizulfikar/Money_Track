import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/transaction_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inisialisasi controller agar UI bisa memantau data secara reaktif
    final TransactionController controller = Get.find<TransactionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyTrack Dashboard'),
        backgroundColor: const Color(0xFF0B7A42),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                controller.loadTransactions(), // Refresh data dari cloud
          ),
        ],
      ),
      body: Obx(() {
        // Tampilan loading jika data sedang ditarik dari Supabase
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // ─── CARD RINGKASAN SALDO ───
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF064D2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Saldo',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Obx(
                    () => Text(
                      'Rp ${controller.currentBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        'Pemasukan',
                        controller.dashboardIncome,
                        Colors.greenAccent,
                      ),
                      _buildSummaryItem(
                        'Pengeluaran',
                        controller.dashboardExpense,
                        Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Riwayat Transaksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // ─── LIST DAFTAR TRANSAKSI DARI CLOUD ───
            Expanded(
              child: controller.transactions.isEmpty
                  ? const Center(child: Text('Belum ada transaksi di cloud.'))
                  : ListView.builder(
                      itemCount: controller.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = controller.transactions[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tx.isExpense
                                ? Colors.red[100]
                                : Colors.green[100],
                            child: Icon(
                              tx.isExpense
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: tx.isExpense ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(tx.title),
                          subtitle: Text(tx.category),
                          trailing: Text(
                            '${tx.isExpense ? "-" : "+"} Rp ${tx.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tx.isExpense ? Colors.red : Colors.green,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Rp ${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
