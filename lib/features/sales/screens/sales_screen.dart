import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../../services/invoice/invoice_pdf_service.dart';
import '../../../shared/widgets/custom_date_range_dialog.dart';
import '../../authentication/providers/auth_provider.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _dateFilter = 'ALL'; // ALL, TODAY, YESTERDAY, THIS_MONTH, PREVIOUS_MONTH, CUSTOM
  DateTimeRange? _customDateRange;
  String _paymentFilter = 'ALL'; // ALL, CASH, ONLINE, SPLIT
  String _statusFilter = 'ALL'; // ALL, COMPLETED, VOIDED
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAllFilters() {
    setState(() {
      _dateFilter = 'ALL';
      _customDateRange = null;
      _paymentFilter = 'ALL';
      _statusFilter = 'ALL';
      _searchController.clear();
    });
  }

  String _getDateFilterLabel() {
    final now = DateTime.now();
    switch (_dateFilter) {
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

  void _showSaleDetailsDialog(SaleModel sale) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.primaryGold, size: 22),
                  const SizedBox(width: 10),
                  Text('Invoice #${sale.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sale.isVoided ? AppColors.rubyLight : AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sale.status,
                  style: TextStyle(
                    color: sale.isVoided ? AppColors.ruby : AppColors.emerald,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Date: ${DateFormatter.formatDateTime(sale.timestamp)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('Cashier: ${sale.createdBy}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (sale.customerName != null && sale.customerName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Customer: ${sale.customerName} (${sale.customerPhone ?? "N/A"})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                        const SizedBox(height: 4),
                        Text('Payment Mode: ${sale.paymentType}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Items Purchased:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...sale.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(
                                  '${item.quantity} ${item.unit} × ${CurrencyFormatter.formatSmart(item.unitPrice)}/${item.unit}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(CurrencyFormatter.format(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.format(sale.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  if (sale.discount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount:', style: TextStyle(fontSize: 13, color: AppColors.ruby)),
                        Text('-${CurrencyFormatter.format(sale.discount)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ruby)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        CurrencyFormatter.format(sale.grandTotal),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.emerald),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cash Paid: ${CurrencyFormatter.format(sale.cashAmount)}', style: const TextStyle(fontSize: 12)),
                      Text('Online Paid: ${CurrencyFormatter.format(sale.onlineAmount)}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  if (sale.isVoided) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.rubyLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('VOID REVERSAL AUDIT NOTE:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.ruby)),
                          const SizedBox(height: 2),
                          Text(sale.notes ?? 'No void reason specified.', style: const TextStyle(fontSize: 11, color: AppColors.ruby)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Receipt'),
              onPressed: () {
                InvoicePdfService.printReceipt(sale);
              },
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _showVoidSaleDialog(SaleModel sale) {
    final reasonCtrl = TextEditingController();
    final user = ref.read(authProvider).currentUser?.displayName ?? 'Admin';

    showDialog(
      context: context,
      builder: (ctx) {
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
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.ruby, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Void Sale #${sale.invoiceNumber}?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to void this transaction? This action strictly triggers the following accounting & inventory reverse mutations:',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                const Text('• Restores deducted stock quantities directly into inventory.'),
                const Text('• Writes "SALE_RETURN" stock audit movement records.'),
                const Text('• Posts a negative "REFUND" debit in the financial ledger.'),
                const Text('• Reconciles the day\'s closing cash/online balances.'),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Cancellation / Return Reason *',
                    hintText: 'e.g. Wrong perfume bottle selected by customer',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.ruby, foregroundColor: Colors.white),
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) return;
                await ref.read(shopRepositoryProvider).voidSale(
                      saleId: sale.saleId,
                      reason: reasonCtrl.text.trim(),
                      user: user,
                    );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Sale #${sale.invoiceNumber} voided. Stock & accounts restored.'),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                }
              },
              child: const Text('Confirm Void Reversal'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesStreamProvider);
    final user = ref.watch(authProvider).currentUser;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (sales) {
          // Apply multi-attribute filters
          final query = _searchController.text.trim().toLowerCase();

          final filteredSales = sales.where((s) {
            // Text search across invoice, saleId, customer name/phone, cashier, items
            final matchesQuery = query.isEmpty ||
                s.invoiceNumber.toLowerCase().contains(query) ||
                s.saleId.toLowerCase().contains(query) ||
                (s.customerName?.toLowerCase().contains(query) ?? false) ||
                (s.customerPhone?.contains(query) ?? false) ||
                s.createdBy.toLowerCase().contains(query) ||
                s.items.any((i) => i.productName.toLowerCase().contains(query));

            // Date filtering with full inclusion of end dates
            bool matchesDate = true;
            if (_dateFilter == 'TODAY') {
              matchesDate = !s.timestamp.isBefore(todayStart) && !s.timestamp.isAfter(todayEnd);
            } else if (_dateFilter == 'YESTERDAY') {
              matchesDate = !s.timestamp.isBefore(yesterdayStart) && !s.timestamp.isAfter(yesterdayEnd);
            } else if (_dateFilter == 'THIS_MONTH') {
              matchesDate = !s.timestamp.isBefore(thisMonthStart) && !s.timestamp.isAfter(thisMonthEnd);
            } else if (_dateFilter == 'PREVIOUS_MONTH') {
              matchesDate = !s.timestamp.isBefore(prevMonthStart) && !s.timestamp.isAfter(prevMonthEnd);
            } else if (_dateFilter == 'CUSTOM' && _customDateRange != null) {
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
              matchesDate = !s.timestamp.isBefore(cStart) && !s.timestamp.isAfter(cEnd);
            }

            final matchesPayment = _paymentFilter == 'ALL' || s.paymentType == _paymentFilter;
            final matchesStatus = _statusFilter == 'ALL' ||
                (_statusFilter == 'COMPLETED' && !s.isVoided) ||
                (_statusFilter == 'VOIDED' && s.isVoided);

            return matchesQuery && matchesDate && matchesPayment && matchesStatus;
          }).toList();

          // Summary calculated STRICTLY based on the currently filtered records
          final activeFilteredSales = filteredSales.where((s) => !s.isVoided).toList();
          final filteredSalesCount = activeFilteredSales.length;
          final filteredTotalSalesAmount = activeFilteredSales.fold(0.0, (sum, s) => sum + s.grandTotal);
          final filteredCashSalesAmount = activeFilteredSales.fold(0.0, (sum, s) => sum + s.cashAmount);
          final filteredOnlineSalesAmount = activeFilteredSales.fold(0.0, (sum, s) => sum + s.onlineAmount);

          final isFilterActive = _dateFilter != 'ALL' ||
              _paymentFilter != 'ALL' ||
              _statusFilter != 'ALL' ||
              _searchController.text.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales Transactions & Invoicing Hub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('Complete invoice audit history, reprint receipts, payment analysis & controlled voids', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 20),

                // Responsive KPI Summary Row reflecting strictly filtered records
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

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildKpiCard(
                          'Total Number of Sales',
                          '$filteredSalesCount Invoices',
                          Icons.receipt_long_rounded,
                          AppColors.primaryGold,
                          width: cardWidth,
                        ),
                        _buildKpiCard(
                          'Total Sales Amount',
                          CurrencyFormatter.format(filteredTotalSalesAmount),
                          Icons.monetization_on_outlined,
                          AppColors.emerald,
                          width: cardWidth,
                        ),
                        _buildKpiCard(
                          'Total Cash Sales',
                          CurrencyFormatter.format(filteredCashSalesAmount),
                          Icons.payments_outlined,
                          AppColors.cashColor,
                          width: cardWidth,
                        ),
                        _buildKpiCard(
                          'Total Online Sales',
                          CurrencyFormatter.format(filteredOnlineSalesAmount),
                          Icons.account_balance_outlined,
                          AppColors.onlineColor,
                          width: cardWidth,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Filter Hub Container
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
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by Invoice #, customer phone/name, perfume name, cashier, or ID...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryGold),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
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
                              selected: _dateFilter == 'ALL',
                              onSelected: (_) => setState(() {
                                _dateFilter = 'ALL';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Today'),
                              selected: _dateFilter == 'TODAY',
                              onSelected: (_) => setState(() {
                                _dateFilter = 'TODAY';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Yesterday'),
                              selected: _dateFilter == 'YESTERDAY',
                              onSelected: (_) => setState(() {
                                _dateFilter = 'YESTERDAY';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('This Month'),
                              selected: _dateFilter == 'THIS_MONTH',
                              onSelected: (_) => setState(() {
                                _dateFilter = 'THIS_MONTH';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Previous Month'),
                              selected: _dateFilter == 'PREVIOUS_MONTH',
                              onSelected: (_) => setState(() {
                                _dateFilter = 'PREVIOUS_MONTH';
                                _customDateRange = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              avatar: const Icon(Icons.date_range_rounded, size: 14),
                              label: Text(
                                _dateFilter == 'CUSTOM' && _customDateRange != null
                                    ? '${DateFormatter.formatDate(_customDateRange!.start)} - ${DateFormatter.formatDate(_customDateRange!.end)}'
                                    : 'Custom Date Range',
                              ),
                              selected: _dateFilter == 'CUSTOM',
                              onSelected: (_) async {
                                final picked = await CustomDateRangeDialog.show(
                                  context,
                                  initialStartDate: _customDateRange?.start,
                                  initialEndDate: _customDateRange?.end,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _dateFilter = 'CUSTOM';
                                    _customDateRange = picked;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            Container(height: 24, width: 1, color: AppColors.border),
                            const SizedBox(width: 16),
                            const Text('Payment: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _paymentFilter == 'ALL',
                              onSelected: (_) => setState(() => _paymentFilter = 'ALL'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Cash'),
                              selected: _paymentFilter == AppConstants.paymentCash,
                              onSelected: (_) => setState(() => _paymentFilter = AppConstants.paymentCash),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Online/UPI'),
                              selected: _paymentFilter == AppConstants.paymentOnline,
                              onSelected: (_) => setState(() => _paymentFilter = AppConstants.paymentOnline),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Split'),
                              selected: _paymentFilter == AppConstants.paymentSplit,
                              onSelected: (_) => setState(() => _paymentFilter = AppConstants.paymentSplit),
                            ),
                            const SizedBox(width: 16),
                            Container(height: 24, width: 1, color: AppColors.border),
                            const SizedBox(width: 16),
                            const Text('Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _statusFilter == 'ALL',
                              onSelected: (_) => setState(() => _statusFilter = 'ALL'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Completed'),
                              selected: _statusFilter == 'COMPLETED',
                              onSelected: (_) => setState(() => _statusFilter = 'COMPLETED'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Voided'),
                              selected: _statusFilter == 'VOIDED',
                              onSelected: (_) => setState(() => _statusFilter = 'VOIDED'),
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
                                    'Active Filter: ${_getDateFilterLabel()} • ${_paymentFilter == "ALL" ? "All Payments" : _paymentFilter} • ${_statusFilter == "ALL" ? "All Statuses" : _statusFilter}',
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

                // Transactions Table
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: filteredSales.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 12),
                                const Text(
                                  'No sales records found for the selected date range and filters.',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Try adjusting your search keywords, period filter, or clearing filters.',
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
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Items Breakdown', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Cashier', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: filteredSales.map((sale) {
                              final itemsSummary = sale.items.map((i) => '${i.productName} (${i.quantity} ${i.unit})').join(', ');
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      '#${sale.invoiceNumber}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: sale.isVoided ? AppColors.ruby : AppColors.primaryGold,
                                        decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(DateFormatter.formatDateTime(sale.timestamp), style: const TextStyle(fontSize: 12)),
                                  ),
                                  DataCell(
                                    Text(
                                      sale.customerName?.isNotEmpty == true ? sale.customerName! : 'Walk-in',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        itemsSummary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      CurrencyFormatter.format(sale.grandTotal),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: sale.isVoided ? AppColors.ruby : AppColors.emerald,
                                        decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: sale.paymentType == AppConstants.paymentCash
                                            ? AppColors.cashColor.withOpacity(0.15)
                                            : (sale.paymentType == AppConstants.paymentOnline
                                                ? AppColors.onlineColor.withOpacity(0.15)
                                                : AppColors.primaryGold.withOpacity(0.15)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sale.paymentType,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: sale.paymentType == AppConstants.paymentCash
                                              ? AppColors.cashColor
                                              : (sale.paymentType == AppConstants.paymentOnline
                                                  ? AppColors.onlineColor
                                                  : AppColors.primaryGold),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(sale.createdBy, style: const TextStyle(fontSize: 12))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: sale.isVoided ? AppColors.rubyLight : AppColors.emeraldLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        sale.status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: sale.isVoided ? AppColors.ruby : AppColors.emerald,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'View Invoice & Reprint',
                                          icon: const Icon(Icons.receipt_rounded, size: 18, color: AppColors.primaryGold),
                                          onPressed: () => _showSaleDetailsDialog(sale),
                                        ),
                                        IconButton(
                                          tooltip: 'Quick Thermal Print',
                                          icon: const Icon(Icons.print_rounded, size: 18, color: AppColors.cashColor),
                                          onPressed: () => InvoicePdfService.printReceipt(sale),
                                        ),
                                        if (!sale.isVoided && (user?.isAdmin ?? false))
                                          IconButton(
                                            tooltip: 'Void Sale & Reverse Stock',
                                            icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.ruby),
                                            onPressed: () => _showVoidSaleDialog(sale),
                                          ),
                                      ],
                                    ),
                                  ),
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

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, {double? width}) {
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
