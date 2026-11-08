import 'package:csv/csv.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/product_model.dart';

enum CsvRowStatus {
  valid,
  duplicateSku,
  invalid,
}

class CsvProductRow {
  final int rowNumber;
  final String productCode;
  final String productName;
  final String category;
  final String productType;
  final String unit;
  final double availableQuantity;
  final double vendorPricePerUnit;
  final double sellingPricePerUnit;
  final double lowStockThreshold;
  final String vendorId;
  final CsvRowStatus status;
  final String? errorMessage;

  CsvProductRow({
    required this.rowNumber,
    required this.productCode,
    required this.productName,
    required this.category,
    required this.productType,
    required this.unit,
    required this.availableQuantity,
    required this.vendorPricePerUnit,
    required this.sellingPricePerUnit,
    required this.lowStockThreshold,
    this.vendorId = '',
    required this.status,
    this.errorMessage,
  });

  bool get isValid => status == CsvRowStatus.valid;
  bool get isDuplicate => status == CsvRowStatus.duplicateSku;

  ProductModel toProductModel() {
    final now = DateTime.now();
    return ProductModel(
      productId: '',
      productName: productName,
      normalizedName: productName.toLowerCase(),
      productCode: productCode,
      productType: productType,
      category: category,
      unit: unit,
      vendorId: vendorId,
      availableQuantity: availableQuantity,
      totalPurchased: availableQuantity,
      vendorPricePerUnit: vendorPricePerUnit,
      sellingPricePerUnit: sellingPricePerUnit,
      lowStockThreshold: lowStockThreshold,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class CsvImportResult {
  final List<CsvProductRow> rows;
  final int validCount;
  final int duplicateCount;
  final int errorCount;

  CsvImportResult({
    required this.rows,
    required this.validCount,
    required this.duplicateCount,
    required this.errorCount,
  });
}

class CsvInventoryService {
  CsvInventoryService._();

  static const List<String> csvHeaders = [
    'Product Code',
    'Product Name',
    'Category',
    'Product Type',
    'Unit',
    'Available Stock',
    'Cost Price',
    'Selling Price',
    'Low Stock Alert',
    'Vendor ID',
  ];

  /// Generates a standardized template CSV for bulk inventory uploads
  static String generateTemplateCsv() {
    final List<List<dynamic>> rows = [
      csvHeaders,
      [
        'OIL-OUD-101',
        'Cambodi Royal Special',
        'Pure Dehn Al Oud',
        'OIL',
        'ml',
        250.0,
        150.0,
        320.0,
        25.0,
        'vendor_al_haramain',
      ],
      [
        'NON-SPR-201',
        'Zeek Velvet Rose EDP 100ml',
        'Perfume Sprays',
        'NON_OIL',
        'piece',
        50.0,
        400.0,
        950.0,
        10.0,
        'vendor_ajmal',
      ],
    ];

    return const ListToCsvConverter().convert(rows);
  }

  /// Exports an entire list of products to CSV format
  static String exportProductsToCsv(List<ProductModel> products) {
    final List<List<dynamic>> rows = [csvHeaders];

    for (final p in products) {
      rows.add([
        p.productCode,
        p.productName,
        p.category,
        p.productType,
        p.unit,
        p.availableQuantity,
        p.vendorPricePerUnit,
        p.sellingPricePerUnit,
        p.lowStockThreshold,
        p.vendorId,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Parses CSV string and validates in-memory against already-cached SKUs
  /// (Zero Firestore reads on Spark Plan!)
  static CsvImportResult parseAndValidateCsv({
    required String csvContent,
    required Map<String, ProductModel> existingProductsByCode,
  }) {
    final List<List<dynamic>> parsedRows =
        const CsvToListConverter(shouldParseNumbers: false).convert(csvContent);

    if (parsedRows.isEmpty) {
      return CsvImportResult(rows: [], validCount: 0, duplicateCount: 0, errorCount: 0);
    }

    // Skip header row if present
    final startIndex = (parsedRows.first.isNotEmpty &&
            parsedRows.first.first.toString().toLowerCase().contains('code'))
        ? 1
        : 0;

    final List<CsvProductRow> validatedRows = [];
    final Set<String> fileSeenCodes = {};
    int valid = 0;
    int duplicates = 0;
    int errors = 0;

    for (int i = startIndex; i < parsedRows.length; i++) {
      final row = parsedRows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue;
      }

      final rowNum = i + 1;
      final code = (row.isNotEmpty ? row[0].toString() : '').trim();
      final name = (row.length > 1 ? row[1].toString() : '').trim();
      final category = (row.length > 2 ? row[2].toString() : 'General').trim();
      String type = (row.length > 3 ? row[3].toString() : 'OIL').trim().toUpperCase();
      String unit = (row.length > 4 ? row[4].toString() : 'ml').trim().toLowerCase();
      final stockStr = row.length > 5 ? row[5].toString().trim() : '0';
      final costStr = row.length > 6 ? row[6].toString().trim() : '0';
      final sellStr = row.length > 7 ? row[7].toString().trim() : '0';
      final alertStr = row.length > 8 ? row[8].toString().trim() : '10';
      final vendorId = row.length > 9 ? row[9].toString().trim() : '';

      // Validation checks
      String? errorMsg;
      CsvRowStatus status = CsvRowStatus.valid;

      if (code.isEmpty) {
        errorMsg = 'Missing Product Code / SKU';
        status = CsvRowStatus.invalid;
      } else if (name.isEmpty) {
        errorMsg = 'Missing Product Name';
        status = CsvRowStatus.invalid;
      } else if (fileSeenCodes.contains(code.toUpperCase())) {
        errorMsg = 'Duplicate SKU in this CSV file';
        status = CsvRowStatus.invalid;
      } else if (existingProductsByCode.containsKey(code.toUpperCase())) {
        status = CsvRowStatus.duplicateSku;
        errorMsg = 'SKU already exists in shop inventory';
      }

      // Type & Unit validation
      if (type != AppConstants.typeOil && type != AppConstants.typeNonOil) {
        if (type == 'NON-OIL' || type == 'NONOIL') {
          type = AppConstants.typeNonOil;
        } else {
          type = AppConstants.typeOil;
        }
      }

      if (type == AppConstants.typeOil && unit != AppConstants.unitMl) {
        unit = AppConstants.unitMl;
      } else if (type == AppConstants.typeNonOil && unit != AppConstants.unitPiece) {
        unit = AppConstants.unitPiece;
      }

      final stock = double.tryParse(stockStr) ?? -1;
      final cost = double.tryParse(costStr) ?? -1;
      final sell = double.tryParse(sellStr) ?? -1;
      final alert = double.tryParse(alertStr) ?? 10.0;

      if (status == CsvRowStatus.valid && (stock < 0 || cost < 0 || sell <= 0)) {
        errorMsg = 'Stock, Cost or Selling Price must be positive valid numbers';
        status = CsvRowStatus.invalid;
      }

      if (type == AppConstants.typeNonOil && stock % 1 != 0) {
        errorMsg = 'Non-Oil pieces must be whole integers';
        status = CsvRowStatus.invalid;
      }

      if (status == CsvRowStatus.valid) {
        valid++;
        fileSeenCodes.add(code.toUpperCase());
      } else if (status == CsvRowStatus.duplicateSku) {
        duplicates++;
        fileSeenCodes.add(code.toUpperCase());
      } else {
        errors++;
      }

      validatedRows.add(
        CsvProductRow(
          rowNumber: rowNum,
          productCode: code,
          productName: name,
          category: category,
          productType: type,
          unit: unit,
          availableQuantity: stock < 0 ? 0.0 : stock,
          vendorPricePerUnit: cost < 0 ? 0.0 : cost,
          sellingPricePerUnit: sell < 0 ? 0.0 : sell,
          lowStockThreshold: alert,
          vendorId: vendorId,
          status: status,
          errorMessage: errorMsg,
        ),
      );
    }

    return CsvImportResult(
      rows: validatedRows,
      validCount: valid,
      duplicateCount: duplicates,
      errorCount: errors,
    );
  }
}

