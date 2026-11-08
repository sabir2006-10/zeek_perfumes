import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/daily_summary_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../authentication/providers/auth_provider.dart';

class DayEndCloseDialog extends ConsumerStatefulWidget {
  final double expectedCash;
  final double currentBankBalance;
  final String date;
  final DailySummaryModel? todaySummary;

  const DayEndCloseDialog({
    super.key,
    required this.expectedCash,
    required this.currentBankBalance,
    required this.date,
    this.todaySummary,
  });

  @override
  ConsumerState<DayEndCloseDialog> createState() => _DayEndCloseDialogState();
}

class _DayEndCloseDialogState extends ConsumerState<DayEndCloseDialog> {
  final TextEditingController _physicalCashCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default actual cash to expected cash
    _physicalCashCtrl.text = widget.expectedCash.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _physicalCashCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final physicalCash = double.tryParse(_physicalCashCtrl.text) ?? 0.0;
    final discrepancy = physicalCash - widget.expectedCash;
    final isExact = discrepancy.abs() < 0.01;
    final isShort = discrepancy < -0.01;

    final user = ref.watch(authProvider).currentUser?.displayName ?? 'Admin';

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
            child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primaryGold, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Day-End Cash Reconciliation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Date: ${widget.date} • Cashier: $user', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Count physical currency notes and coins currently in the shop cash drawer.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),

              // Ledger Expected Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Expected Cash in Till:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          CurrencyFormatter.format(widget.expectedCash),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.cashColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Closing Bank Balance:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        Text(
                          CurrencyFormatter.format(widget.currentBankBalance),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onlineColor),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Formula:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const Text(
                          'Opening + Cash Sales - Expenses - Bank Deposits',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Actual Cash Input
              TextField(
                controller: _physicalCashCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Physical Cash Counted in Till (₹)',
                  prefixText: '₹ ',
                  helperText: 'Enter total rupees counted in the physical cash drawer',
                  suffixIcon: IconButton(
                    tooltip: 'Set to expected cash',
                    icon: const Icon(Icons.auto_fix_high_rounded, color: AppColors.primaryGold, size: 20),
                    onPressed: () {
                      _physicalCashCtrl.text = widget.expectedCash.toStringAsFixed(0);
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Live Discrepancy Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isExact
                      ? AppColors.emeraldLight
                      : isShort
                          ? AppColors.rubyLight
                          : Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isExact
                        ? AppColors.emerald.withOpacity(0.3)
                        : isShort
                            ? AppColors.ruby.withOpacity(0.3)
                            : Colors.amber.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExact
                          ? Icons.check_circle_rounded
                          : isShort
                              ? Icons.warning_rounded
                              : Icons.info_outline_rounded,
                      size: 20,
                      color: isExact
                          ? AppColors.emerald
                          : isShort
                              ? AppColors.ruby
                              : Colors.amber[800],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isExact
                                ? 'Cash Drawer Reconciled: Perfect Match'
                                : isShort
                                    ? 'Cash Shortage: ${CurrencyFormatter.format(discrepancy.abs())}'
                                    : 'Cash Surplus: +${CurrencyFormatter.format(discrepancy)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isExact
                                  ? AppColors.emerald
                                  : isShort
                                      ? AppColors.ruby
                                      : Colors.amber[900],
                            ),
                          ),
                          Text(
                            isExact
                                ? 'Physical drawer matches the ledger exactly.'
                                : isShort
                                    ? 'Physical cash is less than ledger. A negative adjustment will be logged.'
                                    : 'Physical cash exceeds ledger. A surplus entry will be logged.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Closing Notes / Discrepancy Explanation (Optional)',
                  hintText: 'e.g. End of day reconciliation by shift lead. All bills verified.',
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
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  try {
                    await ref.read(shopRepositoryProvider).reconcileAndCloseDay(
                          date: widget.date,
                          actualPhysicalCash: physicalCash,
                          user: user,
                          notes: _notesCtrl.text.trim().isEmpty ? 'Day-end cash closing verified' : _notesCtrl.text.trim(),
                        );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✓ Day ${widget.date} books successfully closed and locked.'),
                          backgroundColor: AppColors.emerald,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error closing day: $e'), backgroundColor: AppColors.ruby),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Confirm & Lock Day Closing'),
        ),
      ],
    );
  }
}

