import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/shop_providers.dart';

class StockSoldScreen extends ConsumerStatefulWidget {
  const StockSoldScreen({super.key});

  @override
  ConsumerState<StockSoldScreen> createState() => _StockSoldScreenState();
}

class _StockSoldScreenState extends ConsumerState<StockSoldScreen> {
  String _typeFilter = 'ALL'; // ALL, OIL, NON_OIL
  String _dateFilter = 'ALL'; // ALL, TODAY, THIS_MONTH
  String _sortBy = 'REVENUE'; // REVENUE, VOLUME, PROFIT, MARGIN
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showProductVelocityDialog(_ProductSoldAggregation item, ProductModel? inventoryProduct) {
    final available = inventoryProduct?.availableQuantity ?? 0.0;
    final dailyRunRate = item.totalQuantity / 30.0; // approximate monthly velocity
    final daysToStockout = dailyRunRate > 0 ? (available / dailyRunRate).round() : 999;

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
                child: const Icon(Icons.insights_rounded, color: AppColors.primaryGold, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Text('Category Performance & Velocity Intelligence', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top velocity metrics
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
                            const Text('Total Sold Volume:', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text('${item.totalQuantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Current In-Stock:', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$available ${item.unit}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: available <= 0 ? AppColors.ruby : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Gross Profit Margin:', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text('${item.marginPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.emerald), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Commercial Markup %:', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text('${item.markupPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.cashColor), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Projected stockout banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: daysToStockout < 7 ? AppColors.rubyLight : AppColors.emeraldLight,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          daysToStockout < 7 ? Icons.warning_rounded : Icons.check_circle_outline_rounded,
                          color: daysToStockout < 7 ? AppColors.ruby : AppColors.emerald,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            daysToStockout < 7
                                ? 'Stockout Alert: Projected to run out in ~$daysToStockout days based on sales velocity. Re-order recommended.'
                                : 'Healthy Inventory Velocity: ~$daysToStockout days of supply remaining at current demand.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: daysToStockout < 7 ? AppColors.ruby : AppColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesStreamProvider);
    final products = ref.watch(productsStreamProvider).valueOrNull ?? [];
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final currentMonthStr = todayStr.substring(0, 7);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
        error: (err, _) => Center(child: Text('Error loading sales: $err')),
        data: (sales) {
          var activeSales = sales.where((s) => !s.isVoided).toList();

          if (_dateFilter == 'TODAY') {
            activeSales = activeSales.where((s) => s.date == todayStr).toList();
          } else if (_dateFilter == 'THIS_MONTH') {
            activeSales = activeSales.where((s) => s.date.startsWith(currentMonthStr)).toList();
          }

          // Aggregate by Product in-memory (0 Firestore reads!)
          final Map<String, _ProductSoldAggregation> aggregations = {};

          for (final sale in activeSales) {
            for (final item in sale.items) {
              if (_typeFilter != 'ALL' && item.productType != _typeFilter) continue;

              final current = aggregations[item.productId] ??
                  _ProductSoldAggregation(
                    productId: item.productId,
                    productName: item.productName,
                    productType: item.productType,
                    unit: item.unit,
                  );

              aggregations[item.productId] = current.add(
                quantity: item.quantity,
                revenue: item.totalPrice,
                cost: item.quantity * item.unitCostAtSale,
              );
            }
          }

          final search = _searchCtrl.text.trim().toLowerCase();
          var aggregatedList = aggregations.values.where((item) {
            return search.isEmpty || item.productName.toLowerCase().contains(search);
          }).toList();

          // Apply dynamic sorting
          if (_sortBy == 'REVENUE') {
            aggregatedList.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
          } else if (_sortBy == 'VOLUME') {
            aggregatedList.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
          } else if (_sortBy == 'PROFIT') {
            aggregatedList.sort((a, b) => b.grossProfit.compareTo(a.grossProfit));
          } else if (_sortBy == 'MARGIN') {
            aggregatedList.sort((a, b) => b.marginPercentage.compareTo(a.marginPercentage));
          }

          final totalRevenue = aggregatedList.fold(0.0, (sum, a) => sum + a.totalRevenue);
          final totalCost = aggregatedList.fold(0.0, (sum, a) => sum + a.totalCost);
          final totalEstimatedProfit = totalRevenue - totalCost;
          final overallMargin = totalRevenue > 0 ? (totalEstimatedProfit / totalRevenue) * 100 : 0.0;
          final topSeller = aggregatedList.isNotEmpty ? aggregatedList.first.productName : 'None';

          final isMobile = MediaQuery.of(context).size.width < 600;
          final screenPadding = isMobile ? const EdgeInsets.all(16) : const EdgeInsets.all(24);

          return SingleChildScrollView(
            padding: screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Sold & Merchandise Intelligence', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('Derived in-memory product velocity, Cost of Goods Sold (COGS), gross margins & markup %', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 20),

                // Responsive KPI Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double cardWidth;
                    if (constraints.maxWidth < 460) {
                      cardWidth = constraints.maxWidth < 320 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
                    } else if (constraints.maxWidth < 750) {
                      cardWidth = (constraints.maxWidth - 24) / 3;
                    } else {
                      cardWidth = 210.0;
                    }

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildKpiCard('Total Merchandise Revenue', CurrencyFormatter.format(totalRevenue), Icons.monetization_on_outlined, AppColors.emerald, width: cardWidth),
                        _buildKpiCard('Total COGS (Cost)', CurrencyFormatter.format(totalCost), Icons.inventory_2_outlined, AppColors.textSecondary, width: cardWidth),
                        _buildKpiCard('Gross Realized Profit', CurrencyFormatter.format(totalEstimatedProfit), Icons.trending_up_rounded, AppColors.goldDark, width: cardWidth),
                        _buildKpiCard('Average Gross Margin', '${overallMargin.toStringAsFixed(1)}%', Icons.percent_rounded, AppColors.cashColor, width: cardWidth),
                        _buildKpiCard('Top Selling Perfume', topSeller, Icons.star_outline_rounded, AppColors.primaryGold, width: cardWidth),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Filter & Sort Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search sold merchandise by perfume name...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryGold),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Category: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ChoiceChip(
                              label: const Text('All Products'),
                              selected: _typeFilter == 'ALL',
                              onSelected: (_) => setState(() => _typeFilter = 'ALL'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Pure Oils / Athar (ml)'),
                              avatar: const Icon(Icons.water_drop_rounded, size: 14, color: AppColors.oilTagText),
                              selected: _typeFilter == AppConstants.typeOil,
                              selectedColor: AppColors.oilTagBg,
                              onSelected: (_) => setState(() => _typeFilter = AppConstants.typeOil),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Non-Oil Sprays & Bottles (Pcs)'),
                              avatar: const Icon(Icons.category_rounded, size: 14, color: AppColors.nonOilTagText),
                              selected: _typeFilter == AppConstants.typeNonOil,
                              selectedColor: AppColors.nonOilTagBg,
                              onSelected: (_) => setState(() => _typeFilter = AppConstants.typeNonOil),
                            ),
                            const SizedBox(width: 16),
                            Container(height: 24, width: 1, color: AppColors.border),
                            const SizedBox(width: 16),
                            const Text('Period: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ChoiceChip(
                              label: const Text('All Time'),
                              selected: _dateFilter == 'ALL',
                              onSelected: (_) => setState(() => _dateFilter = 'ALL'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Today'),
                              selected: _dateFilter == 'TODAY',
                              onSelected: (_) => setState(() => _dateFilter = 'TODAY'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('This Month'),
                              selected: _dateFilter == 'THIS_MONTH',
                              onSelected: (_) => setState(() => _dateFilter = 'THIS_MONTH'),
                            ),
                            const SizedBox(width: 16),
                            Container(height: 24, width: 1, color: AppColors.border),
                            const SizedBox(width: 16),
                            const Text('Sort By: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            DropdownButton<String>(
                              value: _sortBy,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 'REVENUE', child: Text('Highest Revenue', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'VOLUME', child: Text('Highest Volume Sold', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'PROFIT', child: Text('Highest Gross Profit', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'MARGIN', child: Text('Highest Margin %', style: TextStyle(fontSize: 13))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _sortBy = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Table
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: aggregatedList.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No sold merchandise recorded for the selected period.', style: TextStyle(color: AppColors.textSecondary))),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('Product Name', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Sold Volume', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Orders', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Gross Revenue', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('COGS (Cost)', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Gross Profit', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Margin %', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Markup %', style: TextStyle(fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Intelligence', style: TextStyle(fontWeight: FontWeight.w700))),
                            ],
                            rows: aggregatedList.map((item) {
                              final prod = products.where((p) => p.productId == item.productId).firstOrNull;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: item.productType == AppConstants.typeOil ? AppColors.oilTagBg : AppColors.nonOilTagBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.productType,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: item.productType == AppConstants.typeOil ? AppColors.oilTagText : AppColors.nonOilTagText,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${item.totalQuantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                  DataCell(Text('${item.transactionCount} sales')),
                                  DataCell(Text(CurrencyFormatter.format(item.totalRevenue), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.emerald))),
                                  DataCell(Text(CurrencyFormatter.format(item.totalCost))),
                                  DataCell(Text(CurrencyFormatter.format(item.grossProfit), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.goldDark))),
                                  DataCell(
                                    Text(
                                      '${item.marginPercentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.emerald),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${item.markupPercentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Product Velocity & Stockout Risk',
                                      icon: const Icon(Icons.analytics_outlined, size: 18, color: AppColors.primaryGold),
                                      onPressed: () => _showProductVelocityDialog(item, prod),
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

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, {double? width}) {
    return Container(
      width: width ?? 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProductSoldAggregation {
  final String productId;
  final String productName;
  final String productType;
  final String unit;
  final double totalQuantity;
  final double totalRevenue;
  final double totalCost;
  final int transactionCount;

  _ProductSoldAggregation({
    required this.productId,
    required this.productName,
    required this.productType,
    required this.unit,
    this.totalQuantity = 0.0,
    this.totalRevenue = 0.0,
    this.totalCost = 0.0,
    this.transactionCount = 0,
  });

  double get grossProfit => totalRevenue - totalCost;
  double get marginPercentage => totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;
  double get markupPercentage => totalCost > 0 ? (grossProfit / totalCost) * 100 : 0.0;

  _ProductSoldAggregation add({
    required double quantity,
    required double revenue,
    required double cost,
  }) {
    return _ProductSoldAggregation(
      productId: productId,
      productName: productName,
      productType: productType,
      unit: unit,
      totalQuantity: totalQuantity + quantity,
      totalRevenue: totalRevenue + revenue,
      totalCost: totalCost + cost,
      transactionCount: transactionCount + 1,
    );
  }
}
