import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/shop_providers.dart';
import '../../../services/csv/csv_inventory_service.dart';

class CsvImportDialog extends ConsumerStatefulWidget {
  const CsvImportDialog({super.key});

  @override
  ConsumerState<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends ConsumerState<CsvImportDialog> {
  final TextEditingController _csvTextController = TextEditingController();
  CsvImportResult? _validationResult;
  bool _isImporting = false;

  void _validateInput(Map<String, ProductModel> existingByCode) {
    final text = _csvTextController.text.trim();
    if (text.isEmpty) {
      setState(() => _validationResult = null);
      return;
    }

    final result = CsvInventoryService.parseAndValidateCsv(
      csvContent: text,
      existingProductsByCode: existingByCode,
    );

    setState(() => _validationResult = result);
  }

  void _loadSampleCsv() {
    _csvTextController.text = CsvInventoryService.generateTemplateCsv();
    final allProducts = ref.read(productsStreamProvider).valueOrNull ?? [];
    final map = {for (var p in allProducts) p.productCode.toUpperCase(): p};
    _validateInput(map);
  }

  @override
  void dispose() {
    _csvTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsStreamProvider).valueOrNull ?? [];
    final existingByCode = {for (var p in products) p.productCode.toUpperCase(): p};

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
            child: const Icon(Icons.upload_file_rounded, color: AppColors.primaryGold, size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bulk Product CSV Import', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('Upload catalog, validate SKUs, and batch-insert with zero redundant reads', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 750,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Load Sample Template'),
                    onPressed: _loadSampleCsv,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Headers: Code, Name, Category, Type, Unit, Stock, Cost, Sell, Alert, VendorId',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // CSV Text Input / Paste area
              TextField(
                controller: _csvTextController,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Paste CSV rows here or load sample template above...',
                  suffixIcon: IconButton(
                    tooltip: 'Validate Content',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => _validateInput(existingByCode),
                  ),
                ),
                onChanged: (_) => _validateInput(existingByCode),
              ),
              const SizedBox(height: 16),

              // Validation Summary Cards
              if (_validationResult != null) ...[
                Row(
                  children: [
                    _buildCountBadge('Ready to Import', _validationResult!.validCount, AppColors.emerald),
                    const SizedBox(width: 10),
                    _buildCountBadge('Existing SKUs (Duplicates)', _validationResult!.duplicateCount, Colors.orange[800]!),
                    const SizedBox(width: 10),
                    _buildCountBadge('Invalid Rows', _validationResult!.errorCount, AppColors.ruby),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Validation Preview Table:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 36,
                      dataRowMinHeight: 40,
                      columns: const [
                        DataColumn(label: Text('Row #')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Code / SKU')),
                        DataColumn(label: Text('Product Name')),
                        DataColumn(label: Text('Type & Unit')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Cost')),
                        DataColumn(label: Text('Sell Price')),
                        DataColumn(label: Text('Notes / Error')),
                      ],
                      rows: _validationResult!.rows.map((row) {
                        Color statusColor;
                        String statusText;
                        if (row.isValid) {
                          statusColor = AppColors.emerald;
                          statusText = 'VALID';
                        } else if (row.isDuplicate) {
                          statusColor = Colors.orange[800]!;
                          statusText = 'EXISTS';
                        } else {
                          statusColor = AppColors.ruby;
                          statusText = 'ERROR';
                        }

                        return DataRow(
                          cells: [
                            DataCell(Text('${row.rowNumber}')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10)),
                              ),
                            ),
                            DataCell(Text(row.productCode, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text(row.productName)),
                            DataCell(Text('${row.productType} (${row.unit})')),
                            DataCell(Text('${row.availableQuantity}')),
                            DataCell(Text('₹${row.vendorPricePerUnit}')),
                            DataCell(Text('₹${row.sellingPricePerUnit}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(
                              Text(
                                row.errorMessage ?? 'Ready',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: row.errorMessage != null ? statusColor : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            foregroundColor: Colors.white,
          ),
          onPressed: (_isImporting || _validationResult == null || _validationResult!.validCount == 0)
              ? null
              : () async {
                  setState(() => _isImporting = true);
                  try {
                    final validRows = _validationResult!.rows.where((r) => r.isValid).toList();
                    final models = validRows.map((r) => r.toProductModel()).toList();

                    final count = await ref.read(shopRepositoryProvider).batchImportProducts(models);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Successfully imported $count products in batch!'),
                          backgroundColor: AppColors.emerald,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import error: $e'), backgroundColor: AppColors.ruby),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isImporting = false);
                  }
                },
          child: _isImporting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Commit Import (${_validationResult?.validCount ?? 0} Valid Products)'),
        ),
      ],
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          Text('$count', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

