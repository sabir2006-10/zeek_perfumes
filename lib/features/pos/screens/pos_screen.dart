import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../../services/invoice/invoice_pdf_service.dart';
import '../../authentication/providers/auth_provider.dart';
import '../widgets/discount_dialog.dart';
import '../widgets/recent_sales_sheet.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _customerPhoneCtrl = TextEditingController();
  final TextEditingController _splitCashCtrl = TextEditingController();
  final TextEditingController _splitOnlineCtrl = TextEditingController();

  String _selectedCategory = 'ALL';
  String _typeFilter = 'ALL'; // ALL, OIL, NON_OIL
  bool _showCustomerFields = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _splitCashCtrl.dispose();
    _splitOnlineCtrl.dispose();
    super.dispose();
  }

  void _showAddProductDialog(ProductModel product) {
    final qtyController = TextEditingController(
      text: product.isOil ? '10' : '1',
    );

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
                  color: AppColors.primaryGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  product.isOil ? Icons.water_drop_rounded : Icons.inventory_2_rounded,
                  color: AppColors.primaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      'Available: ${product.availableQuantity} ${product.unit}  •  ${CurrencyFormatter.formatSmart(product.sellingPricePerUnit)}/${product.unit}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter Quantity:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(decimal: product.isOil),
                decoration: InputDecoration(
                  suffixText: product.unit,
                  hintText: product.isOil ? 'e.g. 10 or 12.5' : 'e.g. 1',
                ),
              ),
              const SizedBox(height: 12),
              if (product.isOil) ...[
                const Text('Quick Select:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [3, 6, 12, 24, 50, 100].map((ml) {
                    return ActionChip(
                      label: Text('$ml ml', style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppColors.background,
                      onPressed: () => qtyController.text = ml.toString(),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text) ?? 0.0;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid quantity greater than 0.')),
                  );
                  return;
                }
                if (product.isNonOil && qty % 1 != 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Non-Oil piece products cannot have decimal quantities.')),
                  );
                  return;
                }
                ref.read(cartProvider.notifier).addOrUpdateProduct(product, qty);
                Navigator.pop(ctx);
              },
              child: const Text('Add to Cart'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCartItemDialog(int index, SaleItemModel item, double maxStock) {
    final qtyCtrl = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Quantity: ${item.productName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Available Stock: $maxStock ${item.unit}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(decimal: item.unit == AppConstants.unitMl),
                decoration: InputDecoration(
                  labelText: 'New Quantity (${item.unit})',
                  suffixText: item.unit,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newQty = double.tryParse(qtyCtrl.text) ?? 0.0;
                if (newQty <= 0) {
                  ref.read(cartProvider.notifier).removeItem(index);
                } else {
                  ref.read(cartProvider.notifier).updateItemQuantity(index, newQty, maxStock);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showInvoiceDialog(SaleModel sale) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sale Completed Successfully', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Inventory & accounts ledger updated atomically', style: TextStyle(fontSize: 12, color: AppColors.emerald)),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 460),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            Text('Invoice: #${sale.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(sale.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Cashier: ${sale.createdBy}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (sale.customerName != null && sale.customerName!.isNotEmpty)
                          Text('Customer: ${sale.customerName} (${sale.customerPhone ?? "N/A"})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text('Payment: ${sale.paymentType} (${CurrencyFormatter.format(sale.grandTotal)})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Items Sold:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...sale.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${item.productName} (${item.quantity} ${item.unit})', style: const TextStyle(fontSize: 13)),
                          ),
                          Text(CurrencyFormatter.format(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                  if (sale.discount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount:', style: TextStyle(fontSize: 12, color: AppColors.ruby)),
                        Text('-${CurrencyFormatter.format(sale.discount)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.ruby)),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(CurrencyFormatter.format(sale.grandTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.emerald)),
                    ],
                  ),
                  if (sale.paymentType == AppConstants.paymentSplit) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cash Paid: ${CurrencyFormatter.format(sale.cashAmount)}', style: const TextStyle(fontSize: 12, color: AppColors.cashColor)),
                        Text('Online Paid: ${CurrencyFormatter.format(sale.onlineAmount)}', style: const TextStyle(fontSize: 12, color: AppColors.onlineColor)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.print_rounded, size: 16, color: AppColors.primaryGold),
              label: const Text('Print Receipt'),
              onPressed: () => InvoicePdfService.printReceipt(sale),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16, color: AppColors.cashColor),
              label: const Text('Download PDF'),
              onPressed: () => InvoicePdfService.shareReceipt(sale),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(cartProvider.notifier).clearCart();
                _customerNameCtrl.clear();
                _customerPhoneCtrl.clear();
                _splitCashCtrl.clear();
                _splitOnlineCtrl.clear();
              },
              child: const Text('Start New Sale'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final cart = ref.watch(cartProvider);
    final user = ref.watch(authProvider).currentUser;
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
        error: (err, _) => Center(child: Text('Error loading products: $err')),
        data: (allProducts) {
          if (allProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.primaryGold),
                  const SizedBox(height: 16),
                  const Text('No Products Found in Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Seed sample Oud, Athar & Non-Oil products to start testing POS immediately.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: const Text('Load Sample Perfumes Catalog'),
                    onPressed: () async {
                      await ref.read(shopRepositoryProvider).seedInitialDataIfEmpty();
                    },
                  ),
                ],
              ),
            );
          }

          final query = _searchController.text.trim().toLowerCase();
          final filteredProducts = allProducts.where((p) {
            final matchesQuery = query.isEmpty ||
                p.normalizedName.contains(query) ||
                p.productCode.toLowerCase().contains(query);
            final matchesType = _typeFilter == 'ALL' || p.productType == _typeFilter;
            final matchesCat = _selectedCategory == 'ALL' || p.category == _selectedCategory;
            return matchesQuery && matchesType && matchesCat;
          }).toList();

          final categories = {'ALL', ...allProducts.map((e) => e.category)};

          if (isDesktop) {
            return Row(
              children: [
                // Left Panel: Product Catalogue & Search
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchAndFilters(categories, allProducts),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _buildProductGrid(filteredProducts),
                        ),
                      ],
                    ),
                  ),
                ),

                // Vertical Divider
                const VerticalDivider(width: 1, color: AppColors.border),

                // Right Panel: Active Cart & Checkout
                SizedBox(
                  width: 440,
                  child: _buildCartPanel(cart, user?.displayName ?? 'Staff', allProducts),
                ),
              ],
            );
          } else {
            // Mobile Tabbed Layout
            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      const Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Products'),
                      Tab(
                        icon: const Icon(Icons.shopping_bag_outlined),
                        text: 'Cart (${cart.items.length}) - ${CurrencyFormatter.formatSmart(cart.grandTotal)}',
                      ),
                    ],
                    labelColor: AppColors.primaryGold,
                    indicatorColor: AppColors.primaryGold,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              _buildSearchAndFilters(categories, allProducts),
                              const SizedBox(height: 12),
                              Expanded(child: _buildProductGrid(filteredProducts)),
                            ],
                          ),
                        ),
                        _buildCartPanel(cart, user?.displayName ?? 'Staff', allProducts),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(Set<String> categories, List<ProductModel> allProducts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barcode / SKU Quick Input & Search Field
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          onSubmitted: (barcodeOrSku) {
            final trimmed = barcodeOrSku.trim();
            if (trimmed.isNotEmpty) {
              final matched = ref.read(cartProvider.notifier).quickAddBySku(trimmed, allProducts);
              if (matched != null) {
                _searchController.clear();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Scanned: Added "${matched.productName}" to cart.'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.emerald,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('SKU / Barcode "$trimmed" not found in catalog.'),
                    backgroundColor: AppColors.ruby,
                  ),
                );
              }
            }
          },
          decoration: InputDecoration(
            hintText: 'Scan Barcode / SKU (Press Enter) or search by perfume name...',
            prefixIcon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryGold),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),
                IconButton(
                  tooltip: 'Quick Barcode Match',
                  icon: const Icon(Icons.keyboard_return_rounded, color: AppColors.primaryGold, size: 20),
                  onPressed: () {
                    final trimmed = _searchController.text.trim();
                    if (trimmed.isNotEmpty) {
                      final matched = ref.read(cartProvider.notifier).quickAddBySku(trimmed, allProducts);
                      if (matched != null) {
                        _searchController.clear();
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Scanned: Added "${matched.productName}" to cart.'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: AppColors.emerald,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Chips (Oil / Non-Oil & Categories)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Products'),
                selected: _typeFilter == 'ALL',
                onSelected: (_) => setState(() => _typeFilter = 'ALL'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Pure Oils / Athar'),
                avatar: const Icon(Icons.water_drop_rounded, size: 14, color: AppColors.oilTagText),
                selected: _typeFilter == AppConstants.typeOil,
                selectedColor: AppColors.oilTagBg,
                onSelected: (_) => setState(() => _typeFilter = AppConstants.typeOil),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Non-Oil / Sprays'),
                avatar: const Icon(Icons.category_rounded, size: 14, color: AppColors.nonOilTagText),
                selected: _typeFilter == AppConstants.typeNonOil,
                selectedColor: AppColors.nonOilTagBg,
                onSelected: (_) => setState(() => _typeFilter = AppConstants.typeNonOil),
              ),
              const SizedBox(width: 12),
              const VerticalDivider(width: 1),
              const SizedBox(width: 12),
              ...categories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: _selectedCategory == cat,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(List<ProductModel> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text('No products match your search criteria.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isLow = product.isLowStock;
        final isOut = product.isOutOfStock;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isOut ? AppColors.ruby.withOpacity(0.5) : AppColors.border,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isOut ? null : () => _showAddProductDialog(product),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: product.isOil ? AppColors.oilTagBg : AppColors.nonOilTagBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.productType,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: product.isOil ? AppColors.oilTagText : AppColors.nonOilTagText,
                          ),
                        ),
                      ),
                      if (isOut)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.rubyLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('OUT OF STOCK', style: TextStyle(color: AppColors.ruby, fontSize: 9, fontWeight: FontWeight.w800)),
                        )
                      else if (isLow)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('LOW STOCK', style: TextStyle(color: Colors.deepOrange, fontSize: 9, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.productCode,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Stock', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          Text(
                            '${product.availableQuantity} ${product.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isOut ? AppColors.ruby : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Price', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          Text(
                            CurrencyFormatter.formatSmart(product.sellingPricePerUnit),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartPanel(CartState cart, String cashierName, List<ProductModel> allProducts) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Cart Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined, color: AppColors.primaryGold, size: 20),
                    const SizedBox(width: 8),
                    const Text('Current Sale', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${cart.items.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Recent Terminal Sales',
                      icon: const Icon(Icons.history_toggle_off_rounded, color: AppColors.primaryGold, size: 20),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => const RecentSalesSheet(),
                        );
                      },
                    ),
                    if (cart.items.isNotEmpty)
                      TextButton(
                        onPressed: () => ref.read(cartProvider.notifier).clearCart(),
                        child: const Text('Clear', style: TextStyle(color: AppColors.ruby, fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          if (cart.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: AppColors.rubyLight,
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.ruby, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(cart.errorMessage!, style: const TextStyle(color: AppColors.ruby, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Cart Items List
          Expanded(
            child: cart.items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text('Cart is empty', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        Text('Select products or scan barcode to begin', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final prod = allProducts.where((p) => p.productId == item.productId).firstOrNull;
                      final maxAvailable = prod?.availableQuantity ?? (item.quantity + 100);

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  'Rate: ${CurrencyFormatter.formatSmart(item.unitPrice)}/${item.unit}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),

                          // Quantity Stepper Controls
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.textSecondary),
                                onPressed: () {
                                  final step = item.unit == AppConstants.unitMl ? 1.0 : 1.0;
                                  ref.read(cartProvider.notifier).updateItemQuantity(index, item.quantity - step, maxAvailable);
                                },
                              ),
                              InkWell(
                                onTap: () => _showEditCartItemDialog(index, item, maxAvailable),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${item.quantity} ${item.unit}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primaryGold),
                                onPressed: () {
                                  final step = item.unit == AppConstants.unitMl ? 1.0 : 1.0;
                                  ref.read(cartProvider.notifier).updateItemQuantity(index, item.quantity + step, maxAvailable);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(width: 4),
                          Text(
                            CurrencyFormatter.format(item.totalPrice),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.ruby),
                            onPressed: () => ref.read(cartProvider.notifier).removeItem(index),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Customer Details Expansion (Optional for receipts & loyalty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _showCustomerFields,
              onExpansionChanged: (exp) => setState(() => _showCustomerFields = exp),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              leading: const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primaryGold),
              title: const Text('Customer Details (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customerNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        onChanged: (name) => ref.read(cartProvider.notifier).setCustomerDetails(name: name),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _customerPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        onChanged: (phone) => ref.read(cartProvider.notifier).setCustomerDetails(phone: phone),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Payment Details and Checkout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Subtotal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(CurrencyFormatter.format(cart.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),

                // Discount Row with Interactive Dialog Trigger
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Discount:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => showDialog(context: context, builder: (_) => const DiscountDialog()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cart.discountAmount > 0 ? AppColors.rubyLight : AppColors.primaryGold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.discount_outlined,
                                  size: 12,
                                  color: cart.discountAmount > 0 ? AppColors.ruby : AppColors.primaryGold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cart.discountAmount > 0
                                      ? (cart.discountType == 'PERCENT'
                                          ? '${cart.discountValue.toStringAsFixed(0)}% Off'
                                          : 'Flat ₹${cart.discountAmount.toStringAsFixed(0)} Off')
                                      : 'Add Discount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cart.discountAmount > 0 ? AppColors.ruby : AppColors.primaryGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      cart.discountAmount > 0 ? '-${CurrencyFormatter.format(cart.discountAmount)}' : '₹0.00',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: cart.discountAmount > 0 ? AppColors.ruby : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      CurrencyFormatter.format(cart.grandTotal),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.emerald),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Payment Type Selector
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Cash', style: TextStyle(fontSize: 12))),
                        selected: cart.paymentType == AppConstants.paymentCash,
                        selectedColor: AppColors.primaryGold.withOpacity(0.2),
                        onSelected: (_) {
                          ref.read(cartProvider.notifier).setPaymentType(AppConstants.paymentCash);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Online/UPI', style: TextStyle(fontSize: 12))),
                        selected: cart.paymentType == AppConstants.paymentOnline,
                        selectedColor: AppColors.onlineColor.withOpacity(0.2),
                        onSelected: (_) {
                          ref.read(cartProvider.notifier).setPaymentType(AppConstants.paymentOnline);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Split', style: TextStyle(fontSize: 12))),
                        selected: cart.paymentType == AppConstants.paymentSplit,
                        selectedColor: Colors.orange.withOpacity(0.2),
                        onSelected: (_) {
                          ref.read(cartProvider.notifier).setPaymentType(AppConstants.paymentSplit);
                          _splitCashCtrl.text = (cart.grandTotal / 2).toStringAsFixed(0);
                          _splitOnlineCtrl.text = (cart.grandTotal / 2).toStringAsFixed(0);
                          ref.read(cartProvider.notifier).setSplitAmounts(cart.grandTotal / 2, cart.grandTotal / 2);
                        },
                      ),
                    ),
                  ],
                ),

                // Split inputs if Split is chosen
                if (cart.paymentType == AppConstants.paymentSplit) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _splitCashCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Cash Part (₹)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final cash = double.tryParse(val) ?? 0.0;
                            final online = (cart.grandTotal - cash).clamp(0.0, double.infinity);
                            _splitOnlineCtrl.text = online.toStringAsFixed(0);
                            ref.read(cartProvider.notifier).setSplitAmounts(cash, online);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _splitOnlineCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Online Part (₹)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final online = double.tryParse(val) ?? 0.0;
                            final cash = (cart.grandTotal - online).clamp(0.0, double.infinity);
                            _splitCashCtrl.text = cash.toStringAsFixed(0);
                            ref.read(cartProvider.notifier).setSplitAmounts(cash, online);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cart.isPaymentValid
                            ? '✓ Split allocation balanced'
                            : 'Allocation mismatch: ₹${(cart.grandTotal - (cart.customCashAmount + cart.customOnlineAmount)).abs().toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cart.isPaymentValid ? AppColors.emerald : AppColors.ruby,
                        ),
                      ),
                      Text(
                        'Cash: ${CurrencyFormatter.format(cart.customCashAmount)} | UPI: ${CurrencyFormatter.format(cart.customOnlineAmount)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Complete Sale Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (cart.items.isEmpty || cart.isProcessing || !cart.isPaymentValid)
                        ? null
                        : () async {
                            final ok = await ref.read(cartProvider.notifier).checkout(cashierName);
                            if (ok && mounted) {
                              final sale = ref.read(cartProvider).lastCompletedSale;
                              if (sale != null) {
                                _showInvoiceDialog(sale);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: cart.isProcessing
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            'Complete Sale (${CurrencyFormatter.format(cart.grandTotal)})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
}
