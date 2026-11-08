import 'package:cloud_firestore/cloud_firestore.dart';

class VendorModel {
  final String vendorId;
  final String vendorName;
  final String phoneNumber;
  final String address;
  final String companyName;
  final String notes;
  final String status; // ACTIVE, ARCHIVED
  final DateTime createdAt;

  VendorModel({
    required this.vendorId,
    required this.vendorName,
    this.phoneNumber = '',
    this.address = '',
    this.companyName = '',
    this.notes = '',
    this.status = 'ACTIVE',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'phoneNumber': phoneNumber,
      'address': address,
      'companyName': companyName,
      'notes': notes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory VendorModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return VendorModel(
      vendorId: id,
      vendorName: map['vendorName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      address: map['address'] as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'ACTIVE',
      createdAt: parseDate(map['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VendorModel &&
          runtimeType == other.runtimeType &&
          vendorId == other.vendorId;

  @override
  int get hashCode => vendorId.hashCode;
}

