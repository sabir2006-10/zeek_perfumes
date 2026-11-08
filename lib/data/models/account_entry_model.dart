import 'package:cloud_firestore/cloud_firestore.dart';

class AccountEntryModel {
  final String entryId;
  final String date; // YYYY-MM-DD
  final String transactionType; // OPENING_BALANCE, SALE_INCOME, EXPENSE, TRANSFER, REFUND, ADJUSTMENT
  final String referenceId; // saleId, expenseId, etc.
  final double cashAmount; // positive for income/deposit, negative for expense/withdrawal
  final double onlineAmount; // positive for income/deposit, negative for expense/withdrawal
  final String description;
  final String status;
  final String createdBy;
  final DateTime createdAt;

  AccountEntryModel({
    required this.entryId,
    required this.date,
    required this.transactionType,
    required this.referenceId,
    required this.cashAmount,
    required this.onlineAmount,
    required this.description,
    this.status = 'ACTIVE',
    this.createdBy = 'Staff',
    required this.createdAt,
  });

  double get totalAmount => cashAmount + onlineAmount;
  bool get isIncome => totalAmount > 0;

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'date': date,
      'transactionType': transactionType,
      'referenceId': referenceId,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
      'description': description,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AccountEntryModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AccountEntryModel(
      entryId: id,
      date: map['date'] as String? ?? '',
      transactionType: map['transactionType'] as String? ?? 'SALE_INCOME',
      referenceId: map['referenceId'] as String? ?? '',
      cashAmount: (map['cashAmount'] as num?)?.toDouble() ?? 0.0,
      onlineAmount: (map['onlineAmount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'ACTIVE',
      createdBy: map['createdBy'] as String? ?? 'Staff',
      createdAt: parseDate(map['createdAt']),
    );
  }
}

