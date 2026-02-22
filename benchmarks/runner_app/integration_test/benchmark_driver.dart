import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outputPath = Platform.environment['BENCHMARK_OUTPUT'];

  await integrationDriver(
    responseDataCallback: (data) async {
      if (outputPath != null && outputPath.isNotEmpty && data != null) {
        final file = File(outputPath)..createSync(recursive: true);
        final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
        file.writeAsStringSync(prettyJson);
      }
    },
  );
}
