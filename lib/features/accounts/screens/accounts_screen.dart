import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../../shared/widgets/custom_date_range_dialog.dart';
import '../../authentication/providers/auth_provider.dart';
import '../widgets/day_end_close_dialog.dart';
import '../widgets/daily_summaries_sheet.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedDateFilter = 'ALL'; // ALL, TODAY, YESTERDAY, THIS_MONTH, PREVIOUS_MONTH, CUSTOM
  DateTimeRange? _customDateRange;
  String _selectedTypeFilter = 'ALL'; // ALL, SALE, EXPENSE, TRANSFER, DISCREPANCY
  String _selectedChannelFilter = 'ALL'; // ALL, CASH, ONLINE

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDateFilter = 'ALL';
      _customDateRange = null;
      _selectedTypeFilter = 'ALL';
      _selectedChannelFilter = 'ALL';
      _searchCtrl.clear();
    });
  }

  String _getDateFilterLabel() {
    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case 'TODAY':
        return 'Today (${DateFormatter.formatDate(now)})';
      case 'YESTERDAY':
        final yest = now.subtract(const Duration(days: 1));
        return 'Yesterday (${DateFormatter.formatDate(yest)})';
      case 'THIS_MONTH':
        return 'This Month (${DateFormatter.formatMonth(now)})';
      case 'PREVIOUS_MONTH':
        final prev = DateTime(now.year, now.month - 1, 1);
        return 'Previous Month (${DateFormatter.formatMonth(prev)})';
      case 'CUSTOM':
        if (_customDateRange != null) {
          return 'Custom (${DateFormatter.formatDate(_customDateRange!.start)} - ${DateFormatter.formatDate(_customDateRange!.end)})';
        }
        return 'Custom Date Range';
      default:
        return 'All Records';
    }
  }

  void _showAddExpenseDialog(BuildContext context, double availableCash) {
    final reasonCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final voucherCtrl = TextEditingController();
    String category = 'Rent';
    String paymentMethod = AppConstants.paymentCash;
    final user = ref.read(authProvider).currentUser?.displayName ?? 'Admin';

    final categories = [
      'Rent',
      'Electricity',
      'Salary',
      'Transportation',
      'Packaging',
      'Maintenance',
      'Marketing',
      'Tea & Refreshment',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final amt = double.tryParse(amountCtrl.text) ?? 0.0;
            final isInsufficientCash = paymentMethod == AppConstants.paymentCash && amt > availableCash && availableCash > 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.rubyLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.ruby, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Record Shop Operating Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Expense Category'),
                        items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reason / Description *',
                          hintText: 'e.g. Electricity bill payment for shop',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: voucherCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Voucher / Bill No. (Optional)',
                          hintText: 'e.g. VCH-0042 or Bill ref',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Expense Amount (₹) *',
                          prefixText: '₹ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: paymentMethod,
                        decoration: const InputDecoration(labelText: 'Paid From Account Channel'),
                        items: const [
                          DropdownMenuItem(value: AppConstants.paymentCash, child: Text('Cash in Hand (Physical Till)')),
                          DropdownMenuItem(value: AppConstants.paymentOnline, child: Text('Bank / UPI Account')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => paymentMethod = val);
                        },
                      ),
                      if (isInsufficientCash) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: Expense exceeds recorded physical cash till (${CurrencyFormatter.format(availableCash)}).',
                          style: const TextStyle(color: AppColors.ruby, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.ruby, foregroundColor: Colors.white),
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (amount <= 0 || reasonCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount and description.')),
                      );
                      return;
                    }

                    final isCash = paymentMethod == AppConstants.paymentCash;
                    final expense = ExpenseModel(
                      expenseId: '',
                      date: DateTime.now().toIso8601String().substring(0, 10),
                      reason: reasonCtrl.text.trim(),
                      category: category,
                      totalAmount: amount,
                      paymentMethod: paymentMethod,
                      cashAmount: isCash ? amount : 0.0,
                      onlineAmount: isCash ? 0.0 : amount,
                      description: voucherCtrl.text.trim().isNotEmpty
                          ? '${reasonCtrl.text.trim()} (Voucher: ${voucherCtrl.text.trim()})'
                          : reasonCtrl.text.trim(),
                      createdBy: user,
                      createdAt: DateTime.now(),
                    );

                    await ref.read(shopRepositoryProvider).addExpense(expense);
                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Post Expense Debit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCashTransferDialog(BuildContext context, double currentCash) {
    final amountCtrl = TextEditingController();
    final slipCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: 'Routine cash deposit into bank account');
    final user = ref.read(authProvider).currentUser?.displayName ?? 'Admin';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final amt = double.tryParse(amountCtrl.text) ?? 0.0;
            final isExceeding = amt > currentCash && currentCash > 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Cash-to-Bank Deposit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deposits physical cash from the shop drawer into the bank account. Available Cash in Till: ${CurrencyFormatter.format(currentCash)}.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Deposit Amount (₹) *',
                        prefixText: '₹ ',
                        suffixIcon: IconButton(
                          tooltip: 'Transfer all cash',
                          icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                          onPressed: () {
                            amountCtrl.text = currentCash.clamp(0.0, double.infinity).toStringAsFixed(0);
                            setModalState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: slipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bank Deposit Slip / Challan No. (Optional)',
                        hintText: 'e.g. SLIP-9902 or UPI ref',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Transfer Purpose / Notes'),
                    ),
                    if (isExceeding) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Note: Amount exceeds recorded cash balance (${CurrencyFormatter.format(currentCash)}).',
                        style: const TextStyle(color: AppColors.ruby, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount greater than 0.')),
                      );
                      return;
                    }

                    final noteText = slipCtrl.text.trim().isNotEmpty
                        ? '${notesCtrl.text.trim()} (Challan: ${slipCtrl.text.trim()})'
                        : notesCtrl.text.trim();

                    await ref.read(shopRepositoryProvider).transferCashToBank(
                          amount: amount,
                          notes: noteText,
                          user: user,
                        );
                    if (mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Confirm Deposit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(accountEntriesStreamProvider);
    final todaySummaryAsync = ref.watch(todaySummaryStreamProvider);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final yest = now.subtract(const Duration(days: 1));
    final yesterdayStart = DateTime(yest.year, yest.month, yest.day, 0, 0, 0);
    final yesterdayEnd = DateTime(yest.year, yest.month, yest.day, 23, 59, 59, 999);

    final thisMonthStart = DateTime(now.year, now.month, 1, 0, 0, 0);
    final thisMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final prevMonthStart = DateTime(now.year, now.month - 1, 1, 0, 0, 0);
    final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59, 999);

    final todayStr = now.toIso8601String().substring(0, 10);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
        error: (err, _) => Center(child: Text('Error loading accounts: $err')),
        data: (entries) {
          // Authoritative cumulative ledger balances for cash drawer and bank account
          final currentCashBalance = entries.fold(0.0, (sum, e) => sum + e.cashAmount);
          final currentOnlineBalance = entries.fold(0.0, (sum, e) => sum + e.onlineAmount);
          final grandClosingBalance = currentCashBalance + currentOnlineBalance;

          // Filter entries based on user selection
          final search = _searchCtrl.text.trim().toLowerCase();
          final filteredEntries = entries.where((entry) {
            final matchesSearch = search.isEmpty ||
                entry.description.toLowerCase().contains(search) ||
                entry.transactionType.toLowerCase().contains(search) ||
                entry.referenceId.toLowerCase().contains(search) ||
                entry.createdBy.toLowerCase().contains(search);

            // Date filtering with exact day boundaries
            bool matchesDate = true;
            if (_selectedDateFilter == 'TODAY') {
              matchesDate = !entry.createdAt.isBefore(todayStart) && !entry.createdAt.isAfter(todayEnd);
            } else if (_selectedDateFilter == 'YESTERDAY') {
              matchesDate = !entry.createdAt.isBefore(yesterdayStart) && !entry.createdAt.isAfter(yesterdayEnd);
            } else if (_selectedDateFilter == 'THIS_MONTH') {
              matchesDate = !entry.createdAt.isBefore(thisMonthStart) && !entry.createdAt.isAfter(thisMonthEnd);
            } else if (_selectedDateFilter == 'PREVIOUS_MONTH') {
              matchesDate = !entry.createdAt.isBefore(prevMonthStart) && !entry.createdAt.isAfter(prevMonthEnd);
            } else if (_selectedDateFilter == 'CUSTOM' && _customDateRange != null) {
              final cStart = DateTime(
                _customDateRange!.start.year,
                _customDateRange!.start.month,
                _customDateRange!.start.day,
                0, 0, 0,
              );
              final cEnd = DateTime(
                _customDateRange!.end.year,
                _customDateRange!.end.month,
                _customDateRange!.end.day,
                23, 59, 59, 999,
              );
              matchesDate = !entry.createdAt.isBefore(cStart) && !entry.createdAt.isAfter(cEnd);
            }

            final matchesType = _selectedTypeFilter == 'ALL' ||
                (_selectedTypeFilter == 'SALE' && entry.transactionType == AppConstants.accountSaleIncome) ||
                (_selectedTypeFilter == 'EXPENSE' && entry.transactionType == AppConstants.accountExpense) ||
                (_selectedTypeFilter == 'TRANSFER' && entry.transactionType == AppConstants.accountTransfer) ||
                (_selectedTypeFilter == 'DISCREPANCY' && (entry.transactionType.contains('SHORTAGE') || entry.transactionType.contains('SURPLUS')));

            final matchesChannel = _selectedChannelFilter == 'ALL' ||
                (_selectedChannelFilter == 'CASH' && entry.cashAmount != 0) ||
                (_selectedChannelFilter == 'ONLINE' && entry.onlineAmount != 0);

            return matchesSearch && matchesDate && matchesType && matchesChannel;
          }).toList();

          // Summary values calculated STRICTLY based on filtered transaction records
          final filteredIncome = filteredEntries.where((e) {
            return e.transactionType == AppConstants.accountSaleIncome ||
                (e.cashAmount > 0 && e.transactionType != AppConstants.accountTransfer) ||
                (e.onlineAmount > 0 && e.transactionType != AppConstants.accountTransfer && e.transactionType != AppConstants.accountSaleIncome);
          }).fold(0.0, (sum, e) => sum + (e.cashAmount > 0 ? e.cashAmount : 0.0) + (e.onlineAmount > 0 ? e.onlineAmount : 0.0));

          final filteredExpenses = filteredEntries
              .where((e) => e.transactionType == AppConstants.accountExpense)
              .fold(0.0, (sum, e) => sum + (e.cashAmount.abs() + e.onlineAmount.abs()));

          final filteredNetBalance = filteredIncome - filteredExpenses;
          final filteredTransactionsCount = filteredEntries.length;

          final isFilterActive = _selectedDateFilter != 'ALL' ||
              _selectedTypeFilter != 'ALL' ||
              _selectedChannelFilter != 'ALL' ||
              _searchCtrl.text.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Action Bar
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Financial Accounts & Dual-Channel Ledger', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('Cash in Till, Bank balance reconciliation and automated POS ledger posting', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.history_edu_rounded, size: 18),
                          label: const Text('Daily Summaries'),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (_) => const DailySummariesSheet(),
                            );
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Cash to Bank'),
                          onPressed: () => _showCashTransferDialog(context, currentCashBalance),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_card_rounded, size: 18),
                          label: const Text('Record Expense'),
                          onPressed: () => _showAddExpenseDialog(context, currentCashBalance),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.lock_clock_rounded, size: 18),
                          label: const Text('Close Day Audit'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldDark, foregroundColor: Colors.white),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => DayEndCloseDialog(
                                date: todayStr,
                                expectedCash: currentCashBalance,
                                currentBankBalance: currentOnlineBalance,
                                todaySummary: todaySummaryAsync.valueOrNull,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Accounts & Ledger Summary Cards (strictly reflects filtered records)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double cardWidth;
                    if (constraints.maxWidth < 460) {
                      cardWidth = constraints.maxWidth < 320 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
                    } else if (constraints.maxWidth < 800) {
                      cardWidth = (constraints.maxWidth - 24) / 3;
                    } else {
                      cardWidth = (constraints.maxWidth - 36) / 4;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildBalanceCard(
                              'Total Income',
                              CurrencyFormatter.format(filteredIncome),
                              Icons.trending_up_rounded,
                              AppColors.goldDark,
                              width: cardWidth,
                            ),
                            _buildBalanceCard(
                              'Total Expenses',
                              CurrencyFormatter.format(filteredExpenses),
                              Icons.receipt_long_outlined,
                              AppColors.ruby,
                              width: cardWidth,
                            ),
                            _buildBalanceCard(
                              'Net Balance',
                              CurrencyFormatter.format(filteredNetBalance),
                              Icons.account_balance_wallet_outlined,
                              filteredNetBalance >= 0 ? AppColors.emerald : AppColors.ruby,
                              width: cardWidth,
                            ),
                            _buildBalanceCard(
                              'Total Transactions',
                              '$filteredTransactionsCount Entries',
                              Icons.format_list_bulleted_rounded,
                              AppColors.primaryGold,
                              width: cardWidth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Authoritative Liquid Status Strip
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Wrap(
                            spacing: 20,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.payments_outlined, size: 16, color: AppColors.cashColor),
                                  const SizedBox(width: 6),
                                  Text('Physical Cash in Drawer: ${CurrencyFormatter.format(currentCashBalance)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_outlined, size: 16, color: AppColors.onlineColor),
                                  const SizedBox(width: 6),
                                  Text('Bank/UPI Account: ${CurrencyFormatter.format(currentOnlineBalance)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.savings_outlined, size: 16, color: AppColors.emerald),
                                  const SizedBox(width: 6),
                                  Text('Total Liquid Capital: ${CurrencyFormatter.format(grandClosingBalance)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emerald)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Ledger Filter Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search ledger by description, type, reference ID, or staff name...',
                                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryGold),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryGold),
                            const SizedBox(width: 8),
                            const Text('Date Filter: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ChoiceChip(
                              label: const Text('All Records'),
                              selected: _selectedDateFilter == 'ALL',
                              onSelected: (_) => setState(() {
                                _selectedDateFilter = 'ALL';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Today'),
                              selected: _selectedDateFilter == 'TODAY',
                              onSelected: (_) => setState(() {
                                _selectedDateFilter = 'TODAY';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Yesterday'),
                              selected: _selectedDateFilter == 'YESTERDAY',
                              onSelected: (_) => setState(() {
                                _selectedDateFilter = 'YESTERDAY';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('This Month'),
                              selected: _selectedDateFilter == 'THIS_MONTH',
                              onSelected: (_) => setState(() {
                                _selectedDateFilter = 'THIS_MONTH';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Previous Month'),
                              selected: _selectedDateFilter == 'PREVIOUS_MONTH',
                              onSelected: (_) => setState(() {
                                _selectedDateFilter = 'PREVIOUS_MONTH';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              avatar: const Icon(Icons.date_range_rounded, size: 14),
                              label: Text(
                                _selectedDateFilter == 'CUSTOM' && _customDateRange != null
                                    ? '${DateFormatter.formatDate(_customDateRange!.start)} - ${DateFormatter.formatDate(_customDateRange!.end)}'
                                    : 'Custom Date Range',
                              ),
                              selected: _selectedDateFilter == 'CUSTOM',
                              onSelected: (_) async {
                                final picked = await CustomDateRangeDialog.show(
                                  context,
                                  initialStartDate: _customDateRange?.start,
                                  initialEndDate: _customDateRange?.end,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDateFilter = 'CUSTOM';
                                    _customDateRange = picked;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            Container(height: 24, width: 1, color: AppColors.border),
                            const SizedBox(width: 16),
                            const Text('Type: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ChoiceChip(
                              label: const Text('All Types'),
                              selected: _selectedTypeFilter == 'ALL',
                              onSelected: (_) => setState(() => _selectedTypeFilter = 'ALL'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Sales'),
                              selected: _selectedTypeFilter == 'SALE',
                              onSelected: (_) => setState(() => _selectedTypeFilter = 'SALE'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Expenses'),
                              selected: _selectedTypeFilter == 'EXPENSE',
                              onSelected: (_) => setState(() => _selectedTypeFilter = 'EXPENSE'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Transfers'),
                              selected: _selectedTypeFilter == 'TRANSFER',
                              onSelected: (_) => setState(() => _selectedTypeFilter = 'TRANSFER'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Audits'),
                              selected: _selectedTypeFilter == 'DISCREPANCY',
                              onSelected: (_) => setState(() => _selectedTypeFilter = 'DISCREPANCY'),
                            ),
                            const SizedBox(width: 16),
                            Container(height: 24, width: 1, color: AppColors.border),
                            const SizedBox(width: 16),
                            const Text('Channel: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ChoiceChip(
                              label: const Text('Both'),
                              selected: _selectedChannelFilter == 'ALL',
                              onSelected: (_) => setState(() => _selectedChannelFilter = 'ALL'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Cash Till'),
                              selected: _selectedChannelFilter == 'CASH',
                              onSelected: (_) => setState(() => _selectedChannelFilter = 'CASH'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Online/Bank'),
                              selected: _selectedChannelFilter == 'ONLINE',
                              onSelected: (_) => setState(() => _selectedChannelFilter = 'ONLINE'),
                            ),
                            if (isFilterActive) ...[
                              const SizedBox(width: 16),
                              Container(height: 24, width: 1, color: AppColors.border),
                              const SizedBox(width: 16),
                              TextButton.icon(
                                icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.ruby),
                                label: const Text('Clear Filters', style: TextStyle(color: AppColors.ruby, fontWeight: FontWeight.w700)),
                                onPressed: _clearAllFilters,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isFilterActive) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.primaryGold),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active Filter: ${_getDateFilterLabel()} • ${_selectedTypeFilter == "ALL" ? "All Types" : _selectedTypeFilter} • ${_selectedChannelFilter == "ALL" ? "Both Channels" : _selectedChannelFilter}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryGold),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _clearAllFilters,
                                    child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primaryGold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Transaction Ledger Table
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: filteredEntries.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 12),
                                const Text(
                                  'No transactions match the selected date range and filters.',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Try adjusting your search criteria, period filter, or clearing filters.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                                if (isFilterActive) ...[
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Reset All Filters'),
                                    onPressed: _clearAllFilters,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Description / Reference', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Cash Flow', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Online Flow', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Net Liquid Impact', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Recorded By', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: filteredEntries.map((entry) {
                              final isPos = entry.totalAmount >= 0;
                              Color tagBg;
                              Color tagText;
                              if (entry.transactionType == AppConstants.accountSaleIncome) {
                                tagBg = AppColors.emeraldLight;
                                tagText = AppColors.emerald;
                              } else if (entry.transactionType == AppConstants.accountExpense) {
                                tagBg = AppColors.rubyLight;
                                tagText = AppColors.ruby;
                              } else if (entry.transactionType == AppConstants.accountTransfer) {
                                tagBg = Colors.blue[50]!;
                                tagText = Colors.blue[800]!;
                              } else if (entry.transactionType.contains('SHORTAGE')) {
                                tagBg = AppColors.rubyLight;
                                tagText = AppColors.ruby;
                              } else {
                                tagBg = Colors.amber[50]!;
                                tagText = Colors.amber[900]!;
                              }

                              return DataRow(
                                cells: [
                                  DataCell(Text(entry.date)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: tagBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        entry.transactionType,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: tagText),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 320),
                                      child: Text(entry.description, overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      entry.cashAmount == 0
                                          ? '—'
                                          : '${entry.cashAmount > 0 ? "+" : ""}${CurrencyFormatter.format(entry.cashAmount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: entry.cashAmount > 0
                                            ? AppColors.cashColor
                                            : entry.cashAmount < 0
                                                ? AppColors.ruby
                                                : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      entry.onlineAmount == 0
                                          ? '—'
                                          : '${entry.onlineAmount > 0 ? "+" : ""}${CurrencyFormatter.format(entry.onlineAmount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: entry.onlineAmount > 0
                                            ? AppColors.onlineColor
                                            : entry.onlineAmount < 0
                                                ? AppColors.ruby
                                                : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${isPos ? "+" : ""}${CurrencyFormatter.format(entry.totalAmount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: entry.totalAmount > 0
                                            ? AppColors.emerald
                                            : entry.totalAmount < 0
                                                ? AppColors.ruby
                                                : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(entry.createdBy)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(String title, String value, IconData icon, Color color, {double? width}) {
    return Container(
      width: width ?? 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
