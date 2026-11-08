import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/shop_providers.dart';

class DailySummariesSheet extends ConsumerWidget {
  const DailySummariesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(recentDailySummariesProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxHeight: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppColors.primaryGold, size: 22),
                  SizedBox(width: 10),
                  Text('Daily Summaries & Rollovers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Aggregated daily closing balances. Yesterday’s closing rolls over into today’s opening balance.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 20),

          Expanded(
            child: summariesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
              error: (err, _) => Center(child: Text('Error loading summaries: $err')),
              data: (summaries) {
                if (summaries.isEmpty) {
                  return const Center(
                    child: Text('No daily summary records logged yet.'),
                  );
                }

                return ListView.separated(
                  itemCount: summaries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final summary = summaries[index];
                    return ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      title: Row(
                        children: [
                          Text(summary.date, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: summary.isClosed ? AppColors.emeraldLight : Colors.amber[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              summary.isClosed ? 'CLOSED' : 'OPEN / ACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: summary.isClosed ? AppColors.emerald : Colors.amber[900],
                              ),
                            ),
                          ),
                          if (summary.cashDiscrepancy.abs() > 0.01) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: summary.cashDiscrepancy < 0 ? AppColors.rubyLight : Colors.amber[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                summary.cashDiscrepancy < 0
                                    ? 'SHORT ${CurrencyFormatter.format(summary.cashDiscrepancy.abs())}'
                                    : 'OVER +${CurrencyFormatter.format(summary.cashDiscrepancy)}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: summary.cashDiscrepancy < 0 ? AppColors.ruby : Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        'Sales: ${CurrencyFormatter.format(summary.totalSales)} • Expenses: ${CurrencyFormatter.format(summary.totalExpenses)} • Net: ${CurrencyFormatter.format(summary.netTotalFlow)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Closing Liquid', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          Text(
                            CurrencyFormatter.format(summary.grandClosingBalance),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.emerald),
                          ),
                        ],
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: AppColors.surfaceMuted,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSummaryStat('Opening Cash', CurrencyFormatter.format(summary.openingCashBalance)),
                                  _buildSummaryStat('Cash Sales', '+${CurrencyFormatter.format(summary.cashSales)}'),
                                  _buildSummaryStat('Cash Expenses', '-${CurrencyFormatter.format(summary.cashExpenses)}'),
                                  _buildSummaryStat('Bank Deposits', '-${CurrencyFormatter.format(summary.cashDepositedToBank)}'),
                                  _buildSummaryStat('Closing Cash', CurrencyFormatter.format(summary.closingCashBalance), isHighlight: true),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSummaryStat('Opening Bank', CurrencyFormatter.format(summary.openingOnlineBalance)),
                                  _buildSummaryStat('Online/UPI Sales', '+${CurrencyFormatter.format(summary.onlineSales)}'),
                                  _buildSummaryStat('Online Expenses', '-${CurrencyFormatter.format(summary.onlineExpenses)}'),
                                  _buildSummaryStat('Cash Deposited', '+${CurrencyFormatter.format(summary.cashDepositedToBank)}'),
                                  _buildSummaryStat('Closing Bank', CurrencyFormatter.format(summary.closingOnlineBalance), isHighlight: true),
                                ],
                              ),
                              if (summary.notes != null && summary.notes!.isNotEmpty) ...[
                                const Divider(height: 16),
                                Text('Audited: ${summary.closedBy ?? "Staff"} • ${summary.notes}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isHighlight ? AppColors.primaryGold : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

