import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../authentication/providers/auth_provider.dart';

class StockPurchaseDialog extends ConsumerStatefulWidget {
  final ProductModel? preselectedProduct;

  const StockPurchaseDialog({super.key, this.preselectedProduct});

  @override
  ConsumerState<StockPurchaseDialog> createState() => _StockPurchaseDialogState();
}

class _StockPurchaseDialogState extends ConsumerState<StockPurchaseDialog> {
  String? _selectedProductId;
  String? _selectedVendorId;
  final TextEditingController _qtyCtrl = TextEditingController(text: '100');
  final TextEditingController _unitPriceCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  String _paymentMethod = AppConstants.paymentOnline;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedProduct != null) {
      _selectedProductId = widget.preselectedProduct!.productId;
      _selectedVendorId = widget.preselectedProduct!.vendorId.isNotEmpty
          ? widget.preselectedProduct!.vendorId
          : null;
      _unitPriceCtrl.text = widget.preselectedProduct!.vendorPricePerUnit.toString();
      _qtyCtrl.text = widget.preselectedProduct!.isOil ? '250' : '20';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _unitPriceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final vendorsAsync = ref.watch(vendorsStreamProvider);
    final user = ref.watch(authProvider).currentUser?.displayName ?? 'Admin';

    final allProducts = productsAsync.valueOrNull ?? [];
    final selectedProduct = allProducts.where((p) => p.productId == _selectedProductId).firstOrNull ??
        widget.preselectedProduct;

    final allVendors = vendorsAsync.valueOrNull ?? [];
    final selectedVendor = allVendors.where((v) => v.vendorId == _selectedVendorId).firstOrNull;

    final qty = double.tryParse(_qtyCtrl.text) ?? 0.0;
    final unitPrice = double.tryParse(_unitPriceCtrl.text) ?? 0.0;
    final totalCost = qty * unitPrice;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.emerald, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Stock In / Purchase Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  'Procure inventory, update stock balances & track cost',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Selector
              productsAsync.when(
                data: (products) {
                  final isValidProd = _selectedProductId != null &&
                      products.any((p) => p.productId == _selectedProductId);

                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: isValidProd ? _selectedProductId : null,
                    decoration: const InputDecoration(labelText: 'Select Product to Stock In'),
                    items: products.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.productId,
                        child: Text(
                          '${p.productName} (${p.productCode} • ${p.availableQuantity} ${p.unit} in stock)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedProductId = val;
                        final prod = products.where((p) => p.productId == val).firstOrNull;
                        if (prod != null) {
                          _unitPriceCtrl.text = prod.vendorPricePerUnit.toString();
                          _qtyCtrl.text = prod.isOil ? '250' : '20';
                          if (prod.vendorId.isNotEmpty) {
                            _selectedVendorId = prod.vendorId;
                          }
                        }
                      });
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error loading products'),
              ),
              const SizedBox(height: 12),

              // Vendor Selector
              vendorsAsync.when(
                data: (vendors) {
                  final isValidVendor = _selectedVendorId != null &&
                      vendors.any((v) => v.vendorId == _selectedVendorId);

                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: isValidVendor ? _selectedVendorId : null,
                    decoration: const InputDecoration(labelText: 'Supplier / Vendor'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Direct / No Vendor Specified', overflow: TextOverflow.ellipsis),
                      ),
                      ...vendors.map((v) {
                        return DropdownMenuItem<String>(
                          value: v.vendorId,
                          child: Text('${v.vendorName} (${v.companyName})', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedVendorId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Error loading vendors'),
              ),
              const SizedBox(height: 12),

              // Quantity & Unit Price
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantity to Procure',
                        suffixText: selectedProduct?.unit ?? 'units',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Unit Purchase Cost',
                        prefixText: '${AppConstants.currencySymbol} ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Total Cost Calculation Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Procurement Amount:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(
                      CurrencyFormatter.format(totalCost),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.emerald),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Payment Method
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Payment Allocation'),
                items: const [
                  DropdownMenuItem(
                    value: AppConstants.paymentOnline,
                    child: Text('Bank Transfer / UPI (Auto-debits Accounts)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.paymentCash,
                    child: Text('Cash Till (Auto-debits Cash in Hand)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'CREDIT',
                    child: Text('Credit (Accounts Payable / No Till Outflow)', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMethod = val);
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Invoice / Batch Notes (e.g. Batch #2026-NOV)',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald, foregroundColor: Colors.white),
          onPressed: (_isSubmitting || selectedProduct == null || qty <= 0 || unitPrice < 0)
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    await ref.read(shopRepositoryProvider).recordStockPurchase(
                          vendorId: selectedVendor?.vendorId ?? 'direct_purchase',
                          vendorName: selectedVendor?.vendorName ?? 'Direct Purchase',
                          productId: selectedProduct.productId,
                          productName: selectedProduct.productName,
                          productType: selectedProduct.productType,
                          quantity: qty,
                          unit: selectedProduct.unit,
                          unitPrice: unitPrice,
                          totalAmount: totalCost,
                          paymentMethod: _paymentMethod,
                          notes: _notesCtrl.text.trim(),
                          user: user,
                        );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully stocked in $qty ${selectedProduct.unit} of ${selectedProduct.productName}.'),
                          backgroundColor: AppColors.emerald,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.ruby),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isSubmitting = false);
                  }
                },
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Stock In'),
        ),
      ],
    );
  }
}
