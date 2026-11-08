import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/account_entry_model.dart';
import '../../data/models/sale_model.dart';
import '../file_saver/file_saver.dart';

class FinancialReportPdfService {
  FinancialReportPdfService._();

  static const String shopName = AppConstants.appName;
  static const String shopTagline = 'Pure Dehn Al Oud, Luxury Athar & Exclusive EDP Sprays';
  static const String shopAddress = 'Main Commercial Market, Surat / Mumbai Branch';
  static const String shopPhone = '+91 98765 43210';
  static const String shopGst = 'GSTIN: 27AAAAZ0000A1Z5';

  static String _formatCurrency(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final parts = absAmount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final buffer = StringBuffer();
    final len = integerPart.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
    }

    final formatted = 'Rs. ${buffer.toString()}.$decimalPart';
    return isNegative ? '-$formatted' : formatted;
  }

  /// Generates the raw PDF bytes for an A4 multi-page executive financial report
  static Future<Uint8List> generateReportBytes({
    required List<SaleModel> sales,
    required List<AccountEntryModel> entries,
    required String periodLabel,
    String generatedBy = 'Zeek (Owner)',
  }) async {
    final pdf = pw.Document();

    final activeSales = sales.where((s) => !s.isVoided).toList();
    final totalSalesCount = activeSales.length;

    // Financial calculations
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
    final totalExpenses = expenseEntries.fold(
      0.0,
      (sum, e) => sum + (e.cashAmount.abs() + e.onlineAmount.abs()),
    );

    final netOperatingResult = grossProfit - totalExpenses;

    final baseGold = PdfColor.fromHex('#D4AF37');
    final darkHeader = PdfColor.fromHex('#1E1E1E');
    final emeraldGreen = PdfColor.fromHex('#10B981');
    final rubyRed = PdfColor.fromHex('#EF4444');
    final softGrey = PdfColor.fromHex('#F3F4F6');
    final borderGrey = PdfColor.fromHex('#E5E7EB');
    final textMuted = PdfColor.fromHex('#6B7280');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ZEEK PERFUMES & ATHAR',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: darkHeader,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        shopTagline,
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                      pw.Text(
                        '$shopAddress | Ph: $shopPhone | $shopGst',
                        style: pw.TextStyle(fontSize: 7.5, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: softGrey,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: borderGrey, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('OFFICIAL FINANCIAL STATEMENT', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: baseGold)),
                        pw.Text('Report Period: $periodLabel', style: const pw.TextStyle(fontSize: 7.5)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: borderGrey),
              pw.SizedBox(height: 6),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.8, color: borderGrey),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated by Zeek Perfumes & Athar Management System | Confidential & Proprietary',
                    style: pw.TextStyle(fontSize: 7, color: textMuted),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Title & Generation Metadata
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: softGrey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: borderGrey),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'FINANCIAL INTELLIGENCE & EXECUTIVE PERFORMANCE REPORT',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkHeader),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Comprehensive Profit & Loss, Wholesale COGS, Operating Expenses & Cash/Bank Reconciliations',
                        style: pw.TextStyle(fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Date: ${DateFormatter.formatDateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Operator: $generatedBy', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 1. Executive Performance KPI Cards
            pw.Row(
              children: [
                _buildPdfKpiCard('Gross Revenue', _formatCurrency(totalRevenue), '$totalSalesCount completed sales', emeraldGreen),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard('Cost of Goods (COGS)', _formatCurrency(totalCOGS), 'Wholesale product cost', darkHeader),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard('Gross Realized Profit', _formatCurrency(grossProfit), 'Margin: ${overallMargin.toStringAsFixed(1)}%', baseGold),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard('Operating Expenses', _formatCurrency(totalExpenses), 'Rent, utilities & overheads', rubyRed),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard('Net Operating Result', _formatCurrency(netOperatingResult), 'Net shop profit', netOperatingResult >= 0 ? emeraldGreen : rubyRed),
              ],
            ),
            pw.SizedBox(height: 16),

            // 2. Dual Breakdown Section: Payment Channels & Financial Reconciliation
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Payment Channels Box
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: borderGrey),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Payment Channel Performance', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkHeader)),
                        pw.SizedBox(height: 2),
                        pw.Text('Cash in Register vs. Bank/UPI collections', style: pw.TextStyle(fontSize: 7.5, color: textMuted)),
                        pw.SizedBox(height: 10),
                        _buildPdfSummaryLine('Cash in Register (Till):', _formatCurrency(totalCashSales), '${totalRevenue > 0 ? ((totalCashSales / totalRevenue) * 100).toStringAsFixed(1) : "0.0"}% of total'),
                        pw.SizedBox(height: 6),
                        _buildPdfSummaryLine('Bank / Online UPI Transfer:', _formatCurrency(totalOnlineSales), '${totalRevenue > 0 ? ((totalOnlineSales / totalRevenue) * 100).toStringAsFixed(1) : "0.0"}% of total'),
                        pw.Divider(thickness: 0.5, color: borderGrey),
                        _buildPdfSummaryLine('Total Customer Inflow:', _formatCurrency(totalRevenue), '$totalSalesCount Invoices', isBold: true),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                // Reconciliation & Profit Structure Box
                pw.Expanded(
                  flex: 7,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: borderGrey),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Shop Reconciliation & Profit Structure', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkHeader)),
                        pw.SizedBox(height: 2),
                        pw.Text('Authoritative accounting waterfall for the selected period', style: pw.TextStyle(fontSize: 7.5, color: textMuted)),
                        pw.SizedBox(height: 10),
                        _buildPdfSummaryLine('Total Gross Customer Revenue:', _formatCurrency(totalRevenue), '+ Inflow'),
                        pw.SizedBox(height: 4),
                        _buildPdfSummaryLine('Less: Wholesale Cost of Goods Sold (COGS):', '-${_formatCurrency(totalCOGS)}', '- Outflow'),
                        pw.Divider(thickness: 0.5, color: borderGrey),
                        _buildPdfSummaryLine('Gross Operating Profit:', _formatCurrency(grossProfit), 'Markup: ${overallMargin.toStringAsFixed(1)}%', isBold: true),
                        pw.SizedBox(height: 4),
                        _buildPdfSummaryLine('Less: Store Rent, Utilities & Overheads:', '-${_formatCurrency(totalExpenses)}', '- Outflow'),
                        pw.Divider(thickness: 1, color: borderGrey),
                        _buildPdfSummaryLine(
                          'Net Business Result (After All Overheads):',
                          _formatCurrency(netOperatingResult),
                          netOperatingResult >= 0 ? 'NET PROFIT' : 'NET LOSS',
                          isBold: true,
                          highlightColor: netOperatingResult >= 0 ? emeraldGreen : rubyRed,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // 3. Operating Expenses Table
            pw.Text(
              'STORE OPERATING EXPENSES LOG',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkHeader),
            ),
            pw.SizedBox(height: 6),
            if (expenseEntries.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: softGrey,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Center(
                  child: pw.Text('No store operating expenses recorded for the selected period.', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: softGrey),
                    children: [
                      _buildTableHeaderCell('Date', flex: 2),
                      _buildTableHeaderCell('Expense Description / Category', flex: 5),
                      _buildTableHeaderCell('Cash Paid', flex: 2, alignRight: true),
                      _buildTableHeaderCell('Bank Paid', flex: 2, alignRight: true),
                      _buildTableHeaderCell('Total Amount', flex: 2, alignRight: true),
                      _buildTableHeaderCell('Recorded By', flex: 2),
                    ],
                  ),
                  ...expenseEntries.map((exp) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(exp.date, flex: 2),
                        _buildTableCell(exp.description, flex: 5),
                        _buildTableCell(exp.cashAmount != 0 ? _formatCurrency(exp.cashAmount.abs()) : '-', flex: 2, alignRight: true),
                        _buildTableCell(exp.onlineAmount != 0 ? _formatCurrency(exp.onlineAmount.abs()) : '-', flex: 2, alignRight: true),
                        _buildTableCell(_formatCurrency(exp.totalAmount.abs()), flex: 2, alignRight: true, isBold: true),
                        _buildTableCell(exp.createdBy, flex: 2),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 18),

            // 4. Sales Invoices Audit Table
            pw.Text(
              'ITEMIZED SALES TRANSACTIONS AUDIT LOG',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkHeader),
            ),
            pw.SizedBox(height: 6),
            if (sales.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: softGrey,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Center(
                  child: pw.Text('No sales transactions recorded for the selected period.', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: softGrey),
                    children: [
                      _buildTableHeaderCell('Invoice #', flex: 2),
                      _buildTableHeaderCell('Date & Time', flex: 3),
                      _buildTableHeaderCell('Customer', flex: 3),
                      _buildTableHeaderCell('Purchased Items', flex: 5),
                      _buildTableHeaderCell('Total (INR)', flex: 2, alignRight: true),
                      _buildTableHeaderCell('Payment', flex: 2),
                      _buildTableHeaderCell('COGS (INR)', flex: 2, alignRight: true),
                      _buildTableHeaderCell('Gross Profit', flex: 2, alignRight: true),
                      _buildTableHeaderCell('Status', flex: 2),
                    ],
                  ),
                  ...sales.map((sale) {
                    final itemsSummary = sale.items.map((i) => '${i.productName} (${i.quantity} ${i.unit})').join('; ');
                    final saleCOGS = sale.items.fold(0.0, (sum, i) => sum + (i.quantity * i.unitCostAtSale));
                    final saleProfit = sale.isVoided ? 0.0 : (sale.grandTotal - saleCOGS);

                    return pw.TableRow(
                      decoration: sale.isVoided ? pw.BoxDecoration(color: PdfColor.fromHex('#FEF2F2')) : null,
                      children: [
                        _buildTableCell('#${sale.invoiceNumber}', flex: 2, isBold: true),
                        _buildTableCell(DateFormatter.formatDateTime(sale.timestamp), flex: 3),
                        _buildTableCell(sale.customerName?.isNotEmpty == true ? sale.customerName! : 'Walk-in', flex: 3),
                        _buildTableCell(itemsSummary, flex: 5),
                        _buildTableCell(_formatCurrency(sale.grandTotal), flex: 2, alignRight: true, isBold: true),
                        _buildTableCell(sale.paymentType, flex: 2),
                        _buildTableCell(_formatCurrency(saleCOGS), flex: 2, alignRight: true),
                        _buildTableCell(_formatCurrency(saleProfit), flex: 2, alignRight: true, isBold: true),
                        _buildTableCell(sale.status, flex: 2),
                      ],
                    );
                  }),
                ],
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers direct file download on Web or native save/share on Android
  static Future<bool> generateAndDownloadReport({
    required List<SaleModel> sales,
    required List<AccountEntryModel> entries,
    required String periodLabel,
    required String fileName,
    String generatedBy = 'Zeek (Owner)',
  }) async {
    final pdfBytes = await generateReportBytes(
      sales: sales,
      entries: entries,
      periodLabel: periodLabel,
      generatedBy: generatedBy,
    );

    return await saveOrDownloadFile(
      bytes: pdfBytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }

  static pw.Widget _buildPdfKpiCard(String title, String value, String subtitle, PdfColor accentColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB')),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentColor)),
            pw.SizedBox(height: 2),
            pw.Text(subtitle, style: pw.TextStyle(fontSize: 6.5, color: PdfColor.fromHex('#9CA3AF'))),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfSummaryLine(String label, String value, String tag, {bool isBold = false, PdfColor? highlightColor}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ),
        pw.Expanded(
          flex: 4,
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: isBold ? 8.5 : 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: highlightColor,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Container(
          width: 50,
          child: pw.Text(
            tag,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 6.5, color: PdfColor.fromHex('#6B7280')),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, {int flex = 1, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#374151')),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {int flex = 1, bool alignRight = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
