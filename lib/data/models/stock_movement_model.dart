import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovementModel {
  final String movementId;
  final String productId;
  final String productName;
  final String movementType;
  final double quantity; // signed quantity: positive for incoming, negative for outgoing
  final String unit;
  final String referenceId; // saleId, purchaseId, or adjustment notes
  final String date; // YYYY-MM-DD
  final String createdBy;
  final DateTime createdAt;

  StockMovementModel({
    required this.movementId,
    required this.productId,
    this.productName = '',
    required this.movementType,
    required this.quantity,
    required this.unit,
    required this.referenceId,
    required this.date,
    this.createdBy = 'Staff',
    required this.createdAt,
  });

  bool get isIncoming => quantity > 0;
  bool get isOutgoing => quantity < 0;

  Map<String, dynamic> toMap() {
    return {
      'movementId': movementId,
      'productId': productId,
      'productName': productName,
      'movementType': movementType,
      'quantity': quantity,
      'unit': unit,
      'referenceId': referenceId,
      'date': date,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory StockMovementModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return StockMovementModel(
      movementId: id,
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      movementType: map['movementType'] as String? ?? 'STOCK_ADJUSTMENT',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'ml',
      referenceId: map['referenceId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? 'Staff',
      createdAt: parseDate(map['createdAt']),
    );
  }
}

