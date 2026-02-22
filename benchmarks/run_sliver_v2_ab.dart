import 'dart:convert';
import 'dart:io';

const _scenarioPairs = <_ScenarioPair>[
  _ScenarioPair(
    label: 'dynamic_card_50k',
    v1Scenario: 'dynamic_card_50k',
    v2Scenario: 'dynamic_card_50k_sliver_v2',
  ),
  _ScenarioPair(
    label: 'dynamic_chip_10k',
    v1Scenario: 'dynamic_chip_10k',
    v2Scenario: 'dynamic_chip_10k_sliver_v2',
  ),
];

class _ScenarioPair {
  const _ScenarioPair({
    required this.label,
    required this.v1Scenario,
    required this.v2Scenario,
  });

  final String label;
  final String v1Scenario;
  final String v2Scenario;
}

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  stdout.writeln('Running A/B benchmark for sliverV2 prototype');
  stdout.writeln('Device: ${config.deviceId ?? 'default'}');
  stdout.writeln('Frame budget: ${config.frameBudgetMs.toStringAsFixed(2)} ms');
  stdout.writeln('Repeats per scenario: ${config.repeats}');
  stdout.writeln('Warmup runs descartados: ${config.warmupRuns}');
  stdout.writeln(
    'Outlier filter: ${config.discardOutliers ? 'enabled (IQR x${config.outlierIqrK.toStringAsFixed(2)})' : 'disabled'}',
  );
  stdout.writeln('Scenario pairs:');
  for (final pair in _scenarioPairs) {
    stdout.writeln(
      '- ${pair.v1Scenario} vs ${pair.v2Scenario} (${pair.label})',
    );
  }

  final pairResults = <_PairBatchResult>[];
  for (final pair in _scenarioPairs) {
    stdout.writeln('\n# Pair: ${pair.label}');

    final v1 = await _runScenarioBatch(
      scenario: pair.v1Scenario,
      repeats: config.repeats,
      warmupRuns: config.warmupRuns,
      deviceId: config.deviceId,
      frameBudgetMs: config.frameBudgetMs,
    );

    final v2 = await _runScenarioBatch(
      scenario: pair.v2Scenario,
      repeats: config.repeats,
      warmupRuns: config.warmupRuns,
      deviceId: config.deviceId,
      frameBudgetMs: config.frameBudgetMs,
    );

    pairResults.add(_PairBatchResult(pair: pair, v1: v1, v2: v2));
  }

  final reportPath = _writeReport(
    outputPath: config.reportPath,
    deviceId: config.deviceId,
    frameBudgetMs: config.frameBudgetMs,
    repeats: config.repeats,
    warmupRuns: config.warmupRuns,
    discardOutliers: config.discardOutliers,
    outlierIqrK: config.outlierIqrK,
    pairs: pairResults,
  );
  final jsonReportPath = _writeJsonReport(
    outputPath: config.jsonReportPath,
    deviceId: config.deviceId,
    frameBudgetMs: config.frameBudgetMs,
    repeats: config.repeats,
    warmupRuns: config.warmupRuns,
    discardOutliers: config.discardOutliers,
    outlierIqrK: config.outlierIqrK,
    pairs: pairResults,
  );

  stdout.writeln('A/B report: $reportPath');
  stdout.writeln('A/B json report: $jsonReportPath');
}

class _Config {
  const _Config({
    required this.deviceId,
    required this.frameBudgetMs,
    required this.repeats,
    required this.warmupRuns,
    required this.discardOutliers,
    required this.outlierIqrK,
    required this.reportPath,
    required this.jsonReportPath,
  });

  final String? deviceId;
  final double frameBudgetMs;
  final int repeats;
  final int warmupRuns;
  final bool discardOutliers;
  final double outlierIqrK;
  final String reportPath;
  final String jsonReportPath;
}

class _ScenarioRunResult {
  const _ScenarioRunResult({
    required this.runId,
    required this.summaryPath,
    required this.metrics,
  });

  final String runId;
  final String summaryPath;
  final Map<String, dynamic> metrics;
}

class _ScenarioBatchResult {
  const _ScenarioBatchResult({
    required this.scenario,
    required this.warmupRunIds,
    required this.runs,
  });

  final String scenario;
  final List<String> warmupRunIds;
  final List<_ScenarioRunResult> runs;
}

class _PairBatchResult {
  const _PairBatchResult({
    required this.pair,
    required this.v1,
    required this.v2,
  });

  final _ScenarioPair pair;
  final _ScenarioBatchResult v1;
  final _ScenarioBatchResult v2;
}

_Config _parseArgs(List<String> args) {
  String? deviceId;
  var frameBudgetMs = 16.67;
  var repeats = 3;
  var warmupRuns = 1;
  var discardOutliers = true;
  var outlierIqrK = 1.5;
  var reportPath = 'benchmarks/sliver_v2_ab_report.md';
  var jsonReportPath = 'benchmarks/sliver_v2_ab_report.json';

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
    if (arg == '--frame-budget-ms' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --frame-budget-ms value.');
      }
      frameBudgetMs = parsed;
      continue;
    }
    if (arg == '--repeats' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --repeats value.');
      }
      repeats = parsed;
      continue;
    }
    if (arg == '--warmup-runs' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed < 0) {
        throw ArgumentError('Invalid --warmup-runs value.');
      }
      warmupRuns = parsed;
      continue;
    }
    if (arg == '--outlier-iqr-k' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --outlier-iqr-k value.');
      }
      outlierIqrK = parsed;
      continue;
    }
    if (arg == '--no-outlier-filter') {
      discardOutliers = false;
      continue;
    }
    if (arg == '--report-path' && i + 1 < args.length) {
      reportPath = args[++i];
      continue;
    }
    if (arg == '--json-report-path' && i + 1 < args.length) {
      jsonReportPath = args[++i];
      continue;
    }
    throw ArgumentError('Unknown argument: $arg');
  }

  return _Config(
    deviceId: deviceId,
    frameBudgetMs: frameBudgetMs,
    repeats: repeats,
    warmupRuns: warmupRuns,
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
    reportPath: reportPath,
    jsonReportPath: jsonReportPath,
  );
}

void _printUsage() {
  stdout.writeln('Usage: dart run benchmarks/run_sliver_v2_ab.dart [options]');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln('  --device <id>            Flutter device id (e.g., linux).');
  stdout.writeln(
    '  --frame-budget-ms <num>  Jank threshold in ms (default: 16.67).',
  );
  stdout.writeln(
    '  --repeats <n>            Repetitions per scenario (default: 3).',
  );
  stdout.writeln(
    '  --warmup-runs <n>        Warmup runs discarded per scenario (default: 1).',
  );
  stdout.writeln(
    '  --outlier-iqr-k <num>    IQR multiplier for outlier filter (default: 1.5).',
  );
  stdout.writeln(
    '  --no-outlier-filter      Disable outlier filtering in median metrics.',
  );
  stdout.writeln(
    '  --report-path <p>        Markdown report output path (default: benchmarks/sliver_v2_ab_report.md).',
  );
  stdout.writeln(
    '  --json-report-path <p>   JSON report output path (default: benchmarks/sliver_v2_ab_report.json).',
  );
  stdout.writeln('  -h, --help               Show this help.');
}

Future<_ScenarioBatchResult> _runScenarioBatch({
  required String scenario,
  required int repeats,
  required int warmupRuns,
  required String? deviceId,
  required double frameBudgetMs,
}) async {
  final warmupRunIds = <String>[];
  for (var i = 1; i <= warmupRuns; i++) {
    stdout.writeln('\n## $scenario warmup $i/$warmupRuns (discarded)');
    final warmup = await _runScenarioOnce(
      scenario: scenario,
      deviceId: deviceId,
      frameBudgetMs: frameBudgetMs,
    );
    warmupRunIds.add(warmup.runId);
  }

  final runs = <_ScenarioRunResult>[];

  for (var i = 1; i <= repeats; i++) {
    stdout.writeln('\n## $scenario run $i/$repeats');
    final result = await _runScenarioOnce(
      scenario: scenario,
      deviceId: deviceId,
      frameBudgetMs: frameBudgetMs,
    );
    runs.add(result);
  }

  return _ScenarioBatchResult(
    scenario: scenario,
    warmupRunIds: warmupRunIds,
    runs: runs,
  );
}

Future<_ScenarioRunResult> _runScenarioOnce({
  required String scenario,
  required String? deviceId,
  required double frameBudgetMs,
}) async {
  final before = _listRunIds();

  final command = <String>[
    'run',
    'benchmarks/run_benchmarks.dart',
    '--scenario',
    scenario,
    '--frame-budget-ms',
    frameBudgetMs.toStringAsFixed(2),
    if (deviceId != null) ...['--device', deviceId],
  ];

  stdout.writeln('==> dart ${command.join(' ')}');
  final process = await Process.start('dart', command, runInShell: true);

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
    throw ProcessException('dart', command, 'Exit code: $code', code);
  }

  final after = _listRunIds();
  final created = after.difference(before);
  if (created.isEmpty) {
    throw StateError(
      'No benchmark run folder detected for scenario: $scenario',
    );
  }

  final runId = (created.toList()..sort()).last;
  final summaryPath = 'benchmarks/results/$runId/summary.json';
  final summaryFile = File(summaryPath);

  if (!summaryFile.existsSync()) {
    throw StateError('Missing summary file: $summaryPath');
  }

  final decoded = jsonDecode(summaryFile.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected summary format: $summaryPath');
  }

  final results = decoded['results'];
  if (results is! List || results.isEmpty || results.first is! Map) {
    throw StateError('Unexpected summary results payload: $summaryPath');
  }

  final metrics = Map<String, dynamic>.from(results.first as Map);

  return _ScenarioRunResult(
    runId: runId,
    summaryPath: summaryPath,
    metrics: metrics,
  );
}

Set<String> _listRunIds() {
  final dir = Directory('benchmarks/results');
  if (!dir.existsSync()) return <String>{};

  return dir
      .listSync(followLinks: false)
      .whereType<Directory>()
      .map((entry) => entry.uri.pathSegments.reversed.skip(1).first)
      .toSet();
}

String _writeReport({
  required String outputPath,
  required String? deviceId,
  required double frameBudgetMs,
  required int repeats,
  required int warmupRuns,
  required bool discardOutliers,
  required double outlierIqrK,
  required List<_PairBatchResult> pairs,
}) {
  final report = StringBuffer()
    ..writeln('# A/B Benchmark: offstageV1 vs sliverV2 (Spike)')
    ..writeln()
    ..writeln('- Fecha UTC: `${DateTime.now().toUtc().toIso8601String()}`')
    ..writeln('- Device: `${deviceId ?? 'default'}`')
    ..writeln('- Frame budget: `${frameBudgetMs.toStringAsFixed(2)} ms`')
    ..writeln('- Repeticiones por escenario: `$repeats`')
    ..writeln('- Warmups descartados por escenario: `$warmupRuns`')
    ..writeln(
      '- Outlier filter: `${discardOutliers ? 'enabled (IQR x${outlierIqrK.toStringAsFixed(2)})' : 'disabled'}`',
    )
    ..writeln();

  final summaryRows = <String>[];

  for (final pair in pairs) {
    final v1Build = _metricStats(
      pair.v1.runs,
      'p95_build_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v1Raster = _metricStats(
      pair.v1.runs,
      'p95_raster_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v1Jank = _metricStats(
      pair.v1.runs,
      'jank_percent',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v1Memory = _metricStats(
      pair.v1.runs,
      'peak_memory_mb',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v1Tti = _metricStats(
      pair.v1.runs,
      'time_to_first_interaction_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );

    final v2Build = _metricStats(
      pair.v2.runs,
      'p95_build_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v2Raster = _metricStats(
      pair.v2.runs,
      'p95_raster_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v2Jank = _metricStats(
      pair.v2.runs,
      'jank_percent',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v2Memory = _metricStats(
      pair.v2.runs,
      'peak_memory_mb',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v2Tti = _metricStats(
      pair.v2.runs,
      'time_to_first_interaction_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );

    final buildDelta = _improvementLowerIsBetter(
      v1Build.median,
      v2Build.median,
    );
    final rasterDelta = _improvementLowerIsBetter(
      v1Raster.median,
      v2Raster.median,
    );
    final jankDelta = _improvementLowerIsBetter(
      v1Jank.median,
      v2Jank.median,
    );
    final memoryDelta = _improvementLowerIsBetter(
      v1Memory.median,
      v2Memory.median,
    );
    final ttiDelta = _improvementLowerIsBetter(
      v1Tti.median,
      v2Tti.median,
    );

    summaryRows.add(
      '| `${pair.pair.label}` | ${_fmtPct(buildDelta)} | ${_fmtPct(rasterDelta)} | ${_fmtPct(jankDelta)} | ${_fmtPct(memoryDelta)} | ${_fmtPct(ttiDelta)} |',
    );

    report
      ..writeln('## Escenario `${pair.pair.label}`')
      ..writeln()
      ..writeln('### offstageV1 (`${pair.pair.v1Scenario}`)')
      ..writeln()
      ..writeln(
        '| run_id | p95_build | p95_raster | jank% | peak_mb | tti_ms |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|')
      ..writeln(_runRows(pair.v1.runs))
      ..writeln()
      ..writeln(
        'Warmup run_ids descartados: '
        '${pair.v1.warmupRunIds.isEmpty ? 'ninguno' : pair.v1.warmupRunIds.map((id) => '`$id`').join(', ')}',
      )
      ..writeln()
      ..writeln('### sliverV2 (`${pair.pair.v2Scenario}`)')
      ..writeln()
      ..writeln(
        '| run_id | p95_build | p95_raster | jank% | peak_mb | tti_ms |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|')
      ..writeln(_runRows(pair.v2.runs))
      ..writeln()
      ..writeln(
        'Warmup run_ids descartados: '
        '${pair.v2.warmupRunIds.isEmpty ? 'ninguno' : pair.v2.warmupRunIds.map((id) => '`$id`').join(', ')}',
      )
      ..writeln()
      ..writeln('### Comparación por mediana')
      ..writeln()
      ..writeln('| Métrica | offstageV1 | sliverV2 | Mejora V2 vs V1 |')
      ..writeln('|---|---:|---:|---:|')
      ..writeln(
        '| p95_build_ms | ${_fmt(v1Build.median)} | ${_fmt(v2Build.median)} | ${_fmtPct(buildDelta)} |',
      )
      ..writeln(
        '| p95_raster_ms | ${_fmt(v1Raster.median)} | ${_fmt(v2Raster.median)} | ${_fmtPct(rasterDelta)} |',
      )
      ..writeln(
        '| % jank | ${_fmt(v1Jank.median)} | ${_fmt(v2Jank.median)} | ${_fmtPct(jankDelta)} |',
      )
      ..writeln(
        '| peak_memory_mb | ${_fmt(v1Memory.median)} | ${_fmt(v2Memory.median)} | ${_fmtPct(memoryDelta)} |',
      )
      ..writeln(
        '| time_to_first_interaction_ms | ${_fmt(v1Tti.median)} | ${_fmt(v2Tti.median)} | ${_fmtPct(ttiDelta)} |',
      )
      ..writeln()
      ..writeln(
        'Muestras usadas offstageV1 (build/raster/jank/memoria/tti): '
        '${v1Build.usedCount}/${pair.v1.runs.length}, '
        '${v1Raster.usedCount}/${pair.v1.runs.length}, '
        '${v1Jank.usedCount}/${pair.v1.runs.length}, '
        '${v1Memory.usedCount}/${pair.v1.runs.length}, '
        '${v1Tti.usedCount}/${pair.v1.runs.length}.',
      )
      ..writeln(
        'Muestras usadas sliverV2 (build/raster/jank/memoria/tti): '
        '${v2Build.usedCount}/${pair.v2.runs.length}, '
        '${v2Raster.usedCount}/${pair.v2.runs.length}, '
        '${v2Jank.usedCount}/${pair.v2.runs.length}, '
        '${v2Memory.usedCount}/${pair.v2.runs.length}, '
        '${v2Tti.usedCount}/${pair.v2.runs.length}.',
      )
      ..writeln();
  }

  report
    ..writeln('## Resumen por escenario (mejora V2 vs V1)')
    ..writeln()
    ..writeln('| Escenario | build | raster | jank | memoria | tti |')
    ..writeln('|---|---:|---:|---:|---:|---:|')
    ..writeln(summaryRows.join('\n'))
    ..writeln()
    ..writeln('## Lectura rápida')
    ..writeln()
    ..writeln(
      '- Valor positivo en "Mejora" significa que `sliverV2` mejora (menor valor) respecto a `offstageV1` para esa métrica.',
    )
    ..writeln(
      '- Valor negativo en "Mejora" significa regresión de `sliverV2` respecto a `offstageV1`.',
    )
    ..writeln();

  File(outputPath).writeAsStringSync(report.toString());
  return outputPath;
}

String _writeJsonReport({
  required String outputPath,
  required String? deviceId,
  required double frameBudgetMs,
  required int repeats,
  required int warmupRuns,
  required bool discardOutliers,
  required double outlierIqrK,
  required List<_PairBatchResult> pairs,
}) {
  final pairPayload = <Map<String, dynamic>>[];

  for (final pair in pairs) {
    final v1Build = _metricStats(
      pair.v1.runs,
      'p95_build_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v1Raster = _metricStats(
      pair.v1.runs,
      'p95_raster_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v1Jank = _metricStats(
      pair.v1.runs,
      'jank_percent',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v1Memory = _metricStats(
      pair.v1.runs,
      'peak_memory_mb',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v1Tti = _metricStats(
      pair.v1.runs,
      'time_to_first_interaction_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );

    final v2Build = _metricStats(
      pair.v2.runs,
      'p95_build_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v2Raster = _metricStats(
      pair.v2.runs,
      'p95_raster_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v2Jank = _metricStats(
      pair.v2.runs,
      'jank_percent',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v2Memory = _metricStats(
      pair.v2.runs,
      'peak_memory_mb',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final v2Tti = _metricStats(
      pair.v2.runs,
      'time_to_first_interaction_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );

    pairPayload.add({
      'label': pair.pair.label,
      'v1_scenario': pair.pair.v1Scenario,
      'v2_scenario': pair.pair.v2Scenario,
      'v1': {
        'warmup_run_ids': pair.v1.warmupRunIds,
        'runs': pair.v1.runs
            .map(
              (run) => {
                'run_id': run.runId,
                'summary_path': run.summaryPath,
                'metrics': run.metrics,
              },
            )
            .toList(),
        'medians': {
          'p95_build_ms': v1Build.median,
          'p95_raster_ms': v1Raster.median,
          'jank_percent': v1Jank.median,
          'peak_memory_mb': v1Memory.median,
          'time_to_first_interaction_ms': v1Tti.median,
        },
        'sample_counts': {
          'p95_build_ms': {
            'used': v1Build.usedCount,
            'total': pair.v1.runs.length,
          },
          'p95_raster_ms': {
            'used': v1Raster.usedCount,
            'total': pair.v1.runs.length,
          },
          'jank_percent': {
            'used': v1Jank.usedCount,
            'total': pair.v1.runs.length,
          },
          'peak_memory_mb': {
            'used': v1Memory.usedCount,
            'total': pair.v1.runs.length,
          },
          'time_to_first_interaction_ms': {
            'used': v1Tti.usedCount,
            'total': pair.v1.runs.length,
          },
        },
      },
      'v2': {
        'warmup_run_ids': pair.v2.warmupRunIds,
        'runs': pair.v2.runs
            .map(
              (run) => {
                'run_id': run.runId,
                'summary_path': run.summaryPath,
                'metrics': run.metrics,
              },
            )
            .toList(),
        'medians': {
          'p95_build_ms': v2Build.median,
          'p95_raster_ms': v2Raster.median,
          'jank_percent': v2Jank.median,
          'peak_memory_mb': v2Memory.median,
          'time_to_first_interaction_ms': v2Tti.median,
        },
        'sample_counts': {
          'p95_build_ms': {
            'used': v2Build.usedCount,
            'total': pair.v2.runs.length,
          },
          'p95_raster_ms': {
            'used': v2Raster.usedCount,
            'total': pair.v2.runs.length,
          },
          'jank_percent': {
            'used': v2Jank.usedCount,
            'total': pair.v2.runs.length,
          },
          'peak_memory_mb': {
            'used': v2Memory.usedCount,
            'total': pair.v2.runs.length,
          },
          'time_to_first_interaction_ms': {
            'used': v2Tti.usedCount,
            'total': pair.v2.runs.length,
          },
        },
      },
      'delta_v2_vs_v1_percent': {
        'p95_build_ms': _improvementLowerIsBetter(
          v1Build.median,
          v2Build.median,
        ),
        'p95_raster_ms': _improvementLowerIsBetter(
          v1Raster.median,
          v2Raster.median,
        ),
        'jank_percent': _improvementLowerIsBetter(v1Jank.median, v2Jank.median),
        'peak_memory_mb': _improvementLowerIsBetter(
          v1Memory.median,
          v2Memory.median,
        ),
        'time_to_first_interaction_ms': _improvementLowerIsBetter(
          v1Tti.median,
          v2Tti.median,
        ),
      },
    });
  }

  final payload = <String, dynamic>{
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'device': deviceId ?? 'default',
    'frame_budget_ms': frameBudgetMs,
    'repeats': repeats,
    'warmup_runs': warmupRuns,
    'outlier_filter': {
      'enabled': discardOutliers,
      'iqr_k': outlierIqrK,
    },
    'pairs': pairPayload,
  };

  File(
    outputPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));
  return outputPath;
}

String _runRows(List<_ScenarioRunResult> runs) {
  return runs
      .map(
        (run) =>
            '| `${run.runId}` | ${_fmt(run.metrics['p95_build_ms'])} | ${_fmt(run.metrics['p95_raster_ms'])} | ${_fmt(run.metrics['jank_percent'])} | ${_fmt(run.metrics['peak_memory_mb'])} | ${_fmt(run.metrics['time_to_first_interaction_ms'])} |',
      )
      .join('\n');
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

class _MetricStats {
  const _MetricStats({
    required this.rawValues,
    required this.filteredValues,
    required this.median,
  });

  final List<double> rawValues;
  final List<double> filteredValues;
  final double median;

  int get usedCount => filteredValues.length;
}

_MetricStats _metricStats(
  List<_ScenarioRunResult> runs,
  String key, {
  required bool discardOutliers,
  required double outlierIqrK,
}) {
  final rawValues = runs.map((run) => _asDouble(run.metrics[key])).toList();
  final filteredValues = discardOutliers
      ? _filterOutliersIqr(rawValues, outlierIqrK)
      : rawValues;

  final stableValues = filteredValues.isEmpty ? rawValues : filteredValues;
  return _MetricStats(
    rawValues: rawValues,
    filteredValues: stableValues,
    median: _median(stableValues),
  );
}

List<double> _filterOutliersIqr(List<double> values, double k) {
  // With very small samples, IQR filtering is unstable and can over-drop.
  if (values.length < 4) return values;

  final sorted = [...values]..sort();
  final q1 = _quantile(sorted, 0.25);
  final q3 = _quantile(sorted, 0.75);
  final iqr = q3 - q1;

  if (iqr == 0) return values;

  final low = q1 - (k * iqr);
  final high = q3 + (k * iqr);
  final filtered = values.where((value) => value >= low && value <= high);
  final asList = filtered.toList();
  return asList.isEmpty ? values : asList;
}

double _quantile(List<double> sortedValues, double p) {
  if (sortedValues.isEmpty) return 0;
  if (sortedValues.length == 1) return sortedValues.first;

  final position = (sortedValues.length - 1) * p;
  final lowerIndex = position.floor();
  final upperIndex = position.ceil();

  if (lowerIndex == upperIndex) {
    return sortedValues[lowerIndex];
  }

  final lower = sortedValues[lowerIndex];
  final upper = sortedValues[upperIndex];
  final fraction = position - lowerIndex;
  return lower + ((upper - lower) * fraction);
}

double _improvementLowerIsBetter(double baseline, double current) {
  if (baseline == 0) return 0;
  return ((baseline - current) / baseline) * 100;
}

String _fmt(Object? value) => _asDouble(value).toStringAsFixed(3);

String _fmtPct(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}
