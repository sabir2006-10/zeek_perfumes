import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/shop_providers.dart';

class StockHistoryDialog extends ConsumerWidget {
  final ProductModel product;

  const StockHistoryDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsForProductProvider(product.productId));

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.history_rounded, color: AppColors.primaryGold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Movement Audit: ${product.productName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  'SKU: ${product.productCode} • Available: ${product.availableQuantity} ${product.unit}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 480,
        child: movementsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (movements) {
            if (movements.isEmpty) {
              return const Center(
                child: Text('No stock movements recorded for this product yet.'),
              );
            }

            return ListView.separated(
              itemCount: movements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final m = movements[index];
                final isPositive = m.quantity > 0;

                Color badgeColor;
                switch (m.movementType) {
                  case AppConstants.movementPurchase:
                    badgeColor = AppColors.emerald;
                    break;
                  case AppConstants.movementSale:
                    badgeColor = Colors.orange[800]!;
                    break;
                  case AppConstants.movementSaleReturn:
                    badgeColor = Colors.purple;
                    break;
                  case AppConstants.movementOpeningStock:
                    badgeColor = AppColors.cashColor;
                    break;
                  case AppConstants.movementAdjustment:
                    badgeColor = AppColors.primaryGold;
                    break;
                  default:
                    badgeColor = AppColors.ruby;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      // Movement Type Tag
                      Container(
                        width: 110,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          m.movementType.replaceAll('_', ' '),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Reference details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.referenceId.isNotEmpty ? m.referenceId : 'General movement',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Date: ${m.date} • Operator: ${m.createdBy}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),

                      // Quantity delta
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositive ? AppColors.emeraldLight : AppColors.rubyLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${isPositive ? "+" : ""}${m.quantity} ${m.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isPositive ? AppColors.emerald : AppColors.ruby,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

