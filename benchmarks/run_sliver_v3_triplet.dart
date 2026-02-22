import 'dart:convert';
import 'dart:io';

const _variants = <String>[
  'dynamic_chip_10k',
  'dynamic_chip_10k_sliver_v2',
  'dynamic_chip_10k_sliver_v3',
];

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  stdout.writeln(
    'Running triplet benchmark: offstageV1 vs sliverV2 vs sliverV3',
  );
  stdout.writeln('Device: ${config.deviceId ?? 'default'}');
  stdout.writeln('Frame budget: ${config.frameBudgetMs.toStringAsFixed(2)} ms');
  stdout.writeln('Repeats per variant: ${config.repeats}');
  stdout.writeln('Warmup runs descartados: ${config.warmupRuns}');
  stdout.writeln(
    'Outlier filter: ${config.discardOutliers ? 'enabled (IQR x${config.outlierIqrK.toStringAsFixed(2)})' : 'disabled'}',
  );

  final batches = <_ScenarioBatchResult>[];
  for (final scenario in _variants) {
    stdout.writeln('\n# Variant: $scenario');
    final batch = await _runScenarioBatch(
      scenario: scenario,
      repeats: config.repeats,
      warmupRuns: config.warmupRuns,
      deviceId: config.deviceId,
      frameBudgetMs: config.frameBudgetMs,
    );
    batches.add(batch);
  }

  final reportPath = _writeReport(
    outputPath: config.reportPath,
    deviceId: config.deviceId,
    frameBudgetMs: config.frameBudgetMs,
    repeats: config.repeats,
    warmupRuns: config.warmupRuns,
    discardOutliers: config.discardOutliers,
    outlierIqrK: config.outlierIqrK,
    batches: batches,
  );
  final jsonReportPath = _writeJsonReport(
    outputPath: config.jsonReportPath,
    deviceId: config.deviceId,
    frameBudgetMs: config.frameBudgetMs,
    repeats: config.repeats,
    warmupRuns: config.warmupRuns,
    discardOutliers: config.discardOutliers,
    outlierIqrK: config.outlierIqrK,
    batches: batches,
  );

  stdout.writeln('Triplet report: $reportPath');
  stdout.writeln('Triplet json report: $jsonReportPath');
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

_Config _parseArgs(List<String> args) {
  String? deviceId;
  var frameBudgetMs = 16.67;
  var repeats = 3;
  var warmupRuns = 1;
  var discardOutliers = true;
  var outlierIqrK = 1.5;
  var reportPath = 'benchmarks/sliver_v3_triplet_report.md';
  var jsonReportPath = 'benchmarks/sliver_v3_triplet_report.json';

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
  stdout.writeln(
    'Usage: dart run benchmarks/run_sliver_v3_triplet.dart [options]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln('  --device <id>            Flutter device id (e.g., linux).');
  stdout.writeln(
    '  --frame-budget-ms <num>  Jank threshold in ms (default: 16.67).',
  );
  stdout.writeln(
    '  --repeats <n>            Repetitions per variant (default: 3).',
  );
  stdout.writeln(
    '  --warmup-runs <n>        Warmup runs discarded per variant (default: 1).',
  );
  stdout.writeln(
    '  --outlier-iqr-k <num>    IQR multiplier for outlier filter (default: 1.5).',
  );
  stdout.writeln(
    '  --no-outlier-filter      Disable outlier filtering in median metrics.',
  );
  stdout.writeln(
    '  --report-path <p>        Markdown report output path (default: benchmarks/sliver_v3_triplet_report.md).',
  );
  stdout.writeln(
    '  --json-report-path <p>   JSON report output path (default: benchmarks/sliver_v3_triplet_report.json).',
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
    runs.add(
      await _runScenarioOnce(
        scenario: scenario,
        deviceId: deviceId,
        frameBudgetMs: frameBudgetMs,
      ),
    );
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
  required List<_ScenarioBatchResult> batches,
}) {
  final v1 = batches.firstWhere((batch) => batch.scenario == _variants[0]);
  final v2 = batches.firstWhere((batch) => batch.scenario == _variants[1]);
  final v3 = batches.firstWhere((batch) => batch.scenario == _variants[2]);

  final v1Build = _metricStats(
    v1.runs,
    'p95_build_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v1Raster = _metricStats(
    v1.runs,
    'p95_raster_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v1Jank = _metricStats(
    v1.runs,
    'jank_percent',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v1Memory = _metricStats(
    v1.runs,
    'peak_memory_mb',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v1Tti = _metricStats(
    v1.runs,
    'time_to_first_interaction_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );

  final v2Build = _metricStats(
    v2.runs,
    'p95_build_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v2Raster = _metricStats(
    v2.runs,
    'p95_raster_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v2Jank = _metricStats(
    v2.runs,
    'jank_percent',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v2Memory = _metricStats(
    v2.runs,
    'peak_memory_mb',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v2Tti = _metricStats(
    v2.runs,
    'time_to_first_interaction_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );

  final v3Build = _metricStats(
    v3.runs,
    'p95_build_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v3Raster = _metricStats(
    v3.runs,
    'p95_raster_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v3Jank = _metricStats(
    v3.runs,
    'jank_percent',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v3Memory = _metricStats(
    v3.runs,
    'peak_memory_mb',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v3Tti = _metricStats(
    v3.runs,
    'time_to_first_interaction_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );

  final report = StringBuffer()
    ..writeln('# Triplet Benchmark: offstageV1 vs sliverV2 vs sliverV3')
    ..writeln()
    ..writeln('- Fecha UTC: `${DateTime.now().toUtc().toIso8601String()}`')
    ..writeln('- Device: `${deviceId ?? 'default'}`')
    ..writeln('- Frame budget: `${frameBudgetMs.toStringAsFixed(2)} ms`')
    ..writeln('- Repeticiones por variante: `$repeats`')
    ..writeln('- Warmups descartados por variante: `$warmupRuns`')
    ..writeln(
      '- Outlier filter: `${discardOutliers ? 'enabled (IQR x${outlierIqrK.toStringAsFixed(2)})' : 'disabled'}`',
    )
    ..writeln()
    ..writeln('## Resultados por variante')
    ..writeln();

  for (final batch in batches) {
    final buildStats = _metricStats(
      batch.runs,
      'p95_build_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final rasterStats = _metricStats(
      batch.runs,
      'p95_raster_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final jankStats = _metricStats(
      batch.runs,
      'jank_percent',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final memoryStats = _metricStats(
      batch.runs,
      'peak_memory_mb',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );
    final ttiStats = _metricStats(
      batch.runs,
      'time_to_first_interaction_ms',
      discardOutliers: discardOutliers,
      outlierIqrK: outlierIqrK,
    );

    report
      ..writeln('### `${batch.scenario}`')
      ..writeln()
      ..writeln(
        '| run_id | p95_build | p95_raster | jank% | peak_mb | tti_ms |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|');

    for (final run in batch.runs) {
      report.writeln(
        '| `${run.runId}` | '
        '${_fmt(run.metrics['p95_build_ms'])} | '
        '${_fmt(run.metrics['p95_raster_ms'])} | '
        '${_fmt(run.metrics['jank_percent'])} | '
        '${_fmt(run.metrics['peak_memory_mb'])} | '
        '${_fmt(run.metrics['time_to_first_interaction_ms'])} |',
      );
    }

    report
      ..writeln()
      ..writeln(
        'Warmup run_ids descartados: '
        '${batch.warmupRunIds.isEmpty ? 'ninguno' : batch.warmupRunIds.map((id) => '`$id`').join(', ')}',
      )
      ..writeln()
      ..writeln('Medianas:')
      ..writeln()
      ..writeln('| build | raster | jank | memoria | tti |')
      ..writeln('|---:|---:|---:|---:|---:|')
      ..writeln(
        '| ${_fmt(buildStats.median)}'
        ' | ${_fmt(rasterStats.median)}'
        ' | ${_fmt(jankStats.median)}'
        ' | ${_fmt(memoryStats.median)}'
        ' | ${_fmt(ttiStats.median)} |',
      )
      ..writeln()
      ..writeln(
        'Muestras usadas (build/raster/jank/memoria/tti): '
        '${buildStats.usedCount}/${batch.runs.length}, '
        '${rasterStats.usedCount}/${batch.runs.length}, '
        '${jankStats.usedCount}/${batch.runs.length}, '
        '${memoryStats.usedCount}/${batch.runs.length}, '
        '${ttiStats.usedCount}/${batch.runs.length}.',
      )
      ..writeln();
  }

  report
    ..writeln('## Mejora vs offstageV1 (mediana, lower-is-better)')
    ..writeln()
    ..writeln('| Variante | build | raster | jank | memoria | tti |')
    ..writeln('|---|---:|---:|---:|---:|---:|')
    ..writeln(
      '| `sliverV2` | '
      '${_fmtPct(_improvement(v1Build.median, v2Build.median))} | '
      '${_fmtPct(_improvement(v1Raster.median, v2Raster.median))} | '
      '${_fmtPct(_improvement(v1Jank.median, v2Jank.median))} | '
      '${_fmtPct(_improvement(v1Memory.median, v2Memory.median))} | '
      '${_fmtPct(_improvement(v1Tti.median, v2Tti.median))} |',
    )
    ..writeln(
      '| `sliverV3` | '
      '${_fmtPct(_improvement(v1Build.median, v3Build.median))} | '
      '${_fmtPct(_improvement(v1Raster.median, v3Raster.median))} | '
      '${_fmtPct(_improvement(v1Jank.median, v3Jank.median))} | '
      '${_fmtPct(_improvement(v1Memory.median, v3Memory.median))} | '
      '${_fmtPct(_improvement(v1Tti.median, v3Tti.median))} |',
    );

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
  required List<_ScenarioBatchResult> batches,
}) {
  final v1 = batches.firstWhere((batch) => batch.scenario == _variants[0]);
  final v2 = batches.firstWhere((batch) => batch.scenario == _variants[1]);
  final v3 = batches.firstWhere((batch) => batch.scenario == _variants[2]);

  final v1Build = _metricStats(
    v1.runs,
    'p95_build_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v1Raster = _metricStats(
    v1.runs,
    'p95_raster_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v1Jank = _metricStats(
    v1.runs,
    'jank_percent',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v1Memory = _metricStats(
    v1.runs,
    'peak_memory_mb',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v1Tti = _metricStats(
    v1.runs,
    'time_to_first_interaction_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );

  final v2Build = _metricStats(
    v2.runs,
    'p95_build_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v2Raster = _metricStats(
    v2.runs,
    'p95_raster_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v2Jank = _metricStats(
    v2.runs,
    'jank_percent',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v2Memory = _metricStats(
    v2.runs,
    'peak_memory_mb',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v2Tti = _metricStats(
    v2.runs,
    'time_to_first_interaction_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );

  final v3Build = _metricStats(
    v3.runs,
    'p95_build_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v3Raster = _metricStats(
    v3.runs,
    'p95_raster_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v3Jank = _metricStats(
    v3.runs,
    'jank_percent',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v3Memory = _metricStats(
    v3.runs,
    'peak_memory_mb',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final v3Tti = _metricStats(
    v3.runs,
    'time_to_first_interaction_ms',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );

  final variants = batches
      .map(
        (batch) => {
          'scenario': batch.scenario,
          'warmup_run_ids': batch.warmupRunIds,
          'runs': batch.runs
              .map(
                (run) => {
                  'run_id': run.runId,
                  'summary_path': run.summaryPath,
                  'metrics': run.metrics,
                },
              )
              .toList(),
          'medians': {
            'p95_build_ms': _metricStats(
              batch.runs,
              'p95_build_ms',
              discardOutliers: discardOutliers,
              outlierIqrK: outlierIqrK,
            ).median,
            'p95_raster_ms': _metricStats(
              batch.runs,
              'p95_raster_ms',
              discardOutliers: discardOutliers,
              outlierIqrK: outlierIqrK,
            ).median,
            'jank_percent': _metricStats(
              batch.runs,
              'jank_percent',
              discardOutliers: discardOutliers,
              outlierIqrK: outlierIqrK,
            ).median,
            'peak_memory_mb': _metricStats(
              batch.runs,
              'peak_memory_mb',
              discardOutliers: discardOutliers,
              outlierIqrK: outlierIqrK,
            ).median,
            'time_to_first_interaction_ms': _metricStats(
              batch.runs,
              'time_to_first_interaction_ms',
              discardOutliers: discardOutliers,
              outlierIqrK: outlierIqrK,
            ).median,
          },
          'sample_counts': {
            'p95_build_ms': {
              'used': _metricStats(
                batch.runs,
                'p95_build_ms',
                discardOutliers: discardOutliers,
                outlierIqrK: outlierIqrK,
              ).usedCount,
              'total': batch.runs.length,
            },
            'p95_raster_ms': {
              'used': _metricStats(
                batch.runs,
                'p95_raster_ms',
                discardOutliers: discardOutliers,
                outlierIqrK: outlierIqrK,
              ).usedCount,
              'total': batch.runs.length,
            },
            'jank_percent': {
              'used': _metricStats(
                batch.runs,
                'jank_percent',
                discardOutliers: discardOutliers,
                outlierIqrK: outlierIqrK,
              ).usedCount,
              'total': batch.runs.length,
            },
            'peak_memory_mb': {
              'used': _metricStats(
                batch.runs,
                'peak_memory_mb',
                discardOutliers: discardOutliers,
                outlierIqrK: outlierIqrK,
              ).usedCount,
              'total': batch.runs.length,
            },
            'time_to_first_interaction_ms': {
              'used': _metricStats(
                batch.runs,
                'time_to_first_interaction_ms',
                discardOutliers: discardOutliers,
                outlierIqrK: outlierIqrK,
              ).usedCount,
              'total': batch.runs.length,
            },
          },
        },
      )
      .toList();

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
    'variants': variants,
    'improvement_vs_offstage_v1_percent': {
      'sliver_v2': {
        'p95_build_ms': _improvement(v1Build.median, v2Build.median),
        'p95_raster_ms': _improvement(v1Raster.median, v2Raster.median),
        'jank_percent': _improvement(v1Jank.median, v2Jank.median),
        'peak_memory_mb': _improvement(v1Memory.median, v2Memory.median),
        'time_to_first_interaction_ms': _improvement(
          v1Tti.median,
          v2Tti.median,
        ),
      },
      'sliver_v3': {
        'p95_build_ms': _improvement(v1Build.median, v3Build.median),
        'p95_raster_ms': _improvement(v1Raster.median, v3Raster.median),
        'jank_percent': _improvement(v1Jank.median, v3Jank.median),
        'peak_memory_mb': _improvement(v1Memory.median, v3Memory.median),
        'time_to_first_interaction_ms': _improvement(
          v1Tti.median,
          v3Tti.median,
        ),
      },
    },
  };

  File(outputPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(payload),
  );
  return outputPath;
}

double _improvement(double baseline, double candidate) {
  if (baseline == 0) return 0;
  return ((baseline - candidate) / baseline) * 100;
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
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

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _fmt(Object? value) => _asDouble(value).toStringAsFixed(3);

String _fmtPct(double value) => '${value.toStringAsFixed(2)}%';
