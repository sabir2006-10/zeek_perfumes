import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItemModel {
  final String productId;
  final String productName;
  final String productType;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double unitCostAtSale;
  final double totalPrice;

  SaleItemModel({
    required this.productId,
    required this.productName,
    required this.productType,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.unitCostAtSale = 0.0,
    required this.totalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productType': productType,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'unitCostAtSale': unitCostAtSale,
      'totalPrice': totalPrice,
    };
  }

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productType: map['productType'] as String? ?? 'OIL',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'ml',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      unitCostAtSale: (map['unitCostAtSale'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SaleModel {
  final String saleId;
  final String invoiceNumber;
  final String date; // YYYY-MM-DD
  final DateTime timestamp;
  final List<SaleItemModel> items;
  final double subtotal;
  final double discount;
  final double grandTotal;
  final String paymentType; // CASH, ONLINE, SPLIT
  final double cashAmount;
  final double onlineAmount;
  final String status; // COMPLETED, VOIDED, REFUNDED
  final String createdBy;
  final String? customerName;
  final String? customerPhone;
  final String? notes;
  final DateTime createdAt;

  SaleModel({
    required this.saleId,
    required this.invoiceNumber,
    required this.date,
    required this.timestamp,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.grandTotal,
    required this.paymentType,
    required this.cashAmount,
    required this.onlineAmount,
    this.status = 'COMPLETED',
    this.createdBy = 'Staff',
    this.customerName,
    this.customerPhone,
    this.notes,
    required this.createdAt,
  });

  bool get isCompleted => status == 'COMPLETED';
  bool get isVoided => status == 'VOIDED';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'saleId': saleId,
      'invoiceNumber': invoiceNumber,
      'date': date,
      'timestamp': Timestamp.fromDate(timestamp),
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'grandTotal': grandTotal,
      'paymentType': paymentType,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (customerName != null && customerName!.trim().isNotEmpty) {
      map['customerName'] = customerName!.trim();
    }
    if (customerPhone != null && customerPhone!.trim().isNotEmpty) {
      map['customerPhone'] = customerPhone!.trim();
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      map['notes'] = notes!.trim();
    }
    return map;
  }

  factory SaleModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .map((item) => SaleItemModel.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return SaleModel(
      saleId: id,
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      date: map['date'] as String? ?? '',
      timestamp: parseDate(map['timestamp']),
      items: parsedItems,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paymentType: map['paymentType'] as String? ?? 'CASH',
      cashAmount: (map['cashAmount'] as num?)?.toDouble() ?? 0.0,
      onlineAmount: (map['onlineAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'COMPLETED',
      createdBy: map['createdBy'] as String? ?? 'Staff',
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      notes: map['notes'] as String?,
      createdAt: parseDate(map['createdAt']),
    );
  }
}

