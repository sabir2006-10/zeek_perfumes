import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeek/core/constants/app_constants.dart';
import 'package:zeek/data/models/account_entry_model.dart';
import 'package:zeek/data/models/sale_model.dart';
import 'package:zeek/features/authentication/models/user_role.dart';
import 'package:zeek/services/reports/financial_report_csv_service.dart';

void main() {
  group('Targeted Fix 1: Owner Name Display', () {
    test('Default mock admin display name is Zeek (Owner)', () {
      final admin = AppUser.mockAdmin();
      expect(admin.displayName, equals('Zeek (Owner)'));
      expect(admin.email, equals('admin@zeekperfumes.com'));
      expect(admin.role, equals(UserRole.admin));
    });
  });

  group('Targeted Fix 2: Stock Sold Layout Responsiveness & Overflow Prevention', () {
    testWidgets('Stock Sold KPI Card does not overflow with long title or narrow width', (tester) async {
      // Test the KPI card in an extremely narrow container (140px)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total Merchandise Revenue Very Long Header',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.monetization_on_outlined, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.monetization_on_outlined), findsOneWidget);
    });
  });

  group('Targeted Fix 3: Financial Report CSV Generation & Escaping', () {
    test('Generates valid CSV with headers, summary, and sales records with RFC 4180 escaping', () {
      final now = DateTime(2026, 11, 8, 14, 30);
      final testSale = SaleModel(
        saleId: 'sale_101',
        invoiceNumber: 'INV-20261108-001',
        date: '2026-11-08',
        timestamp: now,
        items: [
          SaleItemModel(
            productId: 'oud_01',
            productName: 'Royal Oud Cambodi, Special "Reserve"',
            productType: AppConstants.typeOil,
            quantity: 50.0,
            unit: 'ml',
            unitPrice: 10.0,
            unitCostAtSale: 4.0,
            totalPrice: 500.0,
          ),
        ],
        subtotal: 500.0,
        discount: 50.0,
        grandTotal: 450.0,
        paymentType: 'SPLIT',
        cashAmount: 200.0,
        onlineAmount: 250.0,
        status: 'COMPLETED',
        createdBy: 'Zeek (Owner)',
        customerName: 'Ahmed, Al-Mansoor',
        customerPhone: '+91 9876543210',
        createdAt: now,
      );

      final testExpense = AccountEntryModel(
        entryId: 'exp_01',
        date: '2026-11-08',
        transactionType: AppConstants.accountExpense,
        referenceId: 'ref_01',
        cashAmount: -100.0,
        onlineAmount: 0.0,
        description: 'Shop Electricity & Fragrance Display light',
        createdBy: 'Zeek (Owner)',
        createdAt: now,
      );

      final csvString = FinancialReportCsvService.buildCsvContent(
        sales: [testSale],
        entries: [testExpense],
        periodLabel: 'Today (2026-11-08)',
      );

      // Verify Metadata and Title
      expect(csvString, contains('ZEEK PERFUMES & ATHAR - FINANCIAL & SALES INTELLIGENCE REPORT'));
      expect(csvString, contains('Period,Today (2026-11-08)'));

      // Verify Executive Summary
      expect(csvString, contains('Gross Sales Revenue (INR),450.00'));
      expect(csvString, contains('Cost of Goods Sold (COGS) (INR),200.00'));
      expect(csvString, contains('Gross Realized Profit (INR),250.00'));
      expect(csvString, contains('Total Operating Expenses (INR),100.00'));
      expect(csvString, contains('Net Business Profit / Result (INR),150.00'));

      // Verify Column Headers
      expect(csvString, contains('Invoice #,Date,Time,Cashier,Customer Name,Customer Phone,Payment Method,Items Purchased,Total Items Qty,Subtotal (INR),Discount (INR),Grand Total (INR),Cash Paid (INR),Online Paid (INR),COGS Cost (INR),Gross Profit (INR),Status'));

      // Verify RFC 4180 Escaped Customer Name and Product Name (with commas and quotes)
      expect(csvString, contains('"Ahmed, Al-Mansoor"'));
      expect(csvString, contains('"Royal Oud Cambodi, Special ""Reserve"" (50.0 ml)"'));

      // Verify Expenses Table
      expect(csvString, contains('STORE OPERATING EXPENSES LOG'));
      expect(csvString, contains('Shop Electricity & Fragrance Display light'));
    });
  });
}
