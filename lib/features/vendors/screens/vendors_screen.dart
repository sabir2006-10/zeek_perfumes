import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/vendor_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../inventory/widgets/stock_purchase_dialog.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddOrEditVendorDialog({VendorModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.vendorName ?? '');
    final companyCtrl = TextEditingController(text: existing?.companyName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phoneNumber ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? 'Register New Perfume Supplier / Vendor' : 'Edit Vendor Details',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Contact Person / Representative')),
                  const SizedBox(height: 12),
                  TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Company / Business Name (e.g. Ajmal Essence Co.)')),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number / WhatsApp')),
                  const SizedBox(height: 12),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'City / Office Address')),
                  const SizedBox(height: 12),
                  TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Procurement Terms / Notes')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;

                if (existing == null) {
                  final newVendor = VendorModel(
                    vendorId: '',
                    vendorName: nameCtrl.text.trim(),
                    companyName: companyCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    status: 'ACTIVE',
                    createdAt: DateTime.now(),
                  );
                  await ref.read(shopRepositoryProvider).addVendor(newVendor);
                } else {
                  final updated = VendorModel(
                    vendorId: existing.vendorId,
                    vendorName: nameCtrl.text.trim(),
                    companyName: companyCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    status: existing.status,
                    createdAt: existing.createdAt,
                  );
                  await ref.read(shopRepositoryProvider).updateVendor(updated);
                }

                if (mounted) Navigator.pop(ctx);
              },
              child: Text(existing == null ? 'Register Vendor' : 'Save Changes'),
            ),
          ],
        );
      },
    );
  }

  void _showVendorDetails(VendorModel vendor) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final suppliedProducts = ref.watch(vendorProductsProvider(vendor.vendorId));

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
                    child: const Icon(Icons.business_rounded, color: AppColors.primaryGold, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendor.companyName.isNotEmpty ? vendor.companyName : vendor.vendorName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('Contact: ${vendor.vendorName} • ${vendor.phoneNumber}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 550,
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
                            Text('Address: ${vendor.address.isNotEmpty ? vendor.address : "Not specified"}',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Procurement Notes: ${vendor.notes.isNotEmpty ? vendor.notes : "Standard terms"}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Products Supplied (${suppliedProducts.length} Catalog Items):',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),

                      if (suppliedProducts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No products currently mapped to this vendor.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        )
                      else
                        ...suppliedProducts.map((p) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('${p.productName} (${p.productCode})',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                                Text(
                                  'Stock: ${p.availableQuantity} ${p.unit}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text('Stock In from this Vendor'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => const StockPurchaseDialog(),
                    );
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsStreamProvider);
    final user = ref.watch(authProvider).currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: vendorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (vendors) {
          final query = _searchCtrl.text.trim().toLowerCase();
          final filtered = vendors.where((v) {
            return query.isEmpty ||
                v.vendorName.toLowerCase().contains(query) ||
                v.companyName.toLowerCase().contains(query);
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vendor & Supplier Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('Manage wholesale perfume suppliers, contact details and procurement sources',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    if (user?.isAdmin ?? false)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_business_rounded),
                        label: const Text('Add New Supplier'),
                        onPressed: () => _showAddOrEditVendorDialog(),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search vendors by company name, contact...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primaryGold),
                  ),
                ),
                const SizedBox(height: 16),

                // Vendors Table
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
                        DataColumn(label: Text('Company / Business', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Representative', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Phone / WhatsApp', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Office Location', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                      rows: filtered.map((v) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                v.companyName.isNotEmpty ? v.companyName : v.vendorName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                            DataCell(Text(v.vendorName)),
                            DataCell(Text(v.phoneNumber)),
                            DataCell(Text(v.address)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: v.status == 'ACTIVE' ? AppColors.emeraldLight : AppColors.rubyLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  v.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: v.status == 'ACTIVE' ? AppColors.emerald : AppColors.ruby,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'View Supplied Products',
                                    icon: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primaryGold),
                                    onPressed: () => _showVendorDetails(v),
                                  ),
                                  if (user?.isAdmin ?? false) ...[
                                    IconButton(
                                      tooltip: 'Edit Vendor Details',
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.cashColor),
                                      onPressed: () => _showAddOrEditVendorDialog(existing: v),
                                    ),
                                    IconButton(
                                      tooltip: 'Archive Vendor',
                                      icon: const Icon(Icons.archive_outlined, size: 18, color: AppColors.ruby),
                                      onPressed: () async {
                                        await ref.read(shopRepositoryProvider).archiveVendor(v.vendorId);
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
}

