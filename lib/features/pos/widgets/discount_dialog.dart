import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/shop_providers.dart';

class DiscountDialog extends ConsumerStatefulWidget {
  const DiscountDialog({super.key});

  @override
  ConsumerState<DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends ConsumerState<DiscountDialog> {
  String _discountType = 'FLAT'; // 'FLAT' or 'PERCENT'
  final TextEditingController _valueCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _discountType = cart.discountType;
    if (cart.discountValue > 0) {
      _valueCtrl.text = cart.discountValue.toString();
    }
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final val = double.tryParse(_valueCtrl.text) ?? 0.0;
    double calculatedDiscount;
    if (_discountType == 'PERCENT') {
      calculatedDiscount = (cart.subtotal * (val / 100.0)).clamp(0.0, cart.subtotal);
    } else {
      calculatedDiscount = val.clamp(0.0, cart.subtotal);
    }
    final newGrandTotal = (cart.subtotal - calculatedDiscount).clamp(0.0, double.infinity);

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
            child: const Icon(Icons.discount_outlined, color: AppColors.primaryGold, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apply Cart Discount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Special offer, seasonal promotion or customer loyalty', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'FLAT', label: Text('Flat Rupee (₹)')),
                ButtonSegment(value: 'PERCENT', label: Text('Percentage (%)')),
              ],
              selected: {_discountType},
              onSelectionChanged: (val) {
                setState(() => _discountType = val.first);
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _valueCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _discountType == 'PERCENT' ? 'Discount Percentage (%)' : 'Discount Amount (₹)',
                prefixText: _discountType == 'FLAT' ? '${AppConstants.currencySymbol} ' : null,
                suffixText: _discountType == 'PERCENT' ? '%' : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Quick preset chips
            Wrap(
              spacing: 8,
              children: (_discountType == 'PERCENT' ? [5, 10, 15, 20] : [20, 50, 100, 200]).map((presetVal) {
                return ActionChip(
                  label: Text(_discountType == 'PERCENT' ? '$presetVal%' : '₹$presetVal'),
                  onPressed: () {
                    _valueCtrl.text = presetVal.toString();
                    setState(() {});
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Subtotal:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.format(cart.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount Reduction:', style: TextStyle(fontSize: 12, color: AppColors.ruby)),
                      Text('-${CurrencyFormatter.format(calculatedDiscount)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ruby)),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('New Grand Total:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text(CurrencyFormatter.format(newGrandTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.emerald)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (cart.discountAmount > 0)
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).setDiscount(0.0);
              Navigator.pop(context);
            },
            child: const Text('Remove Discount', style: TextStyle(color: AppColors.ruby)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(cartProvider.notifier).setDiscount(val, type: _discountType);
            Navigator.pop(context);
          },
          child: const Text('Apply Discount'),
        ),
      ],
    );
  }
}

