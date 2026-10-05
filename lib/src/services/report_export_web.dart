import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String> exportProviderReport(String csv, String filename) async {
  final blob = web.Blob(
    ['\uFEFF$csv'.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return 'CSV download requested: $filename';
}
