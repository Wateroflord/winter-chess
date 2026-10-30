import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final f = File('screenshots/$name.png');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(bytes);
      return true;
    },
    responseDataCallback: (Map<String, dynamic>? data) async {
      final f = File('screenshots/report.json');
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(data ?? {}));
    },
  );
}
