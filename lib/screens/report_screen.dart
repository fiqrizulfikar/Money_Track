import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';
import '../controllers/transaction_controller.dart';
import '../utils/constants.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  int _touchedIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final TransactionController _controller = Get.find<TransactionController>();

  // Filter waktu aktif: 'Minggu Ini', 'Bulan Ini', 'Kustom'
  String _activeTimeFilter = 'Bulan Ini';
  DateTimeRange? _customDateRange;

  // Daftar bulan yang bisa dipilih untuk filter 'Bulan Ini'
  late final List<DateTime> _monthOptions;
  late final List<String> _months;

  String get _selectedMonthStr {
    final d = _controller.selectedReportMonth.value;
    const names = [
      'Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember'
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  @override
  void initState() {
    super.initState();
    // Buat daftar 6 bulan terakhir
    final now = DateTime.now();
    _monthOptions = List.generate(6, (i) =>
      DateTime(now.year, now.month - i, 1)
    );
    const names = [
      'Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember'
    ];
    _months = _monthOptions.map((d) => '${names[d.month - 1]} ${d.year}').toList();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Pilih Bulan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...List.generate(_months.length, (i) {
                final month = _months[i];
                final isSelected = month == _selectedMonthStr;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? AppColors.primary : AppColors.textLight,
                  ),
                  title: Text(
                    month,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color:
                          isSelected ? AppColors.primary : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _activeTimeFilter = 'Bulan Ini';
                      _controller.selectedReportMonth.value = _monthOptions[i];
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activeTimeFilter = 'Kustom';
        _customDateRange = picked;
      });
    }
  }

  // --- LOGIKA FILTER TRANSAKSI YANG AKTIF ---
  List<TransactionModel> _getActiveFilteredTransactions(List<TransactionModel> allTransactions) {
    final now = DateTime.now();

    if (_activeTimeFilter == 'Minggu Ini') {
      // 7 hari ke belakang dari hari ini
      final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      return allTransactions.where((t) {
        return t.date.isAfter(sevenDaysAgo) || t.date.isAtSameMomentAs(sevenDaysAgo);
      }).toList();
    } else if (_activeTimeFilter == 'Kustom') {
      if (_customDateRange == null) return [];
      // Saring berdasarkan range yang dipilih (inklusif hari)
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      return allTransactions.where((t) {
        return t.date.isAfter(start) && t.date.isBefore(end);
      }).toList();
    } else {
      // Default: 'Bulan Ini' sesuai dengan controller.selectedReportMonth
      final targetMonth = _controller.selectedReportMonth.value;
      return allTransactions.where((t) {
        return t.date.month == targetMonth.month && t.date.year == targetMonth.year;
      }).toList();
    }
  }

  // --- EKSPOR DATA TRANSAKSI SAAT INI KE CSV ---
  Future<void> _exportActiveReportToCSV(List<TransactionModel> txList) async {
    try {
      if (txList.isEmpty) {
        Get.snackbar(
          'Info',
          'Tidak ada data transaksi pada periode filter aktif untuk diekspor.',
          backgroundColor: Colors.amber.withValues(alpha: 0.9),
          colorText: Colors.black,
        );
        return;
      }

      List<List<dynamic>> rows = [];
      rows.add([
        'ID',
        'Judul',
        'Jumlah',
        'Kategori',
        'Tanggal',
        'Tipe',
        'Catatan'
      ]);

      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      for (var tx in txList) {
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
      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/Laporan_Keuangan_MoneyTrack_${_activeTimeFilter.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      final File file = File(path);
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(path)],
        text: 'Laporan Keuangan MoneyTrack periode $stringFilterRangeText.',
      );
    } catch (e) {
      Get.snackbar('Error', 'Gagal mengekspor laporan: $e');
    }
  }

  String get stringFilterRangeText {
    if (_activeTimeFilter == 'Minggu Ini') {
      return '7 Hari Terakhir';
    } else if (_activeTimeFilter == 'Kustom') {
      if (_customDateRange == null) return 'Kustom';
      final format = DateFormat('dd MMM yyyy', 'id_ID');
      return '${format.format(_customDateRange!.start)} - ${format.format(_customDateRange!.end)}';
    } else {
      return _selectedMonthStr;
    }
  }

  List<_CategoryData> _getCategoryData(List<TransactionModel> expenses) {
    if (expenses.isEmpty) return [];

    Map<String, double> categoryMap = {};
    for (var tx in expenses) {
      categoryMap[tx.category] = (categoryMap[tx.category] ?? 0) + tx.amount;
    }

    List<_CategoryData> data = [];
    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFBE0B),
      const Color(0xFF9D4EDD),
      const Color(0xFFFF9F1C),
    ];

    int colorIndex = 0;
    categoryMap.forEach((name, amount) {
      IconData icon = Icons.receipt;
      switch (name.toLowerCase()) {
        case 'makan & minum':
          icon = Icons.restaurant;
          break;
        case 'transportasi':
          icon = Icons.directions_car;
          break;
        case 'belanja':
          icon = Icons.shopping_bag;
          break;
        case 'hiburan':
          icon = Icons.movie;
          break;
      }

      data.add(_CategoryData(
        name: name,
        amount: amount,
        color: colors[colorIndex % colors.length],
        icon: icon,
      ));
      colorIndex++;
    });

    data.sort((a, b) => b.amount.compareTo(a.amount));
    return data;
  }

  // --- LOGIKA MENGHITUNG CHART TREN 6 BULAN TERAKHIR ---
  List<BarChartGroupData> _buildTrendBarGroups(List<TransactionModel> allTx) {
    final now = DateTime.now();
    List<BarChartGroupData> groups = [];

    // Cari pemasukan dan pengeluaran per bulan untuk 6 bulan terakhir
    for (int i = 5; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      
      final monthlyTx = allTx.where((t) =>
        t.date.month == targetDate.month && t.date.year == targetDate.year
      ).toList();

      final income = monthlyTx.where((t) => !t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
      final expense = monthlyTx.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);

      groups.add(
        BarChartGroupData(
          x: 5 - i,
          barRods: [
            BarChartRodData(
              toY: income,
              color: AppColors.income,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: expense,
              color: AppColors.expense,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    return groups;
  }

  Widget _buildTrendSection(List<TransactionModel> allTx) {
    final now = DateTime.now();
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    
    // Siapkan label bulan di sumbu X
    List<String> labels = [];
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      labels.add(monthNames[d.month - 1]);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tren Keuangan 6 Bulan Terakhir',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildLegendDot(AppColors.income, 'Pemasukan'),
              const SizedBox(width: 16),
              _buildLegendDot(AppColors.expense, 'Pengeluaran'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxYForTrend(allTx),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.grey.shade900.withValues(alpha: 0.9),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String valueText = AppStyles.formatCurrency.format(rod.toY);
                      return BarTooltipItem(
                        valueText,
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              labels[index],
                              style: const TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _buildTrendBarGroups(allTx),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }

  double _getMaxYForTrend(List<TransactionModel> allTx) {
    double maxVal = 1000000; // default minimum max
    final now = DateTime.now();

    for (int i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final monthly = allTx.where((t) => t.date.month == d.month && t.date.year == d.year);
      
      final inc = monthly.where((t) => !t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
      final exp = monthly.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
      
      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }
    return maxVal * 1.15; // Beri margin 15% agar visual tidak mentok atas
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Obx(() {
            final txList = _getActiveFilteredTransactions(_controller.transactions);
            return IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Ekspor CSV Laporan',
              onPressed: () => _exportActiveReportToCSV(txList),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // Ambil semua transaksi
        final allTransactions = _controller.transactions;

        // Terapkan filter waktu aktif
        final txList = _getActiveFilteredTransactions(allTransactions);

        // Hitung total dari daftar yang terfilter
        final totalIncome = txList.where((t) => !t.isExpense).fold(0.0, (sum, t) => sum + t.amount);
        final totalExpense = txList.where((t) => t.isExpense).fold(0.0, (sum, t) => sum + t.amount);

        final expenses = txList.where((t) => t.isExpense).toList();
        final categories = _getCategoryData(expenses);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _buildTimeFilterChips(),
              const SizedBox(height: 16),
              _buildActiveIndicatorCard(),
              const SizedBox(height: 16),
              _buildSummaryRow(totalIncome, totalExpense),
              const SizedBox(height: 24),
              
              // Grafik Tren 6 Bulan
              _buildTrendSection(allTransactions),
              const SizedBox(height: 24),

              // Distribusi Donut
              if (categories.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: const Center(
                    child: Text(
                      'Belum ada data pengeluaran\ndi periode ini',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                )
              else
                _buildPieChartSection(categories, totalExpense),
              
              const SizedBox(height: 24),
              _buildCategoryBreakdown(categories, totalExpense),
              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTimeFilterChips() {
    return Row(
      children: [
        _buildChipButton('Minggu Ini'),
        const SizedBox(width: 8),
        _buildChipButton('Bulan Ini'),
        const SizedBox(width: 8),
        _buildChipButton('Kustom'),
      ],
    );
  }

  Widget _buildChipButton(String text) {
    final isSelected = _activeTimeFilter == text;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (text == 'Bulan Ini') {
            _showMonthPicker();
          } else if (text == 'Kustom') {
            _selectCustomDateRange();
          } else {
            setState(() {
              _activeTimeFilter = text;
            });
          }
        },
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : Theme.of(context).dividerColor,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveIndicatorCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Periode Laporan Aktif',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  stringFilterRangeText,
                  style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_drop_down_circle_rounded, color: AppColors.primary, size: 22),
            onPressed: () {
              if (_activeTimeFilter == 'Bulan Ini') {
                _showMonthPicker();
              } else {
                _selectCustomDateRange();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(double totalIncome, double totalExpense) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniSummaryCard(
            label: 'Total Pemasukan',
            amount: totalIncome,
            color: AppColors.income,
            icon: Icons.arrow_downward_rounded,
            iconBg: AppColors.income.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMiniSummaryCard(
            label: 'Total Pengeluaran',
            amount: totalExpense,
            color: AppColors.expense,
            icon: Icons.arrow_upward_rounded,
            iconBg: AppColors.expense.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniSummaryCard({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppStyles.formatCurrency.format(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartSection(List<_CategoryData> categories, double totalExpense) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribusi Pengeluaran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: ${AppStyles.formatCurrency.format(totalExpense)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 44,
                      sections: _buildPieSections(categories, totalExpense),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categories.map((cat) {
                      final percentage =
                          (cat.amount / totalExpense * 100).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: cat.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$percentage%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cat.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(List<_CategoryData> categories, double totalExpense) {
    return List.generate(categories.length, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 16.0 : 13.0;
      final radius = isTouched ? 56.0 : 48.0;
      final percentage =
          (categories[i].amount / totalExpense * 100).toStringAsFixed(1);

      return PieChartSectionData(
        color: categories[i].color,
        value: categories[i].amount,
        title: '$percentage%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [
            Shadow(
              color: Colors.black26,
              blurRadius: 4,
            ),
          ],
        ),
        titlePositionPercentageOffset: 0.55,
      );
    });
  }

  Widget _buildCategoryBreakdown(List<_CategoryData> categories, double totalExpense) {
    if (categories.isEmpty) return const SizedBox();

    final maxAmount =
        categories.map((c) => c.amount).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail per Kategori',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(categories.length, (index) {
            final cat = categories[index];
            final percentage =
                (cat.amount / totalExpense * 100).toStringAsFixed(1);
            final progressRatio = cat.amount / maxAmount;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index < categories.length - 1 ? 20 : 0,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(cat.icon, color: cat.color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$percentage% dari total',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        AppStyles.formatCurrency.format(cat.amount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: cat.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progressRatio),
                      duration: Duration(milliseconds: 800 + (index * 200)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          minHeight: 8,
                          backgroundColor: cat.color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryData {
  final String name;
  final double amount;
  final Color color;
  final IconData icon;

  const _CategoryData({
    required this.name,
    required this.amount,
    required this.color,
    required this.icon,
  });
}
