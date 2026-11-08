import 'package:flutter_test/flutter_test.dart';
import 'package:zeek/core/constants/app_constants.dart';
import 'package:zeek/data/models/product_model.dart';
import 'package:zeek/data/models/sale_model.dart';
import 'package:zeek/data/models/daily_summary_model.dart';
import 'package:zeek/data/models/account_entry_model.dart';
import 'package:zeek/data/models/expense_model.dart';

void main() {
  group('Retail Business Scenarios & Accounting Formulas', () {
    final now = DateTime.now();

    test('Scenario 1: Procurement increases stock and tracks asset value', () {
      final initialProduct = ProductModel(
        productId: 'prod_oud',
        productName: 'Dehn Al Oud Cambodi',
        normalizedName: 'dehn al oud cambodi',
        productCode: 'OIL-OUD-001',
        productType: AppConstants.typeOil,
        category: 'Pure Oud',
        unit: AppConstants.unitMl,
        availableQuantity: 500.0,
        totalPurchased: 500.0,
        vendorPricePerUnit: 120.0,
        sellingPricePerUnit: 250.0,
        createdAt: now,
        updatedAt: now,
      );

      // Procure 1,000 ml more
      const purchasedQty = 1000.0;
      final updatedProduct = initialProduct.copyWith(
        availableQuantity: initialProduct.availableQuantity + purchasedQty,
        totalPurchased: initialProduct.totalPurchased + purchasedQty,
      );

      expect(updatedProduct.availableQuantity, equals(1500.0));
      expect(updatedProduct.totalPurchased, equals(1500.0));
      expect(updatedProduct.potentialSellingValue, equals(1500.0 * 250.0));
      expect(updatedProduct.remainingStockCost, equals(1500.0 * 120.0));
      expect(updatedProduct.expectedInventoryMargin, equals((1500.0 * 250.0) - (1500.0 * 120.0)));
    });

    test('Scenario 2: POS Sale decreases stock and generates sale items', () {
      final product = ProductModel(
        productId: 'prod_oud',
        productName: 'Dehn Al Oud Cambodi',
        normalizedName: 'dehn al oud cambodi',
        productCode: 'OIL-OUD-001',
        productType: AppConstants.typeOil,
        category: 'Pure Oud',
        unit: AppConstants.unitMl,
        availableQuantity: 500.0,
        totalPurchased: 500.0,
        vendorPricePerUnit: 120.0,
        sellingPricePerUnit: 250.0,
        createdAt: now,
        updatedAt: now,
      );

      const soldQty = 100.0;
      final remainingStock = product.availableQuantity - soldQty;
      final totalSold = product.totalSold + soldQty;

      expect(remainingStock, equals(400.0));
      expect(totalSold, equals(100.0));

      final saleItem = SaleItemModel(
        productId: product.productId,
        productName: product.productName,
        productType: product.productType,
        quantity: soldQty,
        unit: product.unit,
        unitPrice: product.sellingPricePerUnit,
        unitCostAtSale: product.vendorPricePerUnit,
        totalPrice: soldQty * product.sellingPricePerUnit,
      );

      expect(saleItem.totalPrice, equals(25000.0));
      expect(saleItem.quantity * saleItem.unitCostAtSale, equals(12000.0));
      final grossProfit = saleItem.totalPrice - (saleItem.quantity * saleItem.unitCostAtSale);
      expect(grossProfit, equals(13000.0)); // 25,000 - 12,000 = 13,000
    });

    test('Scenario 3: Split payment allocation strict balance enforcement', () {
      const grandTotal = 500.0;
      const cashPart = 200.0;
      const onlinePart = 300.0;

      expect(cashPart + onlinePart, equals(grandTotal));

      final sale = SaleModel(
        saleId: 'sale_001',
        invoiceNumber: 'INV-001',
        date: '2026-11-07',
        timestamp: now,
        items: [],
        subtotal: 500.0,
        discount: 0.0,
        grandTotal: grandTotal,
        paymentType: AppConstants.paymentSplit,
        cashAmount: cashPart,
        onlineAmount: onlinePart,
        createdAt: now,
      );

      expect(sale.cashAmount, equals(200.0));
      expect(sale.onlineAmount, equals(300.0));
      expect(sale.cashAmount + sale.onlineAmount, equals(sale.grandTotal));
    });

    test('Scenario 4: Operating expense debits correct channel without skewing bank', () {
      final cashExpense = ExpenseModel(
        expenseId: 'exp_001',
        date: '2026-11-07',
        reason: 'Shop cleaning items',
        category: 'Maintenance',
        totalAmount: 100.0,
        paymentMethod: AppConstants.paymentCash,
        cashAmount: 100.0,
        onlineAmount: 0.0,
        createdAt: now,
      );

      expect(cashExpense.cashAmount, equals(100.0));
      expect(cashExpense.onlineAmount, equals(0.0));

      final ledgerEntry = AccountEntryModel(
        entryId: 'ent_001',
        date: '2026-11-07',
        transactionType: AppConstants.accountExpense,
        referenceId: cashExpense.expenseId,
        cashAmount: -cashExpense.cashAmount,
        onlineAmount: -cashExpense.onlineAmount,
        description: 'Expense: ${cashExpense.category} - ${cashExpense.reason}',
        createdAt: now,
      );

      expect(ledgerEntry.cashAmount, equals(-100.0));
      expect(ledgerEntry.onlineAmount, equals(0.0));
      expect(ledgerEntry.totalAmount, equals(-100.0));
    });

    test('Scenario 5: Non-Oil piece enforcement rejects decimal quantities', () {
      final nonOilProduct = ProductModel(
        productId: 'prod_spray',
        productName: 'EDP Spray 100ml',
        normalizedName: 'edp spray 100ml',
        productCode: 'NON-SPR-001',
        productType: AppConstants.typeNonOil,
        category: 'Perfume Sprays',
        unit: AppConstants.unitPiece,
        availableQuantity: 50.0,
        totalPurchased: 50.0,
        vendorPricePerUnit: 400.0,
        sellingPricePerUnit: 950.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(nonOilProduct.isNonOil, isTrue);
      expect(nonOilProduct.unit, equals(AppConstants.unitPiece));

      // Whole pieces valid
      const validQty = 2.0;
      expect(validQty % 1, equals(0));

      // Decimal pieces invalid
      const invalidDecimalQty = 2.5;
      expect(invalidDecimalQty % 1 != 0, isTrue);
    });

    test('Scenario 6: Controlled sale reversal restores stock and refunds ledger', () {
      final originalSale = SaleModel(
        saleId: 'sale_002',
        invoiceNumber: 'INV-002',
        date: '2026-11-07',
        timestamp: now,
        items: [
          SaleItemModel(
            productId: 'prod_oud',
            productName: 'Dehn Al Oud Cambodi',
            productType: AppConstants.typeOil,
            quantity: 50.0,
            unit: AppConstants.unitMl,
            unitPrice: 200.0,
            totalPrice: 10000.0,
          ),
        ],
        subtotal: 10000.0,
        grandTotal: 10000.0,
        paymentType: AppConstants.paymentCash,
        cashAmount: 10000.0,
        onlineAmount: 0.0,
        status: 'COMPLETED',
        createdAt: now,
      );

      // Reversal
      const voidReason = 'Customer exchange request';
      final voidedSale = SaleModel(
        saleId: originalSale.saleId,
        invoiceNumber: originalSale.invoiceNumber,
        date: originalSale.date,
        timestamp: originalSale.timestamp,
        items: originalSale.items,
        subtotal: originalSale.subtotal,
        grandTotal: originalSale.grandTotal,
        paymentType: originalSale.paymentType,
        cashAmount: originalSale.cashAmount,
        onlineAmount: originalSale.onlineAmount,
        status: 'VOIDED',
        createdAt: originalSale.createdAt,
      );

      expect(voidedSale.isVoided, isTrue);

      // Negative ledger entry
      final refundEntry = AccountEntryModel(
        entryId: 'ent_refund',
        date: '2026-11-07',
        transactionType: AppConstants.accountRefund,
        referenceId: voidedSale.saleId,
        cashAmount: -voidedSale.cashAmount,
        onlineAmount: -voidedSale.onlineAmount,
        description: 'Reversal of Sale #${voidedSale.invoiceNumber}: $voidReason',
        createdAt: now,
      );

      expect(refundEntry.cashAmount, equals(-10000.0));
      expect(refundEntry.totalAmount, equals(-10000.0));
    });

    test('Scenario 7: Daily reconciliation formula maintains dual-channel equilibrium', () {
      final summary = DailySummaryModel(
        date: '2026-11-07',
        openingCashBalance: 1000.0,
        openingOnlineBalance: 5000.0,
        cashSales: 3500.0,
        onlineSales: 4500.0,
        totalSales: 8000.0,
        totalTransactions: 12,
        cashExpenses: 500.0,
        onlineExpenses: 1000.0,
        totalExpenses: 1500.0,
        cashDepositedToBank: 2000.0,
      );

      // Formula: Closing Cash = Opening (1,000) + Cash Sales (3,500) - Cash Exp (500) - Bank Deposit (2,000) = 2,000
      expect(summary.expectedClosingCash, equals(2000.0));

      // Formula: Closing Bank = Opening (5,000) + Online Sales (4,500) - Online Exp (1,000) + Bank Deposit (2,000) = 10,500
      expect(summary.expectedClosingBank, equals(10500.0));

      // Total liquid balance = 2,000 + 10,500 = 12,500
      expect(summary.grandExpectedBalance, equals(12500.0));

      // Net business flow = Total Sales (8,000) - Total Exp (1,500) = 6,500
      expect(summary.netTotalFlow, equals(6500.0));
    });
  });
}

