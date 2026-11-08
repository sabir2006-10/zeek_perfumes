import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/account_entry_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../../shared/widgets/custom_date_range_dialog.dart';
import '../../../services/reports/financial_report_pdf_service.dart';
import '../../authentication/providers/auth_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _dateFilter = 'ALL'; // ALL, TODAY, YESTERDAY, THIS_MONTH, PREVIOUS_MONTH, CUSTOM
  DateTimeRange? _customDateRange;
  bool _isGeneratingPdf = false;

  void _clearDateFilter() {
    setState(() {
      _dateFilter = 'ALL';
      _customDateRange = null;
    });
  }

  Future<void> _handleDownloadPdf({
    required List<SaleModel> salesToExport,
    required List<AccountEntryModel> entriesToExport,
    required String periodLabel,
    required String operatorName,
  }) async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      final now = DateTime.now();
      final nowStr = now.toIso8601String().substring(0, 10);
      String fileName;
      if (_dateFilter == 'TODAY') {
        fileName = 'Athar_Shop_Report_$nowStr.pdf';
      } else if (_dateFilter == 'YESTERDAY') {
        final yestStr = now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
        fileName = 'Athar_Shop_Report_$yestStr.pdf';
      } else if (_dateFilter == 'THIS_MONTH') {
        final monthStr = nowStr.substring(0, 7);
        fileName = 'Athar_Shop_Report_$monthStr.pdf';
      } else if (_dateFilter == 'PREVIOUS_MONTH') {
        final prevMonth = DateTime(now.year, now.month - 1, 1).toIso8601String().substring(0, 7);
        fileName = 'Athar_Shop_Report_$prevMonth.pdf';
      } else if (_dateFilter == 'CUSTOM' && _customDateRange != null) {
        final start = _customDateRange!.start.toIso8601String().substring(0, 10);
        final end = _customDateRange!.end.toIso8601String().substring(0, 10);
        fileName = 'Athar_Shop_Report_${start}_to_$end.pdf';
      } else {
        fileName = 'Athar_Shop_Report_$nowStr.pdf';
      }

      final success = await FinancialReportPdfService.generateAndDownloadReport(
        sales: salesToExport,
        entries: entriesToExport,
        periodLabel: periodLabel,
        fileName: fileName,
        generatedBy: operatorName,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('PDF Report "$fileName" downloaded successfully.')),
                ],
              ),
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Failed to generate PDF: $e')),
              ],
            ),
            backgroundColor: AppColors.ruby,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesStreamProvider);
    final accountsAsync = ref.watch(accountEntriesStreamProvider);
    final operatorName = ref.watch(authProvider).currentUser?.displayName ?? 'Zeek (Owner)';

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
        error: (err, _) => Center(child: Text('Error loading sales: $err')),
        data: (allSales) {
          return accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
            error: (err, _) => Center(child: Text('Error loading accounts: $err')),
            data: (allEntries) {
              // Apply Date Filters with full day bounds
              var filteredSales = allSales.toList();
              var filteredEntries = allEntries.toList();
              String periodLabel = 'All Records';

              if (_dateFilter == 'TODAY') {
                periodLabel = 'Today (${DateFormatter.formatDate(now)})';
                filteredSales = filteredSales.where((s) => !s.timestamp.isBefore(todayStart) && !s.timestamp.isAfter(todayEnd)).toList();
                filteredEntries = filteredEntries.where((e) => !e.createdAt.isBefore(todayStart) && !e.createdAt.isAfter(todayEnd)).toList();
              } else if (_dateFilter == 'YESTERDAY') {
                periodLabel = 'Yesterday (${DateFormatter.formatDate(yest)})';
                filteredSales = filteredSales.where((s) => !s.timestamp.isBefore(yesterdayStart) && !s.timestamp.isAfter(yesterdayEnd)).toList();
                filteredEntries = filteredEntries.where((e) => !e.createdAt.isBefore(yesterdayStart) && !e.createdAt.isAfter(yesterdayEnd)).toList();
              } else if (_dateFilter == 'THIS_MONTH') {
                periodLabel = 'This Month (${DateFormatter.formatMonth(now)})';
                filteredSales = filteredSales.where((s) => !s.timestamp.isBefore(thisMonthStart) && !s.timestamp.isAfter(thisMonthEnd)).toList();
                filteredEntries = filteredEntries.where((e) => !e.createdAt.isBefore(thisMonthStart) && !e.createdAt.isAfter(thisMonthEnd)).toList();
              } else if (_dateFilter == 'PREVIOUS_MONTH') {
                final prevMonthDate = DateTime(now.year, now.month - 1, 1);
                periodLabel = 'Previous Month (${DateFormatter.formatMonth(prevMonthDate)})';
                filteredSales = filteredSales.where((s) => !s.timestamp.isBefore(prevMonthStart) && !s.timestamp.isAfter(prevMonthEnd)).toList();
                filteredEntries = filteredEntries.where((e) => !e.createdAt.isBefore(prevMonthStart) && !e.createdAt.isAfter(prevMonthEnd)).toList();
              } else if (_dateFilter == 'CUSTOM' && _customDateRange != null) {
                final cStart = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
                final cEnd = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999);
                periodLabel = 'Custom (${DateFormatter.formatDate(_customDateRange!.start)} - ${DateFormatter.formatDate(_customDateRange!.end)})';

                filteredSales = filteredSales.where((s) => !s.timestamp.isBefore(cStart) && !s.timestamp.isAfter(cEnd)).toList();
                filteredEntries = filteredEntries.where((e) => !e.createdAt.isBefore(cStart) && !e.createdAt.isAfter(cEnd)).toList();
              }

              final activeSales = filteredSales.where((s) => !s.isVoided).toList();

              // Calculations
              final totalRevenue = activeSales.fold(0.0, (sum, s) => sum + s.grandTotal);
              final totalCashSales = activeSales.fold(0.0, (sum, s) => sum + s.cashAmount);
              final totalOnlineSales = activeSales.fold(0.0, (sum, s) => sum + s.onlineAmount);

              final totalCOGS = activeSales.fold(
                0.0,
                (sum, s) => sum + s.items.fold(0.0, (iSum, item) => iSum + (item.quantity * item.unitCostAtSale)),
              );

              final grossProfit = totalRevenue - totalCOGS;

              final operatingExpenses = filteredEntries
                  .where((e) => e.transactionType == AppConstants.accountExpense)
                  .fold(0.0, (sum, e) => sum + (e.cashAmount.abs() + e.onlineAmount.abs()));

              final netOperatingResult = grossProfit - operatingExpenses;

              final isMobile = MediaQuery.of(context).size.width < 600;
              final screenPadding = isMobile ? const EdgeInsets.all(16) : const EdgeInsets.all(24);

              return SingleChildScrollView(
                padding: screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header & Action Bar
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 260),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Financial Intelligence & Executive Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              Text('Comprehensive P&L, gross margins, payment channels & operating expenses', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          icon: _isGeneratingPdf
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: Text(
                            _isGeneratingPdf ? 'Generating PDF...' : 'Download PDF',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onPressed: _isGeneratingPdf
                              ? null
                              : () => _handleDownloadPdf(
                                    salesToExport: filteredSales,
                                    entriesToExport: filteredEntries,
                                    periodLabel: periodLabel,
                                    operatorName: operatorName,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryGold),
                            const SizedBox(width: 8),
                            const Text('Reporting Period: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
                            if (_dateFilter != 'ALL') ...[
                              const SizedBox(width: 16),
                              Container(height: 24, width: 1, color: AppColors.border),
                              const SizedBox(width: 16),
                              TextButton.icon(
                                icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.ruby),
                                label: const Text('Clear Filter', style: TextStyle(color: AppColors.ruby, fontWeight: FontWeight.w700)),
                                onPressed: _clearDateFilter,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Financial P&L Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final double cardWidth;
                        if (constraints.maxWidth < 460) {
                          cardWidth = constraints.maxWidth < 320 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
                        } else if (constraints.maxWidth < 750) {
                          cardWidth = (constraints.maxWidth - 24) / 3;
                        } else {
                          cardWidth = 210.0;
                        }

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildMetricCard('Gross Revenue', CurrencyFormatter.format(totalRevenue), 'Total customer sales', Icons.point_of_sale_rounded, AppColors.emerald, width: cardWidth),
                            _buildMetricCard('Cost of Goods (COGS)', CurrencyFormatter.format(totalCOGS), 'Wholesale product cost', Icons.inventory_2_outlined, Colors.brown, width: cardWidth),
                            _buildMetricCard('Gross Profit', CurrencyFormatter.format(grossProfit), 'Revenue minus COGS', Icons.trending_up_rounded, AppColors.goldDark, width: cardWidth),
                            _buildMetricCard('Operating Expenses', CurrencyFormatter.format(operatingExpenses), 'Rent, utilities & salaries', Icons.receipt_long_rounded, AppColors.ruby, width: cardWidth),
                            _buildMetricCard('Net Operating Result', CurrencyFormatter.format(netOperatingResult), 'Net shop profit', Icons.account_balance_wallet_rounded, netOperatingResult >= 0 ? AppColors.emerald : AppColors.ruby, width: cardWidth),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Visual Analytics Section
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 800;

                        final paymentCard = Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Channel Share', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 6),
                              const Text('Cash in register vs. UPI/Bank payments', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 24),
                              if (totalRevenue > 0) ...[
                                SizedBox(
                                  height: 180,
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 4,
                                      centerSpaceRadius: 40,
                                      sections: [
                                        PieChartSectionData(
                                          color: AppColors.cashColor,
                                          value: totalCashSales,
                                          title: '${((totalCashSales / totalRevenue) * 100).toStringAsFixed(1)}%',
                                          radius: 50,
                                          titleStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white),
                                        ),
                                        PieChartSectionData(
                                          color: AppColors.onlineColor,
                                          value: totalOnlineSales,
                                          title: '${((totalOnlineSales / totalRevenue) * 100).toStringAsFixed(1)}%',
                                          radius: 50,
                                          titleStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildLegend(AppColors.cashColor, 'Cash: ${CurrencyFormatter.format(totalCashSales)}'),
                                    const SizedBox(width: 24),
                                    _buildLegend(AppColors.onlineColor, 'Online: ${CurrencyFormatter.format(totalOnlineSales)}'),
                                  ],
                                ),
                              ] else ...[
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Text('No sales recorded for the selected period.', style: TextStyle(color: AppColors.textSecondary)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );

                        final profitLossCard = Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Shop Reconciliation & Profit Structure', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 6),
                              const Text('Strict distinction between sales income, stock expenditure and net realized profit', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 20),
                              _buildSummaryRow('Total Customer Revenue', totalRevenue, isPositive: true),
                              _buildSummaryRow('Less: Wholesale Cost of Goods Sold (COGS)', -totalCOGS, isPositive: false),
                              const Divider(height: 20),
                              _buildSummaryRow('Gross Operating Profit', grossProfit, isPositive: true, isBold: true),
                              const SizedBox(height: 8),
                              _buildSummaryRow('Less: Store Rent, Utilities & Overheads', -operatingExpenses, isPositive: false),
                              const Divider(height: 24, thickness: 1.5),
                              _buildSummaryRow('Net Business Result (After All Overheads)', netOperatingResult, isPositive: netOperatingResult >= 0, isBold: true, fontSize: 16),
                            ],
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              paymentCard,
                              const SizedBox(height: 20),
                              profitLossCard,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: paymentCard),
                            const SizedBox(width: 20),
                            Expanded(flex: 7, child: profitLossCard),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  Widget _buildSummaryRow(String title, double amount, {required bool isPositive, bool isBold = false, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
          Text(
            CurrencyFormatter.format(amount.abs()),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isPositive ? AppColors.emerald : AppColors.ruby,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color, {double? width}) {
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
