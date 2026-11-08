import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../../services/invoice/invoice_pdf_service.dart';

class RecentSalesSheet extends ConsumerWidget {
  const RecentSalesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentSalesAsync = ref.watch(recentSalesProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxHeight: 550),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_toggle_off_rounded, color: AppColors.primaryGold, size: 22),
                  SizedBox(width: 10),
                  Text('Recent Sales & Receipts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            'Last 10 sales from this terminal. Reprint thermal receipts or download invoices.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 20),

          Expanded(
            child: recentSalesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
              error: (err, _) => Center(child: Text('Error loading recent sales: $err')),
              data: (sales) {
                if (sales.isEmpty) {
                  return const Center(
                    child: Text('No completed sales recorded yet.'),
                  );
                }

                return ListView.separated(
                  itemCount: sales.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('#${sale.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: sale.isVoided ? AppColors.rubyLight : AppColors.emeraldLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sale.status,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: sale.isVoided ? AppColors.ruby : AppColors.emerald,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sale.items.map((i) => '${i.productName} (${i.quantity}${i.unit})').join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                Text(
                                  '${DateFormatter.formatDateTime(sale.timestamp)} • ${sale.paymentType}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(sale.grandTotal),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.emerald),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Reprint Thermal Receipt',
                            icon: const Icon(Icons.print_rounded, size: 18, color: AppColors.primaryGold),
                            onPressed: () => InvoicePdfService.printReceipt(sale),
                          ),
                          IconButton(
                            tooltip: 'Download Invoice PDF',
                            icon: const Icon(Icons.download_rounded, size: 18, color: AppColors.cashColor),
                            onPressed: () => InvoicePdfService.shareReceipt(sale),
                          ),
                        ],
                      ),
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
}

