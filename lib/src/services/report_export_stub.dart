import 'package:flutter/services.dart';

Future<String> exportProviderReport(String csv, String filename) async {
  await Clipboard.setData(ClipboardData(text: csv));
  return 'CSV copied. Paste it into a text file and save as $filename.';
}
