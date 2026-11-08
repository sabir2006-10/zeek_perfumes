import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/shop_providers.dart';

class EditProductDialog extends ConsumerStatefulWidget {
  final ProductModel product;

  const EditProductDialog({super.key, required this.product});

  @override
  ConsumerState<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<EditProductDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _sellCtrl;
  late final TextEditingController _thresholdCtrl;
  String? _selectedVendorId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.productName);
    _codeCtrl = TextEditingController(text: widget.product.productCode);
    _categoryCtrl = TextEditingController(text: widget.product.category);
    _costCtrl = TextEditingController(text: widget.product.vendorPricePerUnit.toString());
    _sellCtrl = TextEditingController(text: widget.product.sellingPricePerUnit.toString());
    _thresholdCtrl = TextEditingController(text: widget.product.lowStockThreshold.toString());
    _selectedVendorId = widget.product.vendorId.isEmpty ? null : widget.product.vendorId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _categoryCtrl.dispose();
    _costCtrl.dispose();
    _sellCtrl.dispose();
    _thresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsStreamProvider);
    final cost = double.tryParse(_costCtrl.text) ?? 0.0;
    final sell = double.tryParse(_sellCtrl.text) ?? 0.0;
    final margin = sell - cost;
    final marginPercent = sell > 0 ? (margin / sell) * 100 : 0.0;

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
            child: const Icon(Icons.edit_note_rounded, color: AppColors.primaryGold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Product & Pricing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(
                  'SKU: ${widget.product.productCode} • ${widget.product.unit}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(labelText: 'SKU / Code'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _categoryCtrl,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              vendorsAsync.when(
                data: (vendors) {
                  final isValidVendor = _selectedVendorId != null &&
                      vendors.any((v) => v.vendorId == _selectedVendorId);
                  return DropdownButtonFormField<String>(
                    value: isValidVendor ? _selectedVendorId : null,
                    decoration: const InputDecoration(labelText: 'Primary Supplier / Vendor'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No Supplier Assigned'),
                      ),
                      ...vendors.map((v) {
                        return DropdownMenuItem<String>(
                          value: v.vendorId,
                          child: Text('${v.vendorName} (${v.companyName})'),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedVendorId = val),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              const Text('Pricing & Margin Structure', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _costCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cost Price (${AppConstants.currencySymbol}/${widget.product.unit})',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _sellCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Selling Price (${AppConstants.currencySymbol}/${widget.product.unit})',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: margin >= 0 ? AppColors.emeraldLight : AppColors.rubyLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Unit Margin: ${CurrencyFormatter.format(margin)} / ${widget.product.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: margin >= 0 ? AppColors.emerald : AppColors.ruby,
                      ),
                    ),
                    Text(
                      'Markup: ${marginPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: margin >= 0 ? AppColors.emerald : AppColors.ruby,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _thresholdCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Low Stock Alert Threshold (${widget.product.unit})',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (_nameCtrl.text.trim().isEmpty) return;
                  setState(() => _isSaving = true);
                  try {
                    final updated = widget.product.copyWith(
                      productName: _nameCtrl.text.trim(),
                      normalizedName: _nameCtrl.text.trim().toLowerCase(),
                      productCode: _codeCtrl.text.trim(),
                      category: _categoryCtrl.text.trim(),
                      vendorId: _selectedVendorId ?? '',
                      vendorPricePerUnit: double.tryParse(_costCtrl.text) ?? widget.product.vendorPricePerUnit,
                      sellingPricePerUnit: double.tryParse(_sellCtrl.text) ?? widget.product.sellingPricePerUnit,
                      lowStockThreshold: double.tryParse(_thresholdCtrl.text) ?? widget.product.lowStockThreshold,
                      updatedAt: DateTime.now(),
                    );
                    await ref.read(shopRepositoryProvider).updateProduct(updated);
                    if (mounted) Navigator.pop(context);
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

