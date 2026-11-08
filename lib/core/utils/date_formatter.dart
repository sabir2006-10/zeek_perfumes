import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _displayDate = DateFormat('dd MMM yyyy');
  static final DateFormat _displayDateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _displayTime = DateFormat('hh:mm a');
  static final DateFormat _storageDate = DateFormat('yyyy-MM-dd');

  static final DateFormat _displayMonth = DateFormat('MMM yyyy');

  static String formatDate(DateTime dateTime) {
    return _displayDate.format(dateTime);
  }

  static String formatMonth(DateTime dateTime) {
    return _displayMonth.format(dateTime);
  }

  static String formatDateTime(DateTime dateTime) {
    return _displayDateTime.format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return _displayTime.format(dateTime);
  }

  static String formatStorageDate(DateTime dateTime) {
    return _storageDate.format(dateTime);
  }

  static DateTime parseStorageDate(String dateString) {
    return _storageDate.parse(dateString);
  }
}

