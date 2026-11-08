import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String expenseId;
  final String date; // YYYY-MM-DD
  final String reason;
  final String category;
  final double totalAmount;
  final String paymentMethod; // CASH, ONLINE, SPLIT
  final double cashAmount;
  final double onlineAmount;
  final String description;
  final String status;
  final String createdBy;
  final DateTime createdAt;

  ExpenseModel({
    required this.expenseId,
    required this.date,
    required this.reason,
    required this.category,
    required this.totalAmount,
    required this.paymentMethod,
    required this.cashAmount,
    required this.onlineAmount,
    this.description = '',
    this.status = 'ACTIVE',
    this.createdBy = 'Staff',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'date': date,
      'reason': reason,
      'category': category,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
      'description': description,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ExpenseModel(
      expenseId: id,
      date: map['date'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'CASH',
      cashAmount: (map['cashAmount'] as num?)?.toDouble() ?? 0.0,
      onlineAmount: (map['onlineAmount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'ACTIVE',
      createdBy: map['createdBy'] as String? ?? 'Staff',
      createdAt: parseDate(map['createdAt']),
    );
  }
}

