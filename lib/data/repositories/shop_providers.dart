import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/account_entry_model.dart';
import '../models/vendor_model.dart';
import '../models/stock_movement_model.dart';
import '../models/purchase_model.dart';
import '../models/daily_summary_model.dart';
import 'shop_repository.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository();
});

final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchProducts();
});

final oilProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchProducts(productType: AppConstants.typeOil);
});

final nonOilProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchProducts(productType: AppConstants.typeNonOil);
});

final salesStreamProvider = StreamProvider<List<SaleModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchSales();
});

final accountEntriesStreamProvider = StreamProvider<List<AccountEntryModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchAccountEntries();
});

final vendorsStreamProvider = StreamProvider<List<VendorModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchVendors();
});

final purchasesStreamProvider = StreamProvider<List<PurchaseModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchPurchases();
});

final stockMovementsStreamProvider = StreamProvider<List<StockMovementModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchStockMovements();
});

// Spark plan optimized: fetch movements only for targeted product on demand
final stockMovementsForProductProvider =
    StreamProvider.family<List<StockMovementModel>, String>((ref, productId) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchStockMovements(productId: productId, limit: 30);
});

// Spark plan optimized: derived in-memory from productsStreamProvider without additional Firestore read!
final vendorProductsProvider =
    Provider.family<List<ProductModel>, String>((ref, vendorId) {
  final allProducts = ref.watch(productsStreamProvider).valueOrNull ?? [];
  return allProducts.where((p) => p.vendorId == vendorId).toList();
});

final recentSalesProvider = StreamProvider<List<SaleModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchSales(limit: 10);
});

final todaySummaryStreamProvider = StreamProvider<DailySummaryModel?>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return repo.watchDailySummary(today);
});

final recentDailySummariesProvider = StreamProvider<List<DailySummaryModel>>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.watchRecentDailySummaries(limit: 30);
});

// ==========================================
// ACTIVE POS CART STATE (PHASE 3 ENHANCED)
// ==========================================

class CartState {
  final List<SaleItemModel> items;
  final String discountType; // 'FLAT' or 'PERCENT'
  final double discountValue;
  final String customerName;
  final String customerPhone;
  final String orderNotes;
  final String paymentType; // CASH, ONLINE, SPLIT
  final double customCashAmount;
  final double customOnlineAmount;
  final bool isProcessing;
  final String? errorMessage;
  final SaleModel? lastCompletedSale;

  const CartState({
    this.items = const [],
    this.discountType = 'FLAT',
    this.discountValue = 0.0,
    this.customerName = '',
    this.customerPhone = '',
    this.orderNotes = '',
    this.paymentType = AppConstants.paymentCash,
    this.customCashAmount = 0.0,
    this.customOnlineAmount = 0.0,
    this.isProcessing = false,
    this.errorMessage,
    this.lastCompletedSale,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get discountAmount {
    if (discountType == 'PERCENT') {
      return (subtotal * (discountValue / 100.0)).clamp(0.0, subtotal);
    }
    return discountValue.clamp(0.0, subtotal);
  }

  double get grandTotal => (subtotal - discountAmount).clamp(0.0, double.infinity);

  double get cashAmount {
    if (paymentType == AppConstants.paymentCash) return grandTotal;
    if (paymentType == AppConstants.paymentOnline) return 0.0;
    return customCashAmount;
  }

  double get onlineAmount {
    if (paymentType == AppConstants.paymentOnline) return grandTotal;
    if (paymentType == AppConstants.paymentCash) return 0.0;
    return customOnlineAmount;
  }

  bool get isPaymentValid {
    if (items.isEmpty) return false;
    if (paymentType == AppConstants.paymentCash || paymentType == AppConstants.paymentOnline) {
      return true;
    }
    return (cashAmount + onlineAmount - grandTotal).abs() < 0.01;
  }

  CartState copyWith({
    List<SaleItemModel>? items,
    String? discountType,
    double? discountValue,
    String? customerName,
    String? customerPhone,
    String? orderNotes,
    String? paymentType,
    double? customCashAmount,
    double? customOnlineAmount,
    bool? isProcessing,
    String? errorMessage,
    SaleModel? lastCompletedSale,
    bool clearError = false,
    bool clearSale = false,
  }) {
    return CartState(
      items: items ?? this.items,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderNotes: orderNotes ?? this.orderNotes,
      paymentType: paymentType ?? this.paymentType,
      customCashAmount: customCashAmount ?? this.customCashAmount,
      customOnlineAmount: customOnlineAmount ?? this.customOnlineAmount,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastCompletedSale: clearSale ? null : (lastCompletedSale ?? this.lastCompletedSale),
    );
  }
}

class CartNotifier extends StateNotifier<CartState> {
  final ShopRepository _repository;

  CartNotifier(this._repository) : super(const CartState());

  ProductModel? quickAddBySku(String skuQuery, List<ProductModel> catalog) {
    final query = skuQuery.trim().toUpperCase();
    if (query.isEmpty) return null;

    final product = catalog.where((p) => p.productCode.toUpperCase() == query).firstOrNull ??
        catalog.where((p) => p.productName.toUpperCase().contains(query)).firstOrNull;

    if (product != null) {
      final defaultQty = product.isOil ? 10.0 : 1.0;
      addOrUpdateProduct(product, defaultQty);
    }
    return product;
  }

  void addOrUpdateProduct(ProductModel product, double quantity) {
    if (quantity <= 0) return;

    final existingIndex = state.items.indexWhere((i) => i.productId == product.productId);
    final unitPrice = product.sellingPricePerUnit;

    if (existingIndex >= 0) {
      final updatedList = List<SaleItemModel>.from(state.items);
      final existing = updatedList[existingIndex];
      final newQuantity = existing.quantity + quantity;

      if (newQuantity > product.availableQuantity) {
        state = state.copyWith(
          errorMessage: 'Cannot add more. Available stock for "${product.productName}" is only ${product.availableQuantity} ${product.unit}.',
        );
        return;
      }

      updatedList[existingIndex] = SaleItemModel(
        productId: product.productId,
        productName: product.productName,
        productType: product.productType,
        quantity: newQuantity,
        unit: product.unit,
        unitPrice: unitPrice,
        unitCostAtSale: product.vendorPricePerUnit,
        totalPrice: newQuantity * unitPrice,
      );
      state = state.copyWith(items: updatedList, clearError: true);
    } else {
      if (quantity > product.availableQuantity) {
        state = state.copyWith(
          errorMessage: 'Requested quantity exceeds available stock (${product.availableQuantity} ${product.unit}).',
        );
        return;
      }

      final newItem = SaleItemModel(
        productId: product.productId,
        productName: product.productName,
        productType: product.productType,
        quantity: quantity,
        unit: product.unit,
        unitPrice: unitPrice,
        unitCostAtSale: product.vendorPricePerUnit,
        totalPrice: quantity * unitPrice,
      );
      state = state.copyWith(items: [...state.items, newItem], clearError: true);
    }
  }

  void updateItemQuantity(int index, double newQuantity, double maxAvailable) {
    if (index < 0 || index >= state.items.length) return;
    if (newQuantity <= 0) {
      removeItem(index);
      return;
    }
    if (newQuantity > maxAvailable) {
      state = state.copyWith(
        errorMessage: 'Quantity exceeds available stock ($maxAvailable).',
      );
      return;
    }

    final updatedList = List<SaleItemModel>.from(state.items);
    final item = updatedList[index];
    updatedList[index] = SaleItemModel(
      productId: item.productId,
      productName: item.productName,
      productType: item.productType,
      quantity: newQuantity,
      unit: item.unit,
      unitPrice: item.unitPrice,
      unitCostAtSale: item.unitCostAtSale,
      totalPrice: newQuantity * item.unitPrice,
    );
    state = state.copyWith(items: updatedList, clearError: true);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    final updatedList = List<SaleItemModel>.from(state.items)..removeAt(index);
    state = state.copyWith(items: updatedList);
  }

  void setDiscount(double value, {String type = 'FLAT'}) {
    state = state.copyWith(
      discountValue: value.clamp(0.0, type == 'PERCENT' ? 100.0 : state.subtotal),
      discountType: type,
    );
  }

  void setCustomerDetails({String? name, String? phone}) {
    state = state.copyWith(
      customerName: name ?? state.customerName,
      customerPhone: phone ?? state.customerPhone,
    );
  }

  void setNotes(String notes) {
    state = state.copyWith(orderNotes: notes);
  }

  void setPaymentType(String type) {
    state = state.copyWith(
      paymentType: type,
      customCashAmount: type == AppConstants.paymentSplit ? state.grandTotal / 2 : 0.0,
      customOnlineAmount: type == AppConstants.paymentSplit ? state.grandTotal / 2 : 0.0,
    );
  }

  void setSplitAmounts(double cash, double online) {
    state = state.copyWith(
      customCashAmount: cash,
      customOnlineAmount: online,
    );
  }

  void clearCart() {
    state = const CartState();
  }

  Future<bool> checkout(String cashierName) async {
    if (!state.isPaymentValid) {
      state = state.copyWith(errorMessage: 'Please verify the payment allocation.');
      return false;
    }

    state = state.copyWith(isProcessing: true, clearError: true);
    try {
      final now = DateTime.now();
      final invoiceSeq = now.millisecondsSinceEpoch.toString().substring(7);
      final saleId = 'sale_${now.millisecondsSinceEpoch}';
      final invoiceNumber = 'INV-$invoiceSeq';
      final date = now.toIso8601String().substring(0, 10);

      final sale = SaleModel(
        saleId: saleId,
        invoiceNumber: invoiceNumber,
        date: date,
        timestamp: now,
        items: state.items,
        subtotal: state.subtotal,
        discount: state.discountAmount,
        grandTotal: state.grandTotal,
        paymentType: state.paymentType,
        cashAmount: state.cashAmount,
        onlineAmount: state.onlineAmount,
        status: 'COMPLETED',
        createdBy: cashierName,
        customerName: state.customerName.isEmpty ? null : state.customerName,
        customerPhone: state.customerPhone.isEmpty ? null : state.customerPhone,
        notes: state.orderNotes.isEmpty ? null : state.orderNotes,
        createdAt: now,
      );

      await _repository.completeSale(sale);

      state = CartState(lastCompletedSale: sale);
      return true;
    } catch (e) {
      state = state.copyWith(isProcessing: false, errorMessage: e.toString());
      return false;
    }
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return CartNotifier(repo);
});

