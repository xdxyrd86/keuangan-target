import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const KeuanganTargetApp());
}

String formatRupiah(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

double parseNominal(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
  return double.tryParse(cleaned) ?? 0;
}

class KeuanganTargetApp extends StatelessWidget {
  const KeuanganTargetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Keuangan & Target',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const MainHomePage(),
    );
  }
}

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final bool isIncome;
  final String category;
  final String wallet;
  final DateTime date;
  final String note;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.wallet,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'isIncome': isIncome,
        'category': category,
        'wallet': wallet,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        isIncome: json['isIncome'] as bool,
        category: json['category'] as String,
        wallet: json['wallet'] as String? ?? 'Tunai',
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String? ?? '',
      );
}

class FinancialGoal {
  final String id;
  final String name;
  final double targetAmount;
  double currentAmount;
  final DateTime deadline;
  final String note;

  FinancialGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'deadline': deadline.toIso8601String(),
        'note': note,
      };

  factory FinancialGoal.fromJson(Map<String, dynamic> json) => FinancialGoal(
        id: json['id'] as String,
        name: json['name'] as String,
        targetAmount: (json['targetAmount'] as num).toDouble(),
        currentAmount: (json['currentAmount'] as num).toDouble(),
        deadline: DateTime.parse(json['deadline'] as String),
        note: json['note'] as String? ?? '',
      );
}

class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});

  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  static const String _txStorageKey = 'transactions_v1';
  static const String _goalStorageKey = 'goals_v1';

  final List<String> _wallets = ['Tunai', 'Rekening Bank', 'E-Wallet'];
  final List<String> _expenseCategories = [
    'Makan & Minum',
    'Transportasi & BBM',
    'Tagihan & Rutin',
    'Belanja Kebutuhan',
    'Alokasi Target',
    'Lainnya',
  ];
  final List<String> _incomeCategories = [
    'Gaji / Upah',
    'Bonus / Lembur',
    'Usaha / Sampingan',
    'Lainnya',
  ];

  List<TransactionItem> _transactions = [];
  List<FinancialGoal> _goals = [];
  int _selectedIndex = 0;
  String _txFilter = 'Semua';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final txRaw = prefs.getString(_txStorageKey);
    final goalRaw = prefs.getString(_goalStorageKey);

    setState(() {
      if (txRaw != null) {
        final List decodedTx = jsonDecode(txRaw) as List;
        _transactions = decodedTx
            .map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      }
      if (goalRaw != null) {
        final List decodedGoals = jsonDecode(goalRaw) as List;
        _goals = decodedGoals
            .map((e) => FinancialGoal.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      _isLoading = false;
    });
  }

  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _txStorageKey,
      jsonEncode(_transactions.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _goalStorageKey,
      jsonEncode(_goals.map((e) => e.toJson()).toList()),
    );
  }

  double get _totalIncome => _transactions
      .where((t) => t.isIncome)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get _totalExpense => _transactions
      .where((t) => !t.isIncome)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get _totalBalance => _totalIncome - _totalExpense;

  double _getWalletBalance(String walletName) {
    return _transactions.where((t) => t.wallet == walletName).fold(
          0.0,
          (sum, item) => sum + (item.isIncome ? item.amount : -item.amount),
        );
  }

  void _addTransaction(TransactionItem item) {
    setState(() {
      _transactions.insert(0, item);
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    });
    _saveLocalData();
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((t) => t.id == id);
    });
    _saveLocalData();
  }

  void _addGoal(FinancialGoal goal) {
    setState(() {
      _goals.add(goal);
    });
    _saveLocalData();
  }

  void _deleteGoal(String id) {
    setState(() {
      _goals.removeWhere((g) => g.id == id);
    });
    _saveLocalData();
  }

  void _depositToGoal(
    FinancialGoal goal,
    double amount,
    bool deductFromWallet,
    String wallet,
  ) {
    setState(() {
      goal.currentAmount += amount;
      if (deductFromWallet) {
        _transactions.insert(
          0,
          TransactionItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'Setor Target: ${goal.name}',
            amount: amount,
            isIncome: false,
            category: 'Alokasi Target',
            wallet: wallet,
            date: DateTime.now(),
            note: 'Tabungan otomatis ke target ${goal.name}',
          ),
        );
      }
    });
    _saveLocalData();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboardTab(),
      _buildTransactionsTab(),
      _buildGoalsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Keuangan & Target',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pages[_selectedIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_selectedIndex == 2) {
            _showAddGoalModal();
          } else {
            _showAddTransactionModal();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_selectedIndex == 2 ? 'Target Baru' : 'Catat Transaksi'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Ringkasan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Target',
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: DASHBOARD ====================
  Widget _buildDashboardTab() {
    final recentTx = _transactions.take(5).toList();
    final activeGoals = _goals.take(2).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        // Kartu Total Saldo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.teal.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Saldo Tersedia',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                formatRupiah(_totalBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryBadge(
                      icon: Icons.arrow_downward,
                      label: 'Pemasukan',
                      amount: formatRupiah(_totalIncome),
                      iconColor: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryBadge(
                      icon: Icons.arrow_upward,
                      label: 'Pengeluaran',
                      amount: formatRupiah(_totalExpense),
                      iconColor: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Rincian Per Sumber Dana
        const Text(
          'Saldo per Sumber Dana',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: _wallets.map((wallet) {
            return Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatRupiah(_getWalletBalance(wallet)),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Preview Target Prioritas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Progres Target',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 2),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        if (activeGoals.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada catatan target. Buka tab Target untuk menambah rencana tabungan.',
              ),
            ),
          )
        else
          ...activeGoals.map((g) => _buildGoalCard(g, compact: true)),

        const SizedBox(height: 16),

        // Transaksi Terbaru
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transaksi Terbaru',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedIndex = 1),
              child: const Text('Semua Riwayat'),
            ),
          ],
        ),
        if (recentTx.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada transaksi tercatat.'),
            ),
          )
        else
          ...recentTx.map((t) => _buildTransactionTile(t, allowDelete: false)),
      ],
    );
  }

  Widget _buildSummaryBadge({
    required IconData icon,
    required String label,
    required String amount,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    amount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 2: TRANSAKSI ====================
  Widget _buildTransactionsTab() {
    final filtered = _transactions.where((t) {
      if (_txFilter == 'Pemasukan') return t.isIncome;
      if (_txFilter == 'Pengeluaran') return !t.isIncome;
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: ['Semua', 'Pemasukan', 'Pengeluaran'].map((filter) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: _txFilter == filter,
                  onSelected: (_) => setState(() => _txFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Tidak ada data transaksi.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildTransactionTile(
                      filtered[index],
                      allowDelete: true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionTile(
    TransactionItem tx, {
    required bool allowDelete,
  }) {
    final dateText = DateFormat('dd MMM yyyy', 'id_ID').format(tx.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              tx.isIncome ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            tx.isIncome ? Icons.south_west : Icons.north_east,
            color: tx.isIncome ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        title: Text(
          tx.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${tx.category} • ${tx.wallet} • $dateText${tx.note.isNotEmpty ? '\nCatatan: ${tx.note}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${tx.isIncome ? '+' : '-'} ${formatRupiah(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: tx.isIncome ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            if (allowDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _deleteTransaction(tx.id),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 3: TARGET & CATATAN ====================
  Widget _buildGoalsTab() {
    if (_goals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada target tercatat.\nTekan tombol "+ Target Baru" di bawah untuk mulai mencatat target tabungan.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _goals.length,
      itemBuilder: (context, index) => _buildGoalCard(_goals[index]),
    );
  }

  Widget _buildGoalCard(FinancialGoal goal, {bool compact = false}) {
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (progress * 100).toStringAsFixed(1);
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(
      0.0,
      double.infinity,
    );
    final isCompleted = goal.currentAmount >= goal.targetAmount;

    final daysLeft = goal.deadline.difference(DateTime.now()).inDays;
    final monthsLeft = (daysLeft / 30).ceil().clamp(1, 999);
    final monthlyNeeded = remaining > 0 ? remaining / monthsLeft : 0.0;
    final deadlineStr = DateFormat('dd MMM yyyy', 'id_ID').format(goal.deadline);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    isCompleted
                        ? 'Tercapai'
                        : (daysLeft >= 0 ? '$daysLeft hari lagi' : 'Lewat tenggat'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: isCompleted
                      ? Colors.green.shade100
                      : Colors.teal.shade50,
                ),
                if (!compact)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    onPressed: () => _deleteGoal(goal.id),
                  ),
              ],
            ),
            if (goal.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                goal.note,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatRupiah(goal.currentAmount)} / ${formatRupiah(goal.targetAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const Divider(height: 20),
              Text(
                'Tenggat: $deadlineStr • Kekurangan: ${formatRupiah(remaining)}',
                style: const TextStyle(fontSize: 13),
              ),
              if (!isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Estimasi sisihkan: ${formatRupiah(monthlyNeeded)} / bulan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _showDepositDialog(goal),
                  icon: const Icon(Icons.savings_outlined),
                  label: const Text('Tambah Setoran Target'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== MODAL INPUT TRANSAKSI ====================
  void _showAddTransactionModal() {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    bool isIncome = false;
    String selectedCategory = _expenseCategories.first;
    String selectedWallet = _wallets.first;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categories =
                isIncome ? _incomeCategories : _expenseCategories;
            if (!categories.contains(selectedCategory)) {
              selectedCategory = categories.first;
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Catat Transaksi Baru',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Pengeluaran'),
                            icon: Icon(Icons.north_east),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Pemasukan'),
                            icon: Icon(Icons.south_west),
                          ),
                        ],
                        selected: {isIncome},
                        onSelectionChanged: (val) {
                          setModalState(() {
                            isIncome = val.first;
                            selectedCategory = isIncome
                                ? _incomeCategories.first
                                : _expenseCategories.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Judul Transaksi (misal: Makan Siang)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nominal (Rp)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => parseNominal(v ?? '') <= 0
                            ? 'Masukkan nominal valid'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Kategori',
                                border: OutlineInputBorder(),
                              ),
                              items: categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedCategory = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedWallet,
                              decoration: const InputDecoration(
                                labelText: 'Sumber Dana',
                                border: OutlineInputBorder(),
                              ),
                              items: _wallets
                                  .map(
                                    (w) => DropdownMenuItem(
                                      value: w,
                                      child: Text(w),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedWallet = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          'Tanggal: ${DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Catatan Tambahan (Opsional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            _addTransaction(
                              TransactionItem(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                title: titleCtrl.text.trim(),
                                amount: parseNominal(amountCtrl.text),
                                isIncome: isIncome,
                                category: selectedCategory,
                                wallet: selectedWallet,
                                date: selectedDate,
                                note: noteCtrl.text.trim(),
                              ),
                            );
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Simpan Transaksi'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== MODAL INPUT TARGET BARU ====================
  void _showAddGoalModal() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final initialCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController();
    DateTime deadline = DateTime.now().add(const Duration(days: 180));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Buat Catatan Target Baru',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nama Target (misal: Dana Darurat)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: targetCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nominal Target (Rp)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => parseNominal(v ?? '') <= 0
                            ? 'Masukkan nominal target valid'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: initialCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Saldo Awal Terkumpul (Rp)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: deadline,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setModalState(() => deadline = picked);
                          }
                        },
                        icon: const Icon(Icons.event),
                        label: Text(
                          'Tenggat Target: ${DateFormat('dd MMM yyyy', 'id_ID').format(deadline)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Catatan Rencana / Detail Target',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            _addGoal(
                              FinancialGoal(
                                id: DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                                name: nameCtrl.text.trim(),
                                targetAmount: parseNominal(targetCtrl.text),
                                currentAmount: parseNominal(initialCtrl.text),
                                deadline: deadline,
                                note: noteCtrl.text.trim(),
                              ),
                            );
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Simpan Target'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== DIALOG SETOR DANA TARGET ====================
  void _showDepositDialog(FinancialGoal goal) {
    final amountCtrl = TextEditingController();
    bool deductFromWallet = true;
    String selectedWallet = _wallets.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Setor ke ${goal.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Setoran (Rp)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: deductFromWallet,
                    title: const Text(
                      'Potong dari saldo utama',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Otomatis catat sebagai transaksi alokasi',
                      style: TextStyle(fontSize: 12),
                    ),
                    onChanged: (val) {
                      setDialogState(() => deductFromWallet = val ?? true);
                    },
                  ),
                  if (deductFromWallet)
                    DropdownButtonFormField<String>(
                      value: selectedWallet,
                      decoration: const InputDecoration(
                        labelText: 'Ambil dari Sumber Dana',
                        border: OutlineInputBorder(),
                      ),
                      items: _wallets
                          .map(
                            (w) => DropdownMenuItem(value: w, child: Text(w)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedWallet = val);
                        }
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = parseNominal(amountCtrl.text);
                    if (amount > 0) {
                      _depositToGoal(
                        goal,
                        amount,
                        deductFromWallet,
                        selectedWallet,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Simpan Setoran'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
