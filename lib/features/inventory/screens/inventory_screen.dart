import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../../services/csv/csv_inventory_service.dart';
import '../../authentication/providers/auth_provider.dart';
import '../widgets/stock_purchase_dialog.dart';
import '../widgets/stock_history_dialog.dart';
import '../widgets/edit_product_dialog.dart';
import '../widgets/product_details_dialog.dart';
import '../widgets/csv_import_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddProductDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController(text: 'OIL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final catCtrl = TextEditingController(text: 'Pure Dehn Al Oud');
    final stockCtrl = TextEditingController(text: '100');
    final costCtrl = TextEditingController(text: '50');
    final sellCtrl = TextEditingController(text: '120');
    final thresholdCtrl = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Perfume / Oil Product', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name (e.g. Royal Amber Athar)')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'SKU / Code'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening Stock (ml)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: thresholdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Low Stock Alert (ml)'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Vendor Cost (₹/ml)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹/ml)'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final now = DateTime.now();
                final product = ProductModel(
                  productId: '',
                  productName: nameCtrl.text.trim(),
                  normalizedName: nameCtrl.text.trim().toLowerCase(),
                  productCode: codeCtrl.text.trim(),
                  productType: AppConstants.typeOil,
                  category: catCtrl.text.trim(),
                  unit: AppConstants.unitMl,
                  availableQuantity: double.tryParse(stockCtrl.text) ?? 0.0,
                  totalPurchased: double.tryParse(stockCtrl.text) ?? 0.0,
                  vendorPricePerUnit: double.tryParse(costCtrl.text) ?? 0.0,
                  sellingPricePerUnit: double.tryParse(sellCtrl.text) ?? 0.0,
                  lowStockThreshold: double.tryParse(thresholdCtrl.text) ?? 10.0,
                  createdAt: now,
                  updatedAt: now,
                );
                await ref.read(shopRepositoryProvider).addProduct(product);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Product'),
            ),
          ],
        );
      },
    );
  }

  void _showAdjustStockDialog(ProductModel product) {
    final qtyCtrl = TextEditingController(text: product.availableQuantity.toString());
    final reasonCtrl = TextEditingController(text: 'Physical Inventory Audit');
    final user = ref.read(authProvider).currentUser?.displayName ?? 'Admin';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Adjust Stock: ${product.productName}', style: const TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Stock: ${product.availableQuantity} ${product.unit}', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'New Verified Stock (${product.unit})'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason for Adjustment'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newQty = double.tryParse(qtyCtrl.text) ?? product.availableQuantity;
                await ref.read(shopRepositoryProvider).adjustStock(
                      productId: product.productId,
                      productName: product.productName,
                      oldQuantity: product.availableQuantity,
                      newQuantity: newQty,
                      unit: product.unit,
                      reason: reasonCtrl.text.trim(),
                      user: user,
                    );
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Confirm Adjustment'),
            ),
          ],
        );
      },
    );
  }

  void _exportCsv(List<ProductModel> products) {
    final csvString = CsvInventoryService.exportProductsToCsv(products);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.file_download_done_rounded, color: AppColors.emerald, size: 24),
              const SizedBox(width: 10),
              Text('Exported ${products.length} Products to CSV', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CSV snapshot generated successfully for Excel / Spreadsheets:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: AppColors.surfaceMuted,
                  child: SelectableText(
                    csvString,
                    maxLines: 8,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(oilProductsProvider);
    final user = ref.watch(authProvider).currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
        error: (err, _) => Center(child: Text('Error loading inventory: $err')),
        data: (products) {
          // Calculate KPI metrics
          final totalProducts = products.length;
          final totalStockMl = products.fold(0.0, (sum, p) => sum + p.availableQuantity);
          final totalPurchaseCost = products.fold(0.0, (sum, p) => sum + (p.availableQuantity * p.vendorPricePerUnit));
          final potentialValue = products.fold(0.0, (sum, p) => sum + (p.availableQuantity * p.sellingPricePerUnit));
          final lowStockProducts = products.where((p) => p.isLowStock || p.isOutOfStock).toList();

          // Filter
          final query = _searchController.text.trim().toLowerCase();
          final filtered = products.where((p) {
            final matchesQuery = query.isEmpty ||
                p.normalizedName.contains(query) ||
                p.productCode.toLowerCase().contains(query);
            final matchesCat = _selectedCategory == 'ALL' || p.category == _selectedCategory;
            return matchesQuery && matchesCat;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Actions (Responsive Wrap to eliminate RenderFlex overflow)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Oil & Athar Inventory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('Master stock management, wholesale cost & selling margins', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Export CSV'),
                          onPressed: () => _exportCsv(products),
                        ),
                        if (user?.isAdmin ?? false) ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                            label: const Text('Import CSV'),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => const CsvImportDialog(),
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                            label: const Text('Stock In / Purchase'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => const StockPurchaseDialog(),
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Oil Product'),
                            onPressed: () => _showAddProductDialog(context),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sticky Low Stock Alert Banner
                if (lowStockProducts.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '⚠️ Low Stock Alert: ${lowStockProducts.length} items need replenishment (${lowStockProducts.map((p) => "${p.productName} (${p.availableQuantity}${p.unit})").take(3).join(", ")}${lowStockProducts.length > 3 ? "..." : ""}).',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.deepOrange),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                          label: const Text('Quick Stock In', style: TextStyle(fontSize: 12)),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => StockPurchaseDialog(preselectedProduct: lowStockProducts.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // KPI Metrics Row
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildKpiCard('Active Oils', '$totalProducts Items', Icons.spa_outlined, AppColors.primaryDark),
                    _buildKpiCard('Total Stock', '${totalStockMl.toStringAsFixed(1)} ml', Icons.water_drop_outlined, AppColors.cashColor),
                    _buildKpiCard('Stock Cost', CurrencyFormatter.format(totalPurchaseCost), Icons.shopping_basket_outlined, Colors.brown),
                    _buildKpiCard('Potential Value', CurrencyFormatter.format(potentialValue), Icons.trending_up_rounded, AppColors.emerald),
                    _buildKpiCard('Low / Out of Stock', '${lowStockProducts.length} Items', Icons.warning_amber_rounded, AppColors.ruby),
                  ],
                ),
                const SizedBox(height: 24),

                // Filter & Search bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Filter by oil name, code...',
                          prefixIcon: Icon(Icons.search, color: AppColors.primaryGold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table view
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product & SKU', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Available Stock', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Cost / ml', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Selling / ml', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Potential Value', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                      rows: filtered.map((p) {
                        return DataRow(
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => ProductDetailsDialog(product: p),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryDark)),
                                    Text(p.productCode, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Text(p.category)),
                            DataCell(
                              Text(
                                '${p.availableQuantity} ${p.unit}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: p.isOutOfStock ? AppColors.ruby : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            DataCell(Text(CurrencyFormatter.formatSmart(p.vendorPricePerUnit))),
                            DataCell(Text(CurrencyFormatter.formatSmart(p.sellingPricePerUnit), style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text(CurrencyFormatter.format(p.potentialSellingValue))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: p.isOutOfStock
                                      ? AppColors.rubyLight
                                      : p.isLowStock
                                          ? Colors.orange[50]
                                          : AppColors.emeraldLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.isOutOfStock
                                      ? 'Out of Stock'
                                      : p.isLowStock
                                          ? 'Low Stock'
                                          : 'Healthy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p.isOutOfStock
                                        ? AppColors.ruby
                                        : p.isLowStock
                                            ? Colors.deepOrange
                                            : AppColors.emerald,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'View Profile & Margin Breakdown',
                                    icon: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.primaryGold),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => ProductDetailsDialog(product: p),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Stock In / Procurement',
                                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: AppColors.emerald),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => StockPurchaseDialog(preselectedProduct: p),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Audit Movement History',
                                    icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.cashColor),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => StockHistoryDialog(product: p),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Adjust Stock',
                                    icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                                    onPressed: () => _showAdjustStockDialog(p),
                                  ),
                                  if (user?.isAdmin ?? false) ...[
                                    IconButton(
                                      tooltip: 'Edit Product & Pricing',
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryDark),
                                      onPressed: () => showDialog(
                                        context: context,
                                        builder: (_) => EditProductDialog(product: p),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Archive Product',
                                      icon: const Icon(Icons.archive_outlined, size: 18, color: AppColors.ruby),
                                      onPressed: () async {
                                        await ref.read(shopRepositoryProvider).archiveProduct(p.productId);
                                      },
                                    ),
                                  ],
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

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 200,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
