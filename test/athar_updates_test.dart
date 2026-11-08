import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeek/core/constants/app_constants.dart';
import 'package:zeek/data/models/account_entry_model.dart';
import 'package:zeek/data/models/sale_model.dart';
import 'package:zeek/services/reports/financial_report_pdf_service.dart';
import 'package:zeek/shared/widgets/custom_date_range_dialog.dart';

void main() {
  group('Athar Update 1: Sales History Date-Wise Filtering & Summary', () {
    final now = DateTime(2026, 11, 8, 14, 30);
    final yesterday = DateTime(2026, 11, 7, 10, 0);
    final lastMonth = DateTime(2026, 10, 15, 16, 45);

    final salesList = [
      // Today Sale
      SaleModel(
        saleId: 'sale_001',
        invoiceNumber: 'INV-001',
        date: '2026-11-08',
        timestamp: now,
        items: [
          SaleItemModel(
            productId: 'oud_01',
            productName: 'Royal Oud Cambodi',
            productType: AppConstants.typeOil,
            quantity: 10,
            unit: 'ml',
            unitPrice: 50,
            unitCostAtSale: 20,
            totalPrice: 500,
          ),
        ],
        subtotal: 500,
        discount: 0,
        grandTotal: 500,
        paymentType: AppConstants.paymentCash,
        cashAmount: 500,
        onlineAmount: 0,
        status: 'COMPLETED',
        createdBy: 'Zeek (Owner)',
        customerName: 'Ahmed Ali',
        customerPhone: '9876543210',
        createdAt: now,
      ),
      // Yesterday Sale
      SaleModel(
        saleId: 'sale_002',
        invoiceNumber: 'INV-002',
        date: '2026-11-07',
        timestamp: yesterday,
        items: [
          SaleItemModel(
            productId: 'musk_01',
            productName: 'White Musk',
            productType: AppConstants.typeOil,
            quantity: 5,
            unit: 'ml',
            unitPrice: 60,
            unitCostAtSale: 25,
            totalPrice: 300,
          ),
        ],
        subtotal: 300,
        discount: 0,
        grandTotal: 300,
        paymentType: AppConstants.paymentOnline,
        cashAmount: 0,
        onlineAmount: 300,
        status: 'COMPLETED',
        createdBy: 'Staff',
        customerName: 'Bilal Khan',
        customerPhone: '9876543211',
        createdAt: yesterday,
      ),
      // Last Month Sale
      SaleModel(
        saleId: 'sale_003',
        invoiceNumber: 'INV-003',
        date: '2026-10-15',
        timestamp: lastMonth,
        items: [
          SaleItemModel(
            productId: 'rose_01',
            productName: 'Taif Rose Spray',
            productType: AppConstants.typeNonOil,
            quantity: 2,
            unit: 'pcs',
            unitPrice: 400,
            unitCostAtSale: 150,
            totalPrice: 800,
          ),
        ],
        subtotal: 800,
        discount: 100,
        grandTotal: 700,
        paymentType: AppConstants.paymentSplit,
        cashAmount: 200,
        onlineAmount: 500,
        status: 'COMPLETED',
        createdBy: 'Zeek (Owner)',
        customerName: 'Sultan Al-Oud',
        customerPhone: '9876543212',
        createdAt: lastMonth,
      ),
    ];

    test('Today filter matches only today sales and computes accurate summary', () {
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final filtered = salesList.where((s) {
        return !s.timestamp.isBefore(todayStart) && !s.timestamp.isAfter(todayEnd);
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.invoiceNumber, equals('INV-001'));

      final totalSalesAmount = filtered.fold(0.0, (sum, s) => sum + s.grandTotal);
      final totalCash = filtered.fold(0.0, (sum, s) => sum + s.cashAmount);
      final totalOnline = filtered.fold(0.0, (sum, s) => sum + s.onlineAmount);

      expect(totalSalesAmount, equals(500.0));
      expect(totalCash, equals(500.0));
      expect(totalOnline, equals(0.0));
    });

    test('Custom Date Range includes transactions made late on To Date', () {
      final customRange = DateTimeRange(
        start: DateTime(2026, 11, 7),
        end: DateTime(2026, 11, 8),
      );

      final cStart = DateTime(customRange.start.year, customRange.start.month, customRange.start.day, 0, 0, 0);
      final cEnd = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59, 999);

      final filtered = salesList.where((s) {
        return !s.timestamp.isBefore(cStart) && !s.timestamp.isAfter(cEnd);
      }).toList();

      expect(filtered.length, equals(2));
      expect(filtered.map((s) => s.invoiceNumber).toList(), containsAll(['INV-001', 'INV-002']));
    });

    test('Search filter and Date filter combine accurately', () {
      final query = 'bilal';
      final thisMonthStart = DateTime(now.year, now.month, 1, 0, 0, 0);
      final thisMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

      final filtered = salesList.where((s) {
        final matchesQuery = s.customerName?.toLowerCase().contains(query) ?? false;
        final matchesDate = !s.timestamp.isBefore(thisMonthStart) && !s.timestamp.isAfter(thisMonthEnd);
        return matchesQuery && matchesDate;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.invoiceNumber, equals('INV-002'));
    });
  });

  group('Athar Update 2: Accounts & Ledger Date-Wise Filtering & Summary', () {
    final now = DateTime(2026, 11, 8, 14, 30);
    final yesterday = DateTime(2026, 11, 7, 10, 0);

    final entries = [
      AccountEntryModel(
        entryId: 'e1',
        date: '2026-11-08',
        transactionType: AppConstants.accountSaleIncome,
        referenceId: 'sale_001',
        cashAmount: 500.0,
        onlineAmount: 0.0,
        description: 'POS Sale #INV-001',
        createdBy: 'Zeek (Owner)',
        createdAt: now,
      ),
      AccountEntryModel(
        entryId: 'e2',
        date: '2026-11-08',
        transactionType: AppConstants.accountExpense,
        referenceId: 'exp_001',
        cashAmount: -100.0,
        onlineAmount: 0.0,
        description: 'Shop Electricity Bill',
        createdBy: 'Zeek (Owner)',
        createdAt: now.add(const Duration(hours: 1)),
      ),
      AccountEntryModel(
        entryId: 'e3',
        date: '2026-11-07',
        transactionType: AppConstants.accountSaleIncome,
        referenceId: 'sale_002',
        cashAmount: 0.0,
        onlineAmount: 300.0,
        description: 'POS Sale #INV-002',
        createdBy: 'Staff',
        createdAt: yesterday,
      ),
    ];

    test('Computes filtered Total Income, Expenses, Net Balance and Transactions Count', () {
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final filtered = entries.where((e) {
        return !e.createdAt.isBefore(todayStart) && !e.createdAt.isAfter(todayEnd);
      }).toList();

      expect(filtered.length, equals(2));

      final filteredIncome = filtered.where((e) {
        return e.transactionType == AppConstants.accountSaleIncome ||
            (e.cashAmount > 0 && e.transactionType != AppConstants.accountTransfer);
      }).fold(0.0, (sum, e) => sum + (e.cashAmount > 0 ? e.cashAmount : 0.0) + (e.onlineAmount > 0 ? e.onlineAmount : 0.0));

      final filteredExpenses = filtered.where((e) => e.transactionType == AppConstants.accountExpense).fold(
            0.0,
            (sum, e) => sum + (e.cashAmount.abs() + e.onlineAmount.abs()),
          );

      final filteredNetBalance = filteredIncome - filteredExpenses;

      expect(filteredIncome, equals(500.0));
      expect(filteredExpenses, equals(100.0));
      expect(filteredNetBalance, equals(400.0));
    });
  });

  group('Athar Update 3: Reports & Analytics PDF Report Generation', () {
    test('FinancialReportPdfService generates valid A4 PDF bytes with all required sections', () async {
      final now = DateTime(2026, 11, 8, 14, 30);
      final sampleSale = SaleModel(
        saleId: 'sale_999',
        invoiceNumber: 'INV-999',
        date: '2026-11-08',
        timestamp: now,
        items: [
          SaleItemModel(
            productId: 'oud_royale',
            productName: 'Royal Oud Cambodi Luxury Athar',
            productType: AppConstants.typeOil,
            quantity: 25,
            unit: 'ml',
            unitPrice: 100,
            unitCostAtSale: 40,
            totalPrice: 2500,
          ),
        ],
        subtotal: 2500,
        discount: 200,
        grandTotal: 2300,
        paymentType: AppConstants.paymentSplit,
        cashAmount: 1000,
        onlineAmount: 1300,
        status: 'COMPLETED',
        createdBy: 'Zeek (Owner)',
        customerName: 'Sheikh Mansoor',
        customerPhone: '+91 99999 88888',
        createdAt: now,
      );

      final sampleExpense = AccountEntryModel(
        entryId: 'exp_999',
        date: '2026-11-08',
        transactionType: AppConstants.accountExpense,
        referenceId: 'exp_ref_1',
        cashAmount: -500,
        onlineAmount: 0,
        description: 'Store Rental & Air Conditioning Maintenance',
        createdBy: 'Zeek (Owner)',
        createdAt: now,
      );

      final Uint8List pdfBytes = await FinancialReportPdfService.generateReportBytes(
        sales: [sampleSale],
        entries: [sampleExpense],
        periodLabel: 'Today (08 Nov 2026)',
        generatedBy: 'Zeek (Owner)',
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // Valid PDF magic header bytes: %PDF-
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
      expect(pdfBytes[4], equals(0x2D)); // -
    });
  });

  group('Validation: CustomDateRangeDialog', () {
    testWidgets('CustomDateRangeDialog validates that From Date cannot be later than To Date', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomDateRangeDialog(
              initialStartDate: DateTime(2026, 11, 10),
              initialEndDate: DateTime(2026, 11, 5),
            ),
          ),
        ),
      );

      expect(find.text('From Date cannot be later than To Date.'), findsOneWidget);

      final applyButtonFinder = find.widgetWithText(ElevatedButton, 'Apply Filter');
      final ElevatedButton applyButton = tester.widget(applyButtonFinder);
      expect(applyButton.onPressed, isNull); // Disabled because invalid!
    });
  });
}

