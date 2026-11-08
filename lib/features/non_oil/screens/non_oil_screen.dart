import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../inventory/widgets/stock_purchase_dialog.dart';
import '../../inventory/widgets/stock_history_dialog.dart';
import '../../inventory/widgets/edit_product_dialog.dart';
import '../../inventory/widgets/product_details_dialog.dart';

class NonOilScreen extends ConsumerStatefulWidget {
  const NonOilScreen({super.key});

  @override
  ConsumerState<NonOilScreen> createState() => _NonOilScreenState();
}

class _NonOilScreenState extends ConsumerState<NonOilScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddNonOilDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController(text: 'NON-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final catCtrl = TextEditingController(text: 'Perfume Sprays');
    final stockCtrl = TextEditingController(text: '25');
    final costCtrl = TextEditingController(text: '300');
    final sellCtrl = TextEditingController(text: '650');
    final thresholdCtrl = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Non-Oil Merchandise (Bottles / Sprays)', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enforced Rule: Non-oil products are strictly piece-based whole numbers (no decimal quantities).',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name (e.g. 50ml EDP Spray, 12ml Crystal Bottle) *')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'SKU / Code *'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category *'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Initial Pieces (Whole Number) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: thresholdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Low Stock Alert (pieces) *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Cost Price (₹/pc) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: sellCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Selling Price (₹/pc) *'),
                        ),
                      ),
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

                final rawStock = double.tryParse(stockCtrl.text) ?? 0.0;
                if (rawStock % 1 != 0 || rawStock < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Non-Oil pieces must be whole numbers (e.g. 10, not 10.5).')),
                  );
                  return;
                }

                final now = DateTime.now();
                final product = ProductModel(
                  productId: '',
                  productName: nameCtrl.text.trim(),
                  normalizedName: nameCtrl.text.trim().toLowerCase(),
                  productCode: codeCtrl.text.trim(),
                  productType: AppConstants.typeNonOil,
                  category: catCtrl.text.trim(),
                  unit: AppConstants.unitPiece,
                  availableQuantity: rawStock,
                  totalPurchased: rawStock,
                  vendorPricePerUnit: double.tryParse(costCtrl.text) ?? 0.0,
                  sellingPricePerUnit: double.tryParse(sellCtrl.text) ?? 0.0,
                  lowStockThreshold: double.tryParse(thresholdCtrl.text) ?? 5.0,
                  createdAt: now,
                  updatedAt: now,
                );
                await ref.read(shopRepositoryProvider).addProduct(product);
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Non-Oil Product'),
            ),
          ],
        );
      },
    );
  }

  void _showLogDamageDialog(ProductModel product) {
    final qtyCtrl = TextEditingController(text: '1');
    String reason = 'Broken Glass Bottle';
    final customNotesCtrl = TextEditingController();
    final user = ref.read(authProvider).currentUser?.displayName ?? 'Staff';

    final reasons = [
      'Broken Glass Bottle',
      'Defective Spray Nozzle / Leaking Valve',
      'Store Display Tester / Decant Sample',
      'Packaging Damaged in Transit',
      'Other Defect / Wastage',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final damagePieces = double.tryParse(qtyCtrl.text) ?? 0.0;
            final isExceeding = damagePieces > product.availableQuantity;

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
                    child: const Icon(Icons.broken_image_outlined, color: AppColors.ruby, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Log Breakage, Damage & Wastage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Product: ${product.productName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('Available in stock: ${product.availableQuantity.toInt()} pieces', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: reason,
                      decoration: const InputDecoration(labelText: 'Damage / Wastage Category'),
                      items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => reason = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Damaged / Broken Pieces (Whole number) *',
                        suffixText: 'pieces',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customNotesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Incident Notes / Staff Remarks (Optional)',
                        hintText: 'e.g. Dropped during shelf restock by shift assistant',
                      ),
                    ),
                    if (isExceeding) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Error: Damaged pieces ($damagePieces) exceed available stock (${product.availableQuantity.toInt()}).',
                        style: const TextStyle(color: AppColors.ruby, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.ruby, foregroundColor: Colors.white),
                  onPressed: isExceeding
                      ? null
                      : () async {
                          final pcs = double.tryParse(qtyCtrl.text) ?? 0.0;
                          if (pcs <= 0 || pcs % 1 != 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid whole number of pieces.')),
                            );
                            return;
                          }

                          final finalReason = customNotesCtrl.text.trim().isNotEmpty
                              ? '$reason: ${customNotesCtrl.text.trim()}'
                              : reason;

                          await ref.read(shopRepositoryProvider).adjustStock(
                                productId: product.productId,
                                productName: product.productName,
                                oldQuantity: product.availableQuantity,
                                newQuantity: product.availableQuantity - pcs,
                                unit: product.unit,
                                reason: finalReason,
                                user: user,
                                movementType: AppConstants.movementDamage,
                              );

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Logged $pcs damaged piece(s) for "${product.productName}". Inventory deducted.'),
                                backgroundColor: AppColors.ruby,
                              ),
                            );
                          }
                        },
                  child: const Text('Write Off Damaged Stock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAdjustStockDialog(ProductModel product) {
    final qtyCtrl = TextEditingController(text: product.availableQuantity.toInt().toString());
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
              Text('Current Stock: ${product.availableQuantity.toInt()} pieces', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New Verified Stock (whole pieces)'),
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
                if (newQty % 1 != 0 || newQty < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid whole number of pieces.')),
                  );
                  return;
                }
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

  @override
  Widget build(BuildContext context) {
    final nonOilAsync = ref.watch(nonOilProductsProvider);
    final user = ref.watch(authProvider).currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: nonOilAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (products) {
          final totalPieces = products.fold(0.0, (sum, p) => sum + p.availableQuantity);
          final totalCost = products.fold(0.0, (sum, p) => sum + (p.availableQuantity * p.vendorPricePerUnit));
          final potentialValue = products.fold(0.0, (sum, p) => sum + (p.availableQuantity * p.sellingPricePerUnit));

          final query = _searchController.text.trim().toLowerCase();
          final filtered = products.where((p) {
            return query.isEmpty ||
                p.normalizedName.contains(query) ||
                p.productCode.toLowerCase().contains(query);
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Non-Oil Inventory & Packaging', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('Sprays, deodorants, empty crystal bottles, decanting accessories & damage write-offs', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    if (user?.isAdmin ?? false)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Non-Oil Item'),
                        onPressed: () => _showAddNonOilDialog(context),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // KPI Row
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildKpiCard('Non-Oil SKUs', '${products.length} Products', Icons.category_outlined, AppColors.primaryDark),
                    _buildKpiCard('Total In-Stock', '${totalPieces.toInt()} Pieces', Icons.inventory_2_outlined, AppColors.cashColor),
                    _buildKpiCard('Stock Asset Cost', CurrencyFormatter.format(totalCost), Icons.shopping_basket_outlined, Colors.brown),
                    _buildKpiCard('Potential Retail Value', CurrencyFormatter.format(potentialValue), Icons.trending_up_rounded, AppColors.emerald),
                  ],
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search non-oil merchandise by perfume name, bottle type, or SKU...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primaryGold),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: filtered.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No non-oil products found.', style: TextStyle(color: AppColors.textSecondary))),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Product & SKU', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Pieces Available', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Cost / Piece', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Potential Value', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: filtered.map((p) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                        Text(p.productCode, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(p.category)),
                                  DataCell(
                                    Text(
                                      '${p.availableQuantity.toInt()} pcs',
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
                                          tooltip: 'Stock In Pieces',
                                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: AppColors.emerald),
                                          onPressed: () => showDialog(
                                            context: context,
                                            builder: (_) => StockPurchaseDialog(preselectedProduct: p),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Log Breakage / Damage Write-Off',
                                          icon: const Icon(Icons.broken_image_outlined, size: 18, color: AppColors.ruby),
                                          onPressed: () => _showLogDamageDialog(p),
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
                                          tooltip: 'Adjust Pieces',
                                          icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                                          onPressed: () => _showAdjustStockDialog(p),
                                        ),
                                        if (user?.isAdmin ?? false) ...[
                                          IconButton(
                                            tooltip: 'Edit Details & Price',
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryDark),
                                            onPressed: () => showDialog(
                                              context: context,
                                              builder: (_) => EditProductDialog(product: p),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Archive',
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
