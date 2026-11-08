import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseItemModel {
  final String productId;
  final String productName;
  final String productType;
  final double quantity;
  final String unit;
  final double purchasePricePerUnit;
  final double totalCost;

  PurchaseItemModel({
    required this.productId,
    required this.productName,
    required this.productType,
    required this.quantity,
    required this.unit,
    required this.purchasePricePerUnit,
    required this.totalCost,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productType': productType,
      'quantity': quantity,
      'unit': unit,
      'purchasePricePerUnit': purchasePricePerUnit,
      'totalCost': totalCost,
    };
  }

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productType: map['productType'] as String? ?? 'OIL',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'ml',
      purchasePricePerUnit: (map['purchasePricePerUnit'] as num?)?.toDouble() ?? 0.0,
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PurchaseModel {
  final String purchaseId;
  final String invoiceNumber;
  final String vendorId;
  final String vendorName;
  final String purchaseDate; // YYYY-MM-DD
  final List<PurchaseItemModel> items;
  final double totalAmount;
  final String paymentStatus; // PAID, CREDIT
  final String paymentMethod; // CASH, ONLINE, CREDIT
  final String notes;
  final String createdBy;
  final DateTime createdAt;

  PurchaseModel({
    required this.purchaseId,
    required this.invoiceNumber,
    required this.vendorId,
    required this.vendorName,
    required this.purchaseDate,
    required this.items,
    required this.totalAmount,
    this.paymentStatus = 'PAID',
    this.paymentMethod = 'ONLINE',
    this.notes = '',
    this.createdBy = 'Admin',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'purchaseId': purchaseId,
      'invoiceNumber': invoiceNumber,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'purchaseDate': purchaseDate,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => PurchaseItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return PurchaseModel(
      purchaseId: id,
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      vendorId: map['vendorId'] as String? ?? '',
      vendorName: map['vendorName'] as String? ?? 'Unknown Vendor',
      purchaseDate: map['purchaseDate'] as String? ?? '',
      items: itemsList,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['paymentStatus'] as String? ?? 'PAID',
      paymentMethod: map['paymentMethod'] as String? ?? 'ONLINE',
      notes: map['notes'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? 'Admin',
      createdAt: parseDate(map['createdAt']),
    );
  }
}

