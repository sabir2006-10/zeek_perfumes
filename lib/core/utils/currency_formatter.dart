import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    locale: 'en_IN',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormatter = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    locale: 'en_IN',
    decimalDigits: 0,
  );

  /// Formats double amount to standard Indian currency display: e.g. ₹1,250.00
  static String format(double amount) {
    return _formatter.format(amount);
  }

  /// Compact formatting without decimals if exact integer
  static String formatSmart(double amount) {
    if (amount % 1 == 0) {
      return _compactFormatter.format(amount);
    }
    return _formatter.format(amount);
  }

  /// Converts paise (integer) to rupees (double)
  static double paiseToRupees(int paise) {
    return paise / 100.0;
  }

  /// Converts rupees (double) to paise (integer) without floating point imprecision
  static int rupeesToPaise(double rupees) {
    return (rupees * 100).round();
  }
}

