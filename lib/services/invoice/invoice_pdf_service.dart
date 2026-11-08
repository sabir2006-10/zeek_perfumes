import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/sale_model.dart';

class InvoicePdfService {
  InvoicePdfService._();

  static const String shopName = AppConstants.appName;
  static const String shopTagline = 'Pure Dehn Al Oud, Luxury Athar & Exclusive EDP Sprays';
  static const String shopAddress = 'Main Commercial Market, Surat / Mumbai Branch';
  static const String shopPhone = '+91 98765 43210';
  static const String shopGst = 'GSTIN: 27AAAAZ0000A1Z5';

  /// Generates the raw PDF bytes for an 80mm thermal receipt
  static Future<Uint8List> generateReceiptBytes(SaleModel sale) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Text(
                'ZEEK',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              pw.Text(
                'PERFUMES & ATHAR',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
              pw.Text('Ph: $shopPhone • $shopGst', style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8),

              // Invoice metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice: #${sale.invoiceNumber}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormatter.formatDate(sale.timestamp), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cashier: ${sale.createdBy}', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(DateFormatter.formatTime(sale.timestamp), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Divider(thickness: 0.8),

              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('Item Description', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 3, child: pw.Text('Total', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items
              ...sale.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.productName, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Rate: ${CurrencyFormatter.formatSmart(item.unitPrice)}/${item.unit}', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('${item.quantity} ${item.unit}', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(CurrencyFormatter.formatSmart(item.totalPrice), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.8),

              // Subtotal & Discount
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(CurrencyFormatter.format(sale.subtotal), style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (sale.discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount Applied:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('-${CurrencyFormatter.format(sale.discount)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 1.0),

              // Grand Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(CurrencyFormatter.format(sale.grandTotal), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 1.0),

              // Payment Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Mode:', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(sale.paymentType, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (sale.paymentType == AppConstants.paymentSplit) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cash Paid:', style: const pw.TextStyle(fontSize: 7)),
                    pw.Text(CurrencyFormatter.format(sale.cashAmount), style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Online/UPI Paid:', style: const pw.TextStyle(fontSize: 7)),
                    pw.Text(CurrencyFormatter.format(sale.onlineAmount), style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ],

              pw.SizedBox(height: 10),
              pw.Text('Thank you for shopping with Zeek Perfumes!', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
              pw.Text('All pure athars are non-refundable once opened.', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers the native browser or mobile printing dialog
  static Future<void> printReceipt(SaleModel sale) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => generateReceiptBytes(sale),
      name: 'Receipt_${sale.invoiceNumber}',
    );
  }

  /// Direct PDF download / share
  static Future<void> shareReceipt(SaleModel sale) async {
    final bytes = await generateReceiptBytes(sale);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Invoice_${sale.invoiceNumber}.pdf',
    );
  }
}

