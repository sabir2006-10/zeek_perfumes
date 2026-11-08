import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/stock_movement_model.dart';
import '../models/account_entry_model.dart';
import '../models/vendor_model.dart';
import '../models/expense_model.dart';
import '../models/daily_summary_model.dart';
import '../models/purchase_model.dart';

class ShopRepository {
  final FirebaseFirestore _firestore;
  final String shopId;

  ShopRepository({
    FirebaseFirestore? firestore,
    this.shopId = AppConstants.defaultShopId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('shops').doc(shopId).collection('products');

  CollectionReference<Map<String, dynamic>> get _salesRef =>
      _firestore.collection('shops').doc(shopId).collection('sales');

  CollectionReference<Map<String, dynamic>> get _stockMovementsRef =>
      _firestore.collection('shops').doc(shopId).collection('stock_movements');

  CollectionReference<Map<String, dynamic>> get _accountEntriesRef =>
      _firestore.collection('shops').doc(shopId).collection('account_entries');

  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      _firestore.collection('shops').doc(shopId).collection('expenses');

  CollectionReference<Map<String, dynamic>> get _vendorsRef =>
      _firestore.collection('shops').doc(shopId).collection('vendors');

  CollectionReference<Map<String, dynamic>> get _dailySummariesRef =>
      _firestore.collection('shops').doc(shopId).collection('daily_summaries');

  CollectionReference<Map<String, dynamic>> get _purchasesRef =>
      _firestore.collection('shops').doc(shopId).collection('purchases');

  // ==========================================
  // PRODUCTS / INVENTORY
  // ==========================================

  Stream<List<ProductModel>> watchProducts({String? productType}) {
    Query<Map<String, dynamic>> query = _productsRef.where('isActive', isEqualTo: true);
    if (productType != null) {
      query = query.where('productType', isEqualTo: productType);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addProduct(ProductModel product) async {
    final docRef = _productsRef.doc(product.productId.isEmpty ? null : product.productId);
    final modelToSave = product.copyWith(productId: docRef.id);
    await docRef.set(modelToSave.toMap());

    // Log opening stock movement if initial availableQuantity > 0
    if (product.availableQuantity > 0) {
      final movementDoc = _stockMovementsRef.doc();
      final movement = StockMovementModel(
        movementId: movementDoc.id,
        productId: docRef.id,
        productName: product.productName,
        movementType: AppConstants.movementOpeningStock,
        quantity: product.availableQuantity,
        unit: product.unit,
        referenceId: 'INITIAL_STOCK',
        date: DateTime.now().toIso8601String().substring(0, 10),
        createdAt: DateTime.now(),
      );
      await movementDoc.set(movement.toMap());
    }
  }

  Future<void> updateProduct(ProductModel product) async {
    await _productsRef.doc(product.productId).update(product.toMap());
  }

  Future<void> archiveProduct(String productId) async {
    await _productsRef.doc(productId).update({
      'isActive': false,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> adjustStock({
    required String productId,
    required String productName,
    required double oldQuantity,
    required double newQuantity,
    required String unit,
    required String reason,
    required String user,
    String? movementType,
  }) async {
    final diff = newQuantity - oldQuantity;
    if (diff == 0) return;

    await _firestore.runTransaction((tx) async {
      final prodDocRef = _productsRef.doc(productId);
      final prodSnap = await tx.get(prodDocRef);
      if (!prodSnap.exists) {
        throw Exception('Product $productId not found.');
      }

      tx.update(prodDocRef, {
        'availableQuantity': newQuantity,
        'updatedAt': Timestamp.now(),
      });

      final movementDocRef = _stockMovementsRef.doc();
      final movement = StockMovementModel(
        movementId: movementDocRef.id,
        productId: productId,
        productName: productName,
        movementType: movementType ?? AppConstants.movementAdjustment,
        quantity: diff, // signed difference
        unit: unit,
        referenceId: reason,
        date: DateTime.now().toIso8601String().substring(0, 10),
        createdBy: user,
        createdAt: DateTime.now(),
      );
      tx.set(movementDocRef, movement.toMap());
    });
  }

  // ==========================================
  // ATOMIC COMPLETE SALE TRANSACTION
  // ==========================================

  Future<String> completeSale(SaleModel sale) async {
    return await _firestore.runTransaction<String>((tx) async {
      // 1. ALL READS FIRST (Firestore rule: all reads must precede all writes)
      // Read all product documents
      final List<DocumentSnapshot<Map<String, dynamic>>> productSnapshots = [];
      for (final item in sale.items) {
        final prodRef = _productsRef.doc(item.productId);
        final snap = await tx.get(prodRef);
        if (!snap.exists) {
          throw Exception('Product "${item.productName}" no longer exists in inventory.');
        }
        productSnapshots.add(snap);
      }

      // Check idempotency (prevent duplicate sale if double-clicked)
      final saleDocRef = _salesRef.doc(sale.saleId);
      final saleSnap = await tx.get(saleDocRef);
      if (saleSnap.exists) {
        return sale.saleId; // already committed
      }

      // Read Daily Summary before any writes
      final dailyDocRef = _dailySummariesRef.doc(sale.date);
      final dailySnap = await tx.get(dailyDocRef);

      // 2. Validate sufficient stock for every product
      for (int i = 0; i < sale.items.length; i++) {
        final item = sale.items[i];
        final prodData = productSnapshots[i].data()!;
        final currentStock = (prodData['availableQuantity'] as num?)?.toDouble() ?? 0.0;
        if (currentStock < item.quantity) {
          throw Exception(
            'Insufficient stock for "${item.productName}". Requested: ${item.quantity} ${item.unit}, Available: $currentStock ${item.unit}',
          );
        }
      }

      // 3. ALL WRITES: Deduct inventory & record stock movements
      for (int i = 0; i < sale.items.length; i++) {
        final item = sale.items[i];
        final prodRef = _productsRef.doc(item.productId);
        final prodData = productSnapshots[i].data()!;
        final currentStock = (prodData['availableQuantity'] as num?)?.toDouble() ?? 0.0;
        final totalSold = (prodData['totalSold'] as num?)?.toDouble() ?? 0.0;

        tx.update(prodRef, {
          'availableQuantity': currentStock - item.quantity,
          'totalSold': totalSold + item.quantity,
          'updatedAt': Timestamp.now(),
        });

        // Record stock movement (negative quantity for sale)
        final movementRef = _stockMovementsRef.doc();
        final movement = StockMovementModel(
          movementId: movementRef.id,
          productId: item.productId,
          productName: item.productName,
          movementType: AppConstants.movementSale,
          quantity: -item.quantity,
          unit: item.unit,
          referenceId: sale.saleId,
          date: sale.date,
          createdBy: sale.createdBy,
          createdAt: DateTime.now(),
        );
        tx.set(movementRef, movement.toMap());
      }

      // 4. Create Sale document
      tx.set(saleDocRef, sale.toMap());

      // 5. Create Account Ledger entry
      final accountDocRef = _accountEntriesRef.doc();
      final accountEntry = AccountEntryModel(
        entryId: accountDocRef.id,
        date: sale.date,
        transactionType: AppConstants.accountSaleIncome,
        referenceId: sale.saleId,
        cashAmount: sale.cashAmount,
        onlineAmount: sale.onlineAmount,
        description: 'Sale Invoice #${sale.invoiceNumber}',
        createdBy: sale.createdBy,
        createdAt: DateTime.now(),
      );
      tx.set(accountDocRef, accountEntry.toMap());

      // 6. Update Daily Summary
      if (dailySnap.exists) {
        final curData = dailySnap.data()!;
        tx.update(dailyDocRef, {
          'cashSales': ((curData['cashSales'] as num?)?.toDouble() ?? 0.0) + sale.cashAmount,
          'onlineSales': ((curData['onlineSales'] as num?)?.toDouble() ?? 0.0) + sale.onlineAmount,
          'totalSales': ((curData['totalSales'] as num?)?.toDouble() ?? 0.0) + sale.grandTotal,
          'totalTransactions': ((curData['totalTransactions'] as num?)?.toInt() ?? 0) + 1,
          'closingCashBalance': ((curData['closingCashBalance'] as num?)?.toDouble() ?? 0.0) + sale.cashAmount,
          'closingOnlineBalance': ((curData['closingOnlineBalance'] as num?)?.toDouble() ?? 0.0) + sale.onlineAmount,
        });
      } else {
        final newSummary = DailySummaryModel(
          date: sale.date,
          cashSales: sale.cashAmount,
          onlineSales: sale.onlineAmount,
          totalSales: sale.grandTotal,
          totalTransactions: 1,
          closingCashBalance: sale.cashAmount,
          closingOnlineBalance: sale.onlineAmount,
        );
        tx.set(dailyDocRef, newSummary.toMap());
      }

      return sale.saleId;
    });
  }

  // ==========================================
  // SALES HISTORY & REVERSAL / VOID (SPARK-OPTIMIZED)
  // ==========================================

  Stream<List<SaleModel>> watchSales({int limit = 100}) {
    return _salesRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SaleModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> voidSale({
    required String saleId,
    required String reason,
    required String user,
  }) async {
    await _firestore.runTransaction((tx) async {
      // 1. ALL READS FIRST
      final saleDocRef = _salesRef.doc(saleId);
      final saleSnap = await tx.get(saleDocRef);
      if (!saleSnap.exists) throw Exception('Sale $saleId does not exist.');

      final sale = SaleModel.fromMap(saleSnap.data()!, saleId);
      if (sale.status == 'VOIDED') throw Exception('Sale is already voided.');

      // Read all products in sale
      final List<DocumentSnapshot<Map<String, dynamic>>> productSnapshots = [];
      for (final item in sale.items) {
        final prodRef = _productsRef.doc(item.productId);
        final prodSnap = await tx.get(prodRef);
        productSnapshots.add(prodSnap);
      }

      // Read daily summary
      final dailyDocRef = _dailySummariesRef.doc(sale.date);
      final dailySnap = await tx.get(dailyDocRef);

      // 2. ALL WRITES
      // 2.1 Mark sale as voided
      tx.update(saleDocRef, {
        'status': 'VOIDED',
        'voidReason': reason,
        'voidedBy': user,
        'voidedAt': Timestamp.now(),
      });

      // 2.2 Restore stock & log reversal movements
      for (int i = 0; i < sale.items.length; i++) {
        final item = sale.items[i];
        final prodSnap = productSnapshots[i];
        if (prodSnap.exists) {
          final curStock = (prodSnap.data()!['availableQuantity'] as num?)?.toDouble() ?? 0.0;
          final totalSold = (prodSnap.data()!['totalSold'] as num?)?.toDouble() ?? 0.0;
          tx.update(_productsRef.doc(item.productId), {
            'availableQuantity': curStock + item.quantity,
            'totalSold': (totalSold - item.quantity).clamp(0.0, double.infinity),
            'updatedAt': Timestamp.now(),
          });
        }

        final movementRef = _stockMovementsRef.doc();
        final movement = StockMovementModel(
          movementId: movementRef.id,
          productId: item.productId,
          productName: item.productName,
          movementType: AppConstants.movementSaleReturn,
          quantity: item.quantity, // positive restoration
          unit: item.unit,
          referenceId: 'VOID_SALE_$saleId: $reason',
          date: DateTime.now().toIso8601String().substring(0, 10),
          createdBy: user,
          createdAt: DateTime.now(),
        );
        tx.set(movementRef, movement.toMap());
      }

      // 2.3 Create reverse Account Ledger entry
      final accountRef = _accountEntriesRef.doc();
      final accountEntry = AccountEntryModel(
        entryId: accountRef.id,
        date: DateTime.now().toIso8601String().substring(0, 10),
        transactionType: AppConstants.accountRefund,
        referenceId: saleId,
        cashAmount: -sale.cashAmount,
        onlineAmount: -sale.onlineAmount,
        description: 'Reversal of Sale #${sale.invoiceNumber}: $reason',
        createdBy: user,
        createdAt: DateTime.now(),
      );
      tx.set(accountRef, accountEntry.toMap());

      // 2.4 Reconcile Daily Summary
      if (dailySnap.exists) {
        final cur = dailySnap.data()!;
        tx.update(dailyDocRef, {
          'cashSales': ((cur['cashSales'] as num?)?.toDouble() ?? 0.0) - sale.cashAmount,
          'onlineSales': ((cur['onlineSales'] as num?)?.toDouble() ?? 0.0) - sale.onlineAmount,
          'totalSales': ((cur['totalSales'] as num?)?.toDouble() ?? 0.0) - sale.grandTotal,
          'closingCashBalance': ((cur['closingCashBalance'] as num?)?.toDouble() ?? 0.0) - sale.cashAmount,
          'closingOnlineBalance': ((cur['closingOnlineBalance'] as num?)?.toDouble() ?? 0.0) - sale.onlineAmount,
        });
      }
    });
  }

  // ==========================================
  // ACCOUNTS, EXPENSES & TRANSFERS (SPARK-OPTIMIZED)
  // ==========================================

  Stream<List<AccountEntryModel>> watchAccountEntries({int limit = 100}) {
    return _accountEntriesRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AccountEntryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _firestore.runTransaction((tx) async {
      // 1. ALL READS FIRST
      final dailyDocRef = _dailySummariesRef.doc(expense.date);
      final dailySnap = await tx.get(dailyDocRef);

      // 2. ALL WRITES
      final expenseRef = _expensesRef.doc(expense.expenseId.isEmpty ? null : expense.expenseId);
      final modelToSave = ExpenseModel(
        expenseId: expenseRef.id,
        date: expense.date,
        reason: expense.reason,
        category: expense.category,
        totalAmount: expense.totalAmount,
        paymentMethod: expense.paymentMethod,
        cashAmount: expense.cashAmount,
        onlineAmount: expense.onlineAmount,
        description: expense.description,
        status: expense.status,
        createdBy: expense.createdBy,
        createdAt: expense.createdAt,
      );
      tx.set(expenseRef, modelToSave.toMap());

      // Debit account entries (negative amounts)
      final accountRef = _accountEntriesRef.doc();
      final accountEntry = AccountEntryModel(
        entryId: accountRef.id,
        date: expense.date,
        transactionType: AppConstants.accountExpense,
        referenceId: expenseRef.id,
        cashAmount: -expense.cashAmount,
        onlineAmount: -expense.onlineAmount,
        description: 'Expense: ${expense.category} - ${expense.reason}',
        createdBy: expense.createdBy,
        createdAt: DateTime.now(),
      );
      tx.set(accountRef, accountEntry.toMap());

      // Update Daily Summary
      if (dailySnap.exists) {
        final cur = dailySnap.data()!;
        tx.update(dailyDocRef, {
          'cashExpenses': ((cur['cashExpenses'] as num?)?.toDouble() ?? 0.0) + expense.cashAmount,
          'onlineExpenses': ((cur['onlineExpenses'] as num?)?.toDouble() ?? 0.0) + expense.onlineAmount,
          'totalExpenses': ((cur['totalExpenses'] as num?)?.toDouble() ?? 0.0) + expense.totalAmount,
          'closingCashBalance': ((cur['closingCashBalance'] as num?)?.toDouble() ?? 0.0) - expense.cashAmount,
          'closingOnlineBalance': ((cur['closingOnlineBalance'] as num?)?.toDouble() ?? 0.0) - expense.onlineAmount,
        });
      } else {
        final newSummary = DailySummaryModel(
          date: expense.date,
          cashExpenses: expense.cashAmount,
          onlineExpenses: expense.onlineAmount,
          totalExpenses: expense.totalAmount,
          closingCashBalance: -expense.cashAmount,
          closingOnlineBalance: -expense.onlineAmount,
        );
        tx.set(dailyDocRef, newSummary.toMap());
      }
    });
  }

  Future<void> transferCashToBank({
    required double amount,
    required String notes,
    required String user,
  }) async {
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    await _firestore.runTransaction((tx) async {
      // 1. ALL READS FIRST
      final dailyDocRef = _dailySummariesRef.doc(dateStr);
      final dailySnap = await tx.get(dailyDocRef);

      // 2. ALL WRITES
      final entryRef = _accountEntriesRef.doc();
      final entry = AccountEntryModel(
        entryId: entryRef.id,
        date: dateStr,
        transactionType: AppConstants.accountTransfer,
        referenceId: 'CASH_TO_BANK',
        cashAmount: -amount, // cash reduced
        onlineAmount: amount, // bank increased
        description: 'Internal Transfer Cash to Bank: $notes',
        createdBy: user,
        createdAt: DateTime.now(),
      );
      tx.set(entryRef, entry.toMap());

      if (dailySnap.exists) {
        final cur = dailySnap.data()!;
        tx.update(dailyDocRef, {
          'cashDepositedToBank': ((cur['cashDepositedToBank'] as num?)?.toDouble() ?? 0.0) + amount,
          'closingCashBalance': ((cur['closingCashBalance'] as num?)?.toDouble() ?? 0.0) - amount,
          'closingOnlineBalance': ((cur['closingOnlineBalance'] as num?)?.toDouble() ?? 0.0) + amount,
        });
      } else {
        final newSummary = DailySummaryModel(
          date: dateStr,
          cashDepositedToBank: amount,
          closingCashBalance: -amount,
          closingOnlineBalance: amount,
        );
        tx.set(dailyDocRef, newSummary.toMap());
      }
    });
  }

  Future<void> reconcileAndCloseDay({
    required String date,
    required double actualPhysicalCash,
    required String user,
    required String notes,
  }) async {
    await _firestore.runTransaction((tx) async {
      // 1. READS FIRST
      final dailyDocRef = _dailySummariesRef.doc(date);
      final dailySnap = await tx.get(dailyDocRef);

      double discrepancy = 0.0;
      if (dailySnap.exists) {
        final cur = DailySummaryModel.fromMap(dailySnap.data()!, date);
        discrepancy = actualPhysicalCash - cur.expectedClosingCash;
        tx.update(dailyDocRef, {
          'closingCashBalance': actualPhysicalCash,
          'cashDiscrepancy': discrepancy,
          'isClosed': true,
          'closedBy': user,
          'closedAt': Timestamp.now(),
          'notes': notes,
        });
      } else {
        tx.set(dailyDocRef, DailySummaryModel(
          date: date,
          closingCashBalance: actualPhysicalCash,
          cashDiscrepancy: 0.0,
          isClosed: true,
          closedBy: user,
          closedAt: DateTime.now(),
          notes: notes,
        ).toMap());
      }

      // If discrepancy exists, record audit ledger entry
      if (discrepancy != 0.0) {
        final entryRef = _accountEntriesRef.doc();
        final isShortage = discrepancy < 0;
        final entry = AccountEntryModel(
          entryId: entryRef.id,
          date: date,
          transactionType: isShortage ? 'CASH_SHORTAGE' : 'CASH_SURPLUS',
          referenceId: 'DAY_END_CLOSE_$date',
          cashAmount: discrepancy,
          onlineAmount: 0.0,
          description: 'Day-End Audit Discrepancy (${isShortage ? "Cash Shortage" : "Cash Surplus"}): $notes',
          createdBy: user,
          createdAt: DateTime.now(),
        );
        tx.set(entryRef, entry.toMap());
      }
    });
  }

  Stream<DailySummaryModel?> watchDailySummary(String date) {
    return _dailySummariesRef.doc(date).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return DailySummaryModel.fromMap(snap.data()!, snap.id);
    });
  }

  Stream<List<DailySummaryModel>> watchRecentDailySummaries({int limit = 30}) {
    return _dailySummariesRef
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => DailySummaryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ==========================================
  // STOCK MOVEMENTS & AUDIT (SPARK-OPTIMIZED)
  // ==========================================

  Stream<List<StockMovementModel>> watchStockMovements({String? productId, int limit = 40}) {
    Query<Map<String, dynamic>> query = _stockMovementsRef.orderBy('createdAt', descending: true);
    if (productId != null) {
      query = query.where('productId', isEqualTo: productId);
    }
    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => StockMovementModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ==========================================
  // VENDORS & STOCK PURCHASES
  // ==========================================

  Stream<List<VendorModel>> watchVendors() {
    return _vendorsRef.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => VendorModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addVendor(VendorModel vendor) async {
    final ref = _vendorsRef.doc(vendor.vendorId.isEmpty ? null : vendor.vendorId);
    final toSave = VendorModel(
      vendorId: ref.id,
      vendorName: vendor.vendorName,
      phoneNumber: vendor.phoneNumber,
      address: vendor.address,
      companyName: vendor.companyName,
      notes: vendor.notes,
      status: vendor.status,
      createdAt: vendor.createdAt,
    );
    await ref.set(toSave.toMap());
  }

  Future<void> updateVendor(VendorModel vendor) async {
    await _vendorsRef.doc(vendor.vendorId).update(vendor.toMap());
  }

  Future<void> archiveVendor(String vendorId) async {
    await _vendorsRef.doc(vendorId).update({'status': 'ARCHIVED'});
  }

  Stream<List<PurchaseModel>> watchPurchases({int limit = 50}) {
    return _purchasesRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PurchaseModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> recordStockPurchase({
    required String vendorId,
    required String vendorName,
    required String productId,
    required String productName,
    required String productType,
    required double quantity,
    required String unit,
    required double unitPrice,
    required double totalAmount,
    required String paymentMethod, // CASH, ONLINE, CREDIT
    required String notes,
    required String user,
  }) async {
    await _firestore.runTransaction((tx) async {
      final prodRef = _productsRef.doc(productId);
      final prodSnap = await tx.get(prodRef);
      if (!prodSnap.exists) throw Exception('Product $productId does not exist.');

      final curStock = (prodSnap.data()!['availableQuantity'] as num?)?.toDouble() ?? 0.0;
      final curPurchased = (prodSnap.data()!['totalPurchased'] as num?)?.toDouble() ?? 0.0;

      // 1. Update product stock and vendor price snapshot
      tx.update(prodRef, {
        'availableQuantity': curStock + quantity,
        'totalPurchased': curPurchased + quantity,
        'vendorPricePerUnit': unitPrice,
        'vendorId': vendorId,
        'updatedAt': Timestamp.now(),
      });

      // 2. Generate PO invoice number
      final now = DateTime.now();
      final dateStr = now.toIso8601String().substring(0, 10);
      final invoiceSeq = now.millisecondsSinceEpoch.toString().substring(7);
      final invoiceNumber = 'PO-$invoiceSeq';

      // 3. Record stock movement
      final movementRef = _stockMovementsRef.doc();
      final movement = StockMovementModel(
        movementId: movementRef.id,
        productId: productId,
        productName: productName,
        movementType: AppConstants.movementPurchase,
        quantity: quantity, // positive for stock in
        unit: unit,
        referenceId: 'PO #$invoiceNumber: $notes',
        date: dateStr,
        createdBy: user,
        createdAt: now,
      );
      tx.set(movementRef, movement.toMap());

      // 4. Save Purchase record
      final purchaseRef = _purchasesRef.doc();
      final purchase = PurchaseModel(
        purchaseId: purchaseRef.id,
        invoiceNumber: invoiceNumber,
        vendorId: vendorId,
        vendorName: vendorName,
        purchaseDate: dateStr,
        items: [
          PurchaseItemModel(
            productId: productId,
            productName: productName,
            productType: productType,
            quantity: quantity,
            unit: unit,
            purchasePricePerUnit: unitPrice,
            totalCost: totalAmount,
          ),
        ],
        totalAmount: totalAmount,
        paymentStatus: paymentMethod == 'CREDIT' ? 'CREDIT' : 'PAID',
        paymentMethod: paymentMethod,
        notes: notes,
        createdBy: user,
        createdAt: now,
      );
      tx.set(purchaseRef, purchase.toMap());

      // 5. If paid from shop Cash or Bank, log financial expense entry
      if (paymentMethod == AppConstants.paymentCash || paymentMethod == AppConstants.paymentOnline) {
        final accountRef = _accountEntriesRef.doc();
        final accountEntry = AccountEntryModel(
          entryId: accountRef.id,
          date: dateStr,
          transactionType: AppConstants.accountExpense,
          referenceId: purchaseRef.id,
          cashAmount: paymentMethod == AppConstants.paymentCash ? -totalAmount : 0.0,
          onlineAmount: paymentMethod == AppConstants.paymentOnline ? -totalAmount : 0.0,
          description: 'Stock Purchase PO #$invoiceNumber from $vendorName ($productName)',
          createdBy: user,
          createdAt: now,
        );
        tx.set(accountRef, accountEntry.toMap());
      }
    });
  }

  // ==========================================
  // BULK CSV PRODUCT IMPORT (SPARK CHUNKED BATCH)
  // ==========================================

  Future<int> batchImportProducts(List<ProductModel> products) async {
    if (products.isEmpty) return 0;

    int totalImported = 0;
    // Chunk in batches of 400 (well within the 500 limit)
    for (int i = 0; i < products.length; i += 400) {
      final end = (i + 400 < products.length) ? i + 400 : products.length;
      final chunk = products.sublist(i, end);
      final batch = _firestore.batch();

      for (final product in chunk) {
        final docRef = _productsRef.doc(product.productId.isEmpty ? null : product.productId);
        final modelToSave = product.copyWith(productId: docRef.id);
        batch.set(docRef, modelToSave.toMap());
      }

      await batch.commit();
      totalImported += chunk.length;
    }

    return totalImported;
  }


}

