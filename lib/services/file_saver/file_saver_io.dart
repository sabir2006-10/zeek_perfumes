import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<bool> saveOrDownloadFile({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  return await Printing.sharePdf(
    bytes: Uint8List.fromList(bytes),
    filename: fileName,
  );
}

