import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/shop_providers.dart';
import 'edit_product_dialog.dart';
import 'stock_purchase_dialog.dart';
import 'stock_history_dialog.dart';

class ProductDetailsDialog extends ConsumerWidget {
  final ProductModel product;

  const ProductDetailsDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(vendorsStreamProvider);
    final vendor = vendorsAsync.valueOrNull?.where((v) => v.vendorId == product.vendorId).firstOrNull;

    final unitMargin = product.sellingPricePerUnit - product.vendorPricePerUnit;
    final markup = product.vendorPricePerUnit > 0
        ? ((unitMargin / product.vendorPricePerUnit) * 100)
        : 0.0;

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
            child: Icon(
              product.isOil ? Icons.water_drop_rounded : Icons.inventory_2_rounded,
              color: AppColors.primaryGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.productName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(
                  'SKU: ${product.productCode} • ${product.category} • ${product.productType}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Supplier card
              if (vendor != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 18, color: AppColors.primaryGold),
                      const SizedBox(width: 8),
                      Text(
                        'Supplier: ${vendor.vendorName} (${vendor.companyName})',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        vendor.phoneNumber,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // KPI Grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricTile(
                    'Available Stock',
                    '${product.availableQuantity} ${product.unit}',
                    product.isOutOfStock ? AppColors.ruby : product.isLowStock ? Colors.deepOrange : AppColors.emerald,
                  ),
                  _buildMetricTile('Total Purchased', '${product.totalPurchased} ${product.unit}', AppColors.primaryDark),
                  _buildMetricTile('Total Sold', '${product.totalSold} ${product.unit}', AppColors.cashColor),
                  _buildMetricTile('Vendor Cost', '${CurrencyFormatter.formatSmart(product.vendorPricePerUnit)} / ${product.unit}', Colors.brown),
                  _buildMetricTile('Selling Price', '${CurrencyFormatter.formatSmart(product.sellingPricePerUnit)} / ${product.unit}', AppColors.emerald),
                  _buildMetricTile('Unit Margin', '${CurrencyFormatter.formatSmart(unitMargin)} (${markup.toStringAsFixed(1)}%)', AppColors.goldDark),
                  _buildMetricTile('Inventory Asset Cost', CurrencyFormatter.format(product.remainingStockCost), Colors.brown),
                  _buildMetricTile('Potential Selling Value', CurrencyFormatter.format(product.potentialSellingValue), AppColors.emerald),
                ],
              ),
              const SizedBox(height: 20),

              const Divider(),
              const SizedBox(height: 8),

              // Action bar inside modal
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Stock In / Purchase'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => StockPurchaseDialog(preselectedProduct: product),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Audit History'),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => StockHistoryDialog(product: product),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Edit Details & Price'),
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (_) => EditProductDialog(product: product),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
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

  Widget _buildMetricTile(String label, String value, Color valueColor) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }
}

