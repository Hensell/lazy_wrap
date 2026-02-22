import 'dart:convert';
import 'dart:io';

const _defaultScenarios = <String>[
  'dynamic_chip_10k',
  'dynamic_card_50k',
  'fixed_grid_10k',
];
const _allScenarios = <String>[
  ..._defaultScenarios,
  'dynamic_card_50k_sliver_v2',
  'dynamic_card_50k_sliver_v3',
  'dynamic_chip_10k_sliver_v2',
  'dynamic_chip_10k_sliver_v3',
  'chip_compare_lazy_wrap_2k',
  'chip_compare_listview_2k',
  'chip_compare_wrap_2k',
];
const _runnerAppDir = 'benchmarks/runner_app';

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);
  final runId = _timestampId(DateTime.now().toUtc());
  final runDir = Directory('benchmarks/results/$runId')
    ..createSync(recursive: true);

  final scenarios = config.scenario != null
      ? <String>[config.scenario!]
      : _defaultScenarios;

  stdout.writeln('Benchmark run id: $runId');
  stdout.writeln('Scenarios: ${scenarios.join(', ')}');
  stdout.writeln('Device: ${config.deviceId ?? 'default'}');
  if (config.defines.isNotEmpty) {
    final defineEntries = config.defines.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final serializedDefines = defineEntries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    stdout.writeln('Extra defines: $serializedDefines');
  }

  await _ensureRunnerDependencies();

  final scenarioResults = <Map<String, dynamic>>[];

  for (final scenario in scenarios) {
    final outputPath = File('${runDir.path}/$scenario.json').absolute.path;
    stdout.writeln('\n==> Running $scenario');
    await _runFlutterDrive(
      scenario: scenario,
      outputPath: outputPath,
      deviceId: config.deviceId,
      frameBudgetMs: config.frameBudgetMs,
      defines: config.defines,
    );
    scenarioResults.add(_readResult(outputPath));
  }

  final summary = <String, Object?>{
    'run_id': runId,
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'device_id': config.deviceId,
    'frame_budget_ms': config.frameBudgetMs,
    'extra_defines': config.defines,
    'results': scenarioResults,
  };

  final summaryPath = '${runDir.path}/summary.json';
  final summaryFile = File(summaryPath);
  summaryFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(summary),
  );

  if (config.scenario == null) {
    _writeBaselineReport(
      runId: runId,
      summaryPath: summaryPath,
      results: scenarioResults,
      frameBudgetMs: config.frameBudgetMs,
      deviceId: config.deviceId,
    );
  }

  stdout.writeln('\nBenchmark summary: $summaryPath');
  if (config.scenario == null) {
    stdout.writeln('Baseline report updated: benchmarks/baseline_report.md');
  } else {
    stdout.writeln(
      'Baseline report unchanged (single-scenario run).',
    );
  }
}

void _writeBaselineReport({
  required String runId,
  required String summaryPath,
  required List<Map<String, dynamic>> results,
  required double frameBudgetMs,
  required String? deviceId,
}) {
  final highestJank = _maxBy(results, (r) => _asDouble(r['jank_percent']));
  final highestMemory = _maxBy(results, (r) => _asDouble(r['peak_memory_mb']));
  final highestBuildP95 = _maxBy(results, (r) => _asDouble(r['p95_build_ms']));
  final highestRasterP95 = _maxBy(
    results,
    (r) => _asDouble(r['p95_raster_ms']),
  );

  final rows = results
      .map((result) {
        return '| `${result['scenario']}` | ${_fmt(result['p95_build_ms'])} | '
            '${_fmt(result['p95_raster_ms'])} | ${_fmt(result['jank_percent'])}% | '
            '${_fmt(result['peak_memory_mb'])} | '
            '${_fmt(result['time_to_first_interaction_ms'])} | '
            '${result['frame_count']} |';
      })
      .join('\n');

  final report = StringBuffer()
    ..writeln('# Baseline Report (`lazy_wrap`)')
    ..writeln()
    ..writeln('## Metadata')
    ..writeln()
    ..writeln('- Run ID: `$runId`')
    ..writeln('- Fecha UTC: `${DateTime.now().toUtc().toIso8601String()}`')
    ..writeln('- Device: `${deviceId ?? 'default'}`')
    ..writeln('- Frame budget: `${frameBudgetMs.toStringAsFixed(2)} ms`')
    ..writeln('- Summary JSON: `$summaryPath`')
    ..writeln()
    ..writeln('## Resultados')
    ..writeln()
    ..writeln(
      '| Escenario | p95_build_ms | p95_raster_ms | % jank | peak_memory_mb | time_to_first_interaction_ms | frame_count |',
    )
    ..writeln('|---|---:|---:|---:|---:|---:|---:|')
    ..writeln(rows)
    ..writeln()
    ..writeln('## Conclusiones Iniciales')
    ..writeln()
    ..writeln(
      '- Mayor jank: `${highestJank['scenario']}` (${_fmt(highestJank['jank_percent'])}%).',
    )
    ..writeln(
      '- Mayor consumo de memoria: `${highestMemory['scenario']}` (${_fmt(highestMemory['peak_memory_mb'])} MB).',
    )
    ..writeln(
      '- Mayor p95 build: `${highestBuildP95['scenario']}` (${_fmt(highestBuildP95['p95_build_ms'])} ms).',
    )
    ..writeln(
      '- Mayor p95 raster: `${highestRasterP95['scenario']}` (${_fmt(highestRasterP95['p95_raster_ms'])} ms).',
    )
    ..writeln()
    ..writeln('## Hipotesis de Cuellos de Botella')
    ..writeln()
    ..writeln(
      '1. En `dynamic`, la medicion Offstage + armado de filas incrementa costo de build bajo scroll intenso.',
    )
    ..writeln(
      '2. `dynamic_card_50k` tiende a subir memoria por tamano/variedad de widgets y batching.',
    )
    ..writeln(
      '3. El costo raster crece con composicion de `Card`/`Chip` incluso con lazy rendering.',
    )
    ..writeln()
    ..writeln('## Proximos Pasos (Sprint 2)')
    ..writeln()
    ..writeln(
      '1. Hardening de asserts y estados edge-case (`itemCount`, `controller`, callbacks tardios).',
    )
    ..writeln(
      '2. Mantener este baseline como referencia para comparar cada sprint.',
    )
    ..writeln();

  File('benchmarks/baseline_report.md').writeAsStringSync(report.toString());
}

Map<String, dynamic> _maxBy(
  List<Map<String, dynamic>> values,
  double Function(Map<String, dynamic>) selector,
) {
  if (values.isEmpty) {
    throw StateError('No values to compare.');
  }
  var current = values.first;
  var currentScore = selector(current);
  for (final value in values.skip(1)) {
    final score = selector(value);
    if (score > currentScore) {
      current = value;
      currentScore = score;
    }
  }
  return current;
}

String _fmt(Object? value) => _asDouble(value).toStringAsFixed(2);

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

Future<void> _runFlutterDrive({
  required String scenario,
  required String outputPath,
  required String? deviceId,
  required double frameBudgetMs,
  required Map<String, String> defines,
}) async {
  final defineEntries = defines.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final defineArgs = defineEntries
      .map((entry) => '--dart-define=${entry.key}=${entry.value}')
      .toList();

  final arguments = <String>[
    'drive',
    '--profile',
    '--no-pub',
    '--driver=integration_test/benchmark_driver.dart',
    '--target=integration_test/benchmark_test.dart',
    '--dart-define=SCENARIO=$scenario',
    '--dart-define=FRAME_BUDGET_MS=${frameBudgetMs.toStringAsFixed(2)}',
    ...defineArgs,
    if (deviceId != null) ...['-d', deviceId],
  ];

  final process = await Process.start(
    'flutter',
    arguments,
    workingDirectory: _runnerAppDir,
    runInShell: true,
    environment: {
      ...Platform.environment,
      'BENCHMARK_OUTPUT': outputPath,
    },
  );

  final stdoutDone = process.stdout.transform(utf8.decoder).listen((chunk) {
    stdout.write('[$scenario] $chunk');
  }).asFuture<void>();

  final stderrDone = process.stderr.transform(utf8.decoder).listen((chunk) {
    stderr.write('[$scenario] $chunk');
  }).asFuture<void>();

  final code = await process.exitCode;
  await stdoutDone;
  await stderrDone;

  if (code != 0) {
    throw ProcessException('flutter', arguments, 'Exit code: $code', code);
  }
}

Future<void> _ensureRunnerDependencies() async {
  final process = await Process.start(
    'flutter',
    const ['pub', 'get'],
    workingDirectory: _runnerAppDir,
    runInShell: true,
  );

  final stdoutDone = process.stdout.transform(utf8.decoder).listen((chunk) {
    stdout.write('[runner_app] $chunk');
  }).asFuture<void>();

  final stderrDone = process.stderr.transform(utf8.decoder).listen((chunk) {
    stderr.write('[runner_app] $chunk');
  }).asFuture<void>();

  final code = await process.exitCode;
  await stdoutDone;
  await stderrDone;

  if (code != 0) {
    throw ProcessException(
      'flutter',
      const ['pub', 'get'],
      'Failed to resolve dependencies for runner app.',
      code,
    );
  }
}

Map<String, dynamic> _readResult(String outputPath) {
  final file = File(outputPath);
  if (!file.existsSync()) {
    throw StateError('Missing benchmark output: $outputPath');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected benchmark output format for $outputPath');
  }

  final requiredKeys = <String>[
    'scenario',
    'p95_build_ms',
    'p95_raster_ms',
    'jank_percent',
    'peak_memory_mb',
    'time_to_first_interaction_ms',
    'frame_count',
  ];

  for (final key in requiredKeys) {
    if (!decoded.containsKey(key)) {
      throw StateError('Output $outputPath is missing key: $key');
    }
  }

  return decoded;
}

_Config _parseArgs(List<String> args) {
  String? deviceId;
  String? scenario;
  var frameBudgetMs = 16.67;
  final defines = <String, String>{};

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      _printUsage();
      exit(0);
    }
    if (arg == '--device' && i + 1 < args.length) {
      deviceId = args[++i];
      continue;
    }
    if (arg == '--scenario' && i + 1 < args.length) {
      scenario = args[++i];
      if (!_allScenarios.contains(scenario)) {
        throw ArgumentError(
          'Unknown scenario "$scenario". Valid: ${_allScenarios.join(', ')}',
        );
      }
      continue;
    }
    if (arg == '--frame-budget-ms' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --frame-budget-ms value.');
      }
      frameBudgetMs = parsed;
      continue;
    }
    if (arg == '--define' && i + 1 < args.length) {
      final rawDefine = args[++i];
      final separator = rawDefine.indexOf('=');
      if (separator <= 0) {
        throw ArgumentError(
          'Invalid --define value "$rawDefine". Use KEY=VALUE.',
        );
      }
      final key = rawDefine.substring(0, separator);
      final value = rawDefine.substring(separator + 1);
      defines[key] = value;
      continue;
    }
    throw ArgumentError('Unknown argument: $arg');
  }

  return _Config(
    deviceId: deviceId,
    scenario: scenario,
    frameBudgetMs: frameBudgetMs,
    defines: defines,
  );
}

void _printUsage() {
  stdout.writeln('Usage: dart run benchmarks/run_benchmarks.dart [options]');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --device <id>            Flutter device id (e.g., linux, chrome).',
  );
  stdout.writeln('  --scenario <name>        Run only one scenario.');
  stdout.writeln(
    '  --frame-budget-ms <num>  Jank threshold in ms (default: 16.67).',
  );
  stdout.writeln(
    '  --define KEY=VALUE       Additional --dart-define (repeatable).',
  );
  stdout.writeln('  -h, --help               Show this help.');
}

String _timestampId(DateTime time) {
  final two = (int value) => value.toString().padLeft(2, '0');
  return '${time.year}${two(time.month)}${two(time.day)}_'
      '${two(time.hour)}${two(time.minute)}${two(time.second)}Z';
}

class _Config {
  const _Config({
    required this.deviceId,
    required this.scenario,
    required this.frameBudgetMs,
    required this.defines,
  });

  final String? deviceId;
  final String? scenario;
  final double frameBudgetMs;
  final Map<String, String> defines;
}
