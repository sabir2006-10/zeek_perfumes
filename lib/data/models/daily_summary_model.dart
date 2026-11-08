import 'package:cloud_firestore/cloud_firestore.dart';

class DailySummaryModel {
  final String date; // YYYY-MM-DD
  final double openingCashBalance;
  final double openingOnlineBalance;
  final double cashSales;
  final double onlineSales;
  final double totalSales;
  final int totalTransactions;
  final double cashExpenses;
  final double onlineExpenses;
  final double totalExpenses;
  final double cashDepositedToBank;
  final double cashDiscrepancy; // cash over (+) or cash short (-)
  final double closingCashBalance;
  final double closingOnlineBalance;
  final bool isClosed;
  final String? closedBy;
  final DateTime? closedAt;
  final String? notes;

  DailySummaryModel({
    required this.date,
    this.openingCashBalance = 0.0,
    this.openingOnlineBalance = 0.0,
    this.cashSales = 0.0,
    this.onlineSales = 0.0,
    this.totalSales = 0.0,
    this.totalTransactions = 0,
    this.cashExpenses = 0.0,
    this.onlineExpenses = 0.0,
    this.totalExpenses = 0.0,
    this.cashDepositedToBank = 0.0,
    this.cashDiscrepancy = 0.0,
    this.closingCashBalance = 0.0,
    this.closingOnlineBalance = 0.0,
    this.isClosed = false,
    this.closedBy,
    this.closedAt,
    this.notes,
  });

  double get expectedClosingCash =>
      openingCashBalance + cashSales - cashExpenses - cashDepositedToBank;

  double get expectedClosingBank =>
      openingOnlineBalance + onlineSales - onlineExpenses + cashDepositedToBank;

  double get grandClosingBalance => closingCashBalance + closingOnlineBalance;
  double get grandExpectedBalance => expectedClosingCash + expectedClosingBank;

  double get netCashFlow => cashSales - cashExpenses - cashDepositedToBank;
  double get netOnlineFlow => onlineSales - onlineExpenses + cashDepositedToBank;
  double get netTotalFlow => totalSales - totalExpenses;

  DailySummaryModel copyWith({
    String? date,
    double? openingCashBalance,
    double? openingOnlineBalance,
    double? cashSales,
    double? onlineSales,
    double? totalSales,
    int? totalTransactions,
    double? cashExpenses,
    double? onlineExpenses,
    double? totalExpenses,
    double? cashDepositedToBank,
    double? cashDiscrepancy,
    double? closingCashBalance,
    double? closingOnlineBalance,
    bool? isClosed,
    String? closedBy,
    DateTime? closedAt,
    String? notes,
  }) {
    return DailySummaryModel(
      date: date ?? this.date,
      openingCashBalance: openingCashBalance ?? this.openingCashBalance,
      openingOnlineBalance: openingOnlineBalance ?? this.openingOnlineBalance,
      cashSales: cashSales ?? this.cashSales,
      onlineSales: onlineSales ?? this.onlineSales,
      totalSales: totalSales ?? this.totalSales,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      cashExpenses: cashExpenses ?? this.cashExpenses,
      onlineExpenses: onlineExpenses ?? this.onlineExpenses,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      cashDepositedToBank: cashDepositedToBank ?? this.cashDepositedToBank,
      cashDiscrepancy: cashDiscrepancy ?? this.cashDiscrepancy,
      closingCashBalance: closingCashBalance ?? this.closingCashBalance,
      closingOnlineBalance: closingOnlineBalance ?? this.closingOnlineBalance,
      isClosed: isClosed ?? this.isClosed,
      closedBy: closedBy ?? this.closedBy,
      closedAt: closedAt ?? this.closedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'date': date,
      'openingCashBalance': openingCashBalance,
      'openingOnlineBalance': openingOnlineBalance,
      'cashSales': cashSales,
      'onlineSales': onlineSales,
      'totalSales': totalSales,
      'totalTransactions': totalTransactions,
      'cashExpenses': cashExpenses,
      'onlineExpenses': onlineExpenses,
      'totalExpenses': totalExpenses,
      'cashDepositedToBank': cashDepositedToBank,
      'cashDiscrepancy': cashDiscrepancy,
      'closingCashBalance': closingCashBalance,
      'closingOnlineBalance': closingOnlineBalance,
      'isClosed': isClosed,
    };
    if (closedBy != null && closedBy!.trim().isNotEmpty) {
      map['closedBy'] = closedBy!.trim();
    }
    if (closedAt != null) {
      map['closedAt'] = Timestamp.fromDate(closedAt!);
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      map['notes'] = notes!.trim();
    }
    return map;
  }

  factory DailySummaryModel.fromMap(Map<String, dynamic> map, String date) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return DailySummaryModel(
      date: date,
      openingCashBalance: (map['openingCashBalance'] as num?)?.toDouble() ?? 0.0,
      openingOnlineBalance: (map['openingOnlineBalance'] as num?)?.toDouble() ?? 0.0,
      cashSales: (map['cashSales'] as num?)?.toDouble() ?? 0.0,
      onlineSales: (map['onlineSales'] as num?)?.toDouble() ?? 0.0,
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: (map['totalTransactions'] as num?)?.toInt() ?? 0,
      cashExpenses: (map['cashExpenses'] as num?)?.toDouble() ?? 0.0,
      onlineExpenses: (map['onlineExpenses'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      cashDepositedToBank: (map['cashDepositedToBank'] as num?)?.toDouble() ?? 0.0,
      cashDiscrepancy: (map['cashDiscrepancy'] as num?)?.toDouble() ?? 0.0,
      closingCashBalance: (map['closingCashBalance'] as num?)?.toDouble() ?? 0.0,
      closingOnlineBalance: (map['closingOnlineBalance'] as num?)?.toDouble() ?? 0.0,
      isClosed: map['isClosed'] as bool? ?? false,
      closedBy: map['closedBy'] as String?,
      closedAt: parseDate(map['closedAt']),
      notes: map['notes'] as String?,
    );
  }
}
