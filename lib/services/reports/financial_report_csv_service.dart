import 'dart:convert';
import 'package:csv/csv.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/account_entry_model.dart';
import '../../data/models/sale_model.dart';
import '../file_saver/file_saver.dart';

class FinancialReportCsvService {
  FinancialReportCsvService._();

  /// Builds the complete formatted CSV string with metadata, P&L summary, sales log, and expenses log
  static String buildCsvContent({
    required List<SaleModel> sales,
    required List<AccountEntryModel> entries,
    required String periodLabel,
  }) {
    final activeSales = sales.where((s) => !s.isVoided).toList();

    // Summary calculations
    final totalRevenue = activeSales.fold(0.0, (sum, s) => sum + s.grandTotal);
    final totalCashSales = activeSales.fold(0.0, (sum, s) => sum + s.cashAmount);
    final totalOnlineSales = activeSales.fold(0.0, (sum, s) => sum + s.onlineAmount);

    final totalCOGS = activeSales.fold(
      0.0,
      (sum, s) => sum + s.items.fold(0.0, (iSum, item) => iSum + (item.quantity * item.unitCostAtSale)),
    );

    final grossProfit = totalRevenue - totalCOGS;
    final overallMargin = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100 : 0.0;

    final expenseEntries = entries.where((e) => e.transactionType == AppConstants.accountExpense).toList();
    final operatingExpenses = expenseEntries.fold(
      0.0,
      (sum, e) => sum + (e.cashAmount.abs() + e.onlineAmount.abs()),
    );

    final netOperatingResult = grossProfit - operatingExpenses;

    final List<List<dynamic>> rows = [];

    // 1. Executive Metadata & P&L Summary Block
    rows.add(['ZEEK PERFUMES & ATHAR - FINANCIAL & SALES INTELLIGENCE REPORT']);
    rows.add(['Generated On', DateTime.now().toIso8601String()]);
    rows.add(['Period', periodLabel]);
    rows.add([]);
    rows.add(['FINANCIAL EXECUTIVE SUMMARY']);
    rows.add(['Total Completed Sales', activeSales.length]);
    rows.add(['Gross Sales Revenue (INR)', totalRevenue.toStringAsFixed(2)]);
    rows.add(['Cost of Goods Sold (COGS) (INR)', totalCOGS.toStringAsFixed(2)]);
    rows.add(['Gross Realized Profit (INR)', grossProfit.toStringAsFixed(2)]);
    rows.add(['Average Gross Margin %', '${overallMargin.toStringAsFixed(1)}%']);
    rows.add(['Total Cash Collections (INR)', totalCashSales.toStringAsFixed(2)]);
    rows.add(['Total Online/UPI Collections (INR)', totalOnlineSales.toStringAsFixed(2)]);
    rows.add(['Total Operating Expenses (INR)', operatingExpenses.toStringAsFixed(2)]);
    rows.add(['Net Business Profit / Result (INR)', netOperatingResult.toStringAsFixed(2)]);
    rows.add([]);

    // 2. Itemized Sales Transactions Table
    rows.add(['SALES TRANSACTIONS LOG']);
    rows.add([
      'Invoice #',
      'Date',
      'Time',
      'Cashier',
      'Customer Name',
      'Customer Phone',
      'Payment Method',
      'Items Purchased',
      'Total Items Qty',
      'Subtotal (INR)',
      'Discount (INR)',
      'Grand Total (INR)',
      'Cash Paid (INR)',
      'Online Paid (INR)',
      'COGS Cost (INR)',
      'Gross Profit (INR)',
      'Status',
    ]);

    for (final sale in sales) {
      final itemsSummary = sale.items.map((i) => '${i.productName} (${i.quantity} ${i.unit})').join('; ');
      final totalQty = sale.items.fold(0.0, (qSum, i) => qSum + i.quantity);
      final saleCOGS = sale.items.fold(0.0, (cSum, i) => cSum + (i.quantity * i.unitCostAtSale));
      final saleGrossProfit = sale.isVoided ? 0.0 : (sale.grandTotal - saleCOGS);

      rows.add([
        sale.invoiceNumber,
        sale.date,
        DateFormatter.formatTime(sale.timestamp),
        sale.createdBy,
        sale.customerName ?? 'Walk-in Customer',
        sale.customerPhone ?? '-',
        sale.paymentType,
        itemsSummary,
        totalQty,
        sale.subtotal.toStringAsFixed(2),
        sale.discount.toStringAsFixed(2),
        sale.grandTotal.toStringAsFixed(2),
        sale.cashAmount.toStringAsFixed(2),
        sale.onlineAmount.toStringAsFixed(2),
        saleCOGS.toStringAsFixed(2),
        saleGrossProfit.toStringAsFixed(2),
        sale.status,
      ]);
    }

    rows.add([]);

    // 3. Operating Expenses Table
    rows.add(['STORE OPERATING EXPENSES LOG']);
    rows.add([
      'Date',
      'Description',
      'Cash Amount (INR)',
      'Online Amount (INR)',
      'Total Expense (INR)',
      'Recorded By',
      'Status',
    ]);

    for (final exp in expenseEntries) {
      rows.add([
        exp.date,
        exp.description,
        exp.cashAmount.abs().toStringAsFixed(2),
        exp.onlineAmount.abs().toStringAsFixed(2),
        exp.totalAmount.abs().toStringAsFixed(2),
        exp.createdBy,
        exp.status,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generates and triggers the download/sharing of a comprehensive financial CSV report
  static Future<bool> exportReport({
    required List<SaleModel> sales,
    required List<AccountEntryModel> entries,
    required String periodLabel,
    required String fileName,
  }) async {
    final csvString = buildCsvContent(
      sales: sales,
      entries: entries,
      periodLabel: periodLabel,
    );

    // Prepend UTF-8 BOM (\uFEFF) for Microsoft Excel compatibility
    final utf8BomBytes = [0xEF, 0xBB, 0xBF];
    final csvBytes = utf8.encode(csvString);
    final fullBytes = [...utf8BomBytes, ...csvBytes];

    return await saveOrDownloadFile(
      bytes: fullBytes,
      fileName: fileName,
      mimeType: 'text/csv;charset=utf-8',
    );
  }
}
