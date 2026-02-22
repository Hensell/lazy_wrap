import 'dart:convert';
import 'dart:io';

const _scenarios = <_ScenarioSpec>[
  _ScenarioSpec(
    scenario: 'chip_compare_lazy_wrap_2k',
    label: 'lazy_wrap.dynamic (2D lazy)',
    family: 'lazy_wrap',
  ),
  _ScenarioSpec(
    scenario: 'chip_compare_wrap_2k',
    label: 'SingleChildScrollView + Wrap (2D eager)',
    family: 'wrap',
  ),
  _ScenarioSpec(
    scenario: 'chip_compare_listview_2k',
    label: 'ListView.builder (1D lazy)',
    family: 'listview',
  ),
];

const _lowerIsBetterMetrics = <String>[
  'p95_build_ms',
  'p95_raster_ms',
  'jank_percent',
  'peak_memory_mb',
  'time_to_first_interaction_ms',
];

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);
  final now = DateTime.now().toUtc();
  final stamp = _timestampId(now);
  final defaultBase =
      'benchmarks/results/experiments/${stamp}_chip_competitor_compare';
  final reportPath = config.reportPath ?? '${defaultBase}_report.md';
  final jsonPath = config.jsonPath ?? '$defaultBase.json';

  final results = <String, Map<String, dynamic>>{};
  final runMeta = <String, Map<String, String>>{};

  stdout.writeln('Chip competitor comparison benchmark');
  stdout.writeln('Device: ${config.deviceId ?? 'default'}');
  stdout.writeln('Frame budget: ${config.frameBudgetMs.toStringAsFixed(2)} ms');
  stdout.writeln('Scenarios: ${_scenarios.map((s) => s.scenario).join(', ')}');

  for (final spec in _scenarios) {
    stdout.writeln('\n# Running ${spec.label}');
    final run = await _runSingleScenario(
      scenario: spec.scenario,
      deviceId: config.deviceId,
      frameBudgetMs: config.frameBudgetMs,
    );
    runMeta[spec.scenario] = run;
    final summary = _readJsonMap(run['summary_path']!);
    final scenarioResults = summary['results'];
    if (scenarioResults is! List || scenarioResults.isEmpty) {
      throw StateError(
        'Unexpected summary format for ${spec.scenario}: ${run['summary_path']}',
      );
    }
    results[spec.scenario] = Map<String, dynamic>.from(
      scenarioResults.first as Map,
    );
  }

  final lazyWrap = results['chip_compare_lazy_wrap_2k']!;
  final wrap = results['chip_compare_wrap_2k']!;
  final listView = results['chip_compare_listview_2k']!;

  final lazyWrapVsWrap = _computeAdvantage(
    reference: wrap,
    candidate: lazyWrap,
  );
  final lazyWrapVsListView = _computeAdvantage(
    reference: listView,
    candidate: lazyWrap,
  );

  final outputJson = <String, Object?>{
    'generated_at_utc': now.toIso8601String(),
    'device': config.deviceId ?? 'default',
    'frame_budget_ms': config.frameBudgetMs,
    'scenarios': _scenarios
        .map(
          (spec) => <String, Object?>{
            'scenario': spec.scenario,
            'label': spec.label,
            'family': spec.family,
            'run_meta': runMeta[spec.scenario],
            'metrics': results[spec.scenario],
          },
        )
        .toList(),
    'lazy_wrap_advantage_percent': <String, Object?>{
      'vs_wrap_2d_eager': lazyWrapVsWrap,
      'vs_listview_1d_lazy': lazyWrapVsListView,
    },
    'notes': <String>[
      'Wrap is 2D but eager (no lazy rendering).',
      'ListView.builder is lazy but 1D and not a wrap layout.',
      'Use this benchmark as a tradeoff illustration, not a universal ranking.',
    ],
  };

  final report = _buildReport(
    generatedAtUtc: now,
    deviceId: config.deviceId ?? 'default',
    frameBudgetMs: config.frameBudgetMs,
    results: results,
    lazyWrapVsWrap: lazyWrapVsWrap,
    lazyWrapVsListView: lazyWrapVsListView,
  );

  File(reportPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(report);
  File(jsonPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(outputJson));

  stdout.writeln('\nReport: $reportPath');
  stdout.writeln('JSON: $jsonPath');
}

Map<String, double> _computeAdvantage({
  required Map<String, dynamic> reference,
  required Map<String, dynamic> candidate,
}) {
  final out = <String, double>{};
  for (final metric in _lowerIsBetterMetrics) {
    final ref = _asDouble(reference[metric]);
    final cand = _asDouble(candidate[metric]);
    if (ref == 0) {
      out[metric] = 0;
      continue;
    }
    out[metric] = ((ref - cand) / ref) * 100;
  }
  return out;
}

String _buildReport({
  required DateTime generatedAtUtc,
  required String deviceId,
  required double frameBudgetMs,
  required Map<String, Map<String, dynamic>> results,
  required Map<String, double> lazyWrapVsWrap,
  required Map<String, double> lazyWrapVsListView,
}) {
  final lazyWrap = results['chip_compare_lazy_wrap_2k']!;
  final wrap = results['chip_compare_wrap_2k']!;
  final listView = results['chip_compare_listview_2k']!;

  String metricsRow(String label, Map<String, dynamic> r) {
    return '| $label | ${_fmt(r['p95_build_ms'])} | ${_fmt(r['p95_raster_ms'])} | '
        '${_fmt(r['jank_percent'])}% | ${_fmt(r['peak_memory_mb'])} | '
        '${_fmt(r['time_to_first_interaction_ms'])} | ${r['item_build_calls']} | '
        '${r['unique_built_indices']} |';
  }

  String advantageRow(String metric, Map<String, double> deltas) {
    return '| `$metric` | ${_fmtPct(deltas[metric] ?? 0)} |';
  }

  final buffer = StringBuffer()
    ..writeln('# Chip Benchmark: `lazy_wrap` vs `Wrap` vs `ListView.builder`')
    ..writeln()
    ..writeln('## Metadata')
    ..writeln()
    ..writeln('- Fecha UTC: `${generatedAtUtc.toIso8601String()}`')
    ..writeln('- Device: `$deviceId`')
    ..writeln('- Frame budget: `${frameBudgetMs.toStringAsFixed(2)} ms`')
    ..writeln('- Item count por escenario: `2000`')
    ..writeln()
    ..writeln('## Caveats (comparacion justa)')
    ..writeln()
    ..writeln('- `Wrap` es layout **2D** pero **no lazy** (eager).')
    ..writeln('- `ListView.builder` es **lazy** pero **1D** (no reproduce wrap).')
    ..writeln(
      '- `lazy_wrap.dynamic` se posiciona en el espacio intermedio: layout tipo wrap + lazy rendering.',
    )
    ..writeln()
    ..writeln('## Resultados')
    ..writeln()
    ..writeln(
      '| Implementacion | p95_build_ms | p95_raster_ms | % jank | peak_memory_mb | TTI ms | item_build_calls | unique_built_indices |',
    )
    ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|')
    ..writeln(metricsRow('`lazy_wrap.dynamic` (2D lazy)', lazyWrap))
    ..writeln(metricsRow('`SingleChildScrollView + Wrap` (2D eager)', wrap))
    ..writeln(metricsRow('`ListView.builder` (1D lazy)', listView))
    ..writeln()
    ..writeln('## Ventaja de `lazy_wrap` vs `Wrap` (2D eager)')
    ..writeln()
    ..writeln(
      '`+` significa que `lazy_wrap` es mejor (menor costo) en esa metrica lower-is-better.',
    )
    ..writeln()
    ..writeln('| Metrica | Ventaja de `lazy_wrap` |')
    ..writeln('|---|---:|')
    ..writeln(advantageRow('p95_build_ms', lazyWrapVsWrap))
    ..writeln(advantageRow('p95_raster_ms', lazyWrapVsWrap))
    ..writeln(advantageRow('jank_percent', lazyWrapVsWrap))
    ..writeln(advantageRow('peak_memory_mb', lazyWrapVsWrap))
    ..writeln(advantageRow('time_to_first_interaction_ms', lazyWrapVsWrap))
    ..writeln()
    ..writeln('## Lectura rapida vs `ListView.builder` (1D lazy)')
    ..writeln()
    ..writeln(
      '- `ListView.builder` puede ganar en algunas metricas porque resuelve un problema 1D mas simple.',
    )
    ..writeln(
      '- La comparacion relevante aqui es de tradeoff: `lazy_wrap` mantiene semantica tipo wrap con lazy rendering.',
    )
    ..writeln()
    ..writeln('| Metrica | `lazy_wrap` vs `ListView.builder` |')
    ..writeln('|---|---:|')
    ..writeln(advantageRow('p95_build_ms', lazyWrapVsListView))
    ..writeln(advantageRow('p95_raster_ms', lazyWrapVsListView))
    ..writeln(advantageRow('jank_percent', lazyWrapVsListView))
    ..writeln(advantageRow('peak_memory_mb', lazyWrapVsListView))
    ..writeln(advantageRow('time_to_first_interaction_ms', lazyWrapVsListView))
    ..writeln()
    ..writeln('## Recomendacion de uso')
    ..writeln()
    ..writeln('1. Usa `Wrap` para pocos elementos (simpleza > performance).')
    ..writeln(
      '2. Usa `ListView.builder` cuando tu layout es naturalmente 1D.',
    )
    ..writeln(
      '3. Usa `lazy_wrap` cuando necesitas un layout tipo `Wrap` con listas grandes y scroll fluido.',
    );

  return buffer.toString();
}

Future<Map<String, String>> _runSingleScenario({
  required String scenario,
  required String? deviceId,
  required double frameBudgetMs,
}) async {
  final args = <String>[
    'run',
    'benchmarks/run_benchmarks.dart',
    '--scenario',
    scenario,
    '--frame-budget-ms',
    frameBudgetMs.toStringAsFixed(2),
    if (deviceId != null) ...['--device', deviceId],
  ];

  final process = await Process.start(
    'dart',
    args,
    runInShell: true,
  );

  final stdoutLines = <String>[];
  final stderrLines = <String>[];

  final stdoutDone = process.stdout.transform(utf8.decoder).listen((chunk) {
    stdout.write('[$scenario] $chunk');
    stdoutLines.addAll(const LineSplitter().convert(chunk));
  }).asFuture<void>();

  final stderrDone = process.stderr.transform(utf8.decoder).listen((chunk) {
    stderr.write('[$scenario] $chunk');
    stderrLines.addAll(const LineSplitter().convert(chunk));
  }).asFuture<void>();

  final exitCode = await process.exitCode;
  await stdoutDone;
  await stderrDone;
  if (exitCode != 0) {
    throw ProcessException('dart', args, 'Exit code: $exitCode', exitCode);
  }

  String? summaryPath;
  for (final line in stdoutLines.reversed) {
    const prefix = 'Benchmark summary: ';
    if (line.startsWith(prefix)) {
      summaryPath = line.substring(prefix.length).trim();
      break;
    }
  }
  if (summaryPath == null || summaryPath.isEmpty) {
    throw StateError('Could not parse benchmark summary path for $scenario.');
  }

  return <String, String>{
    'summary_path': summaryPath,
  };
}

Map<String, dynamic> _readJsonMap(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Expected JSON object: $path');
  }
  return decoded;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _fmt(Object? value) => _asDouble(value).toStringAsFixed(2);

String _fmtPct(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String _timestampId(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}_${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

_CliConfig _parseArgs(List<String> args) {
  String? deviceId;
  String? reportPath;
  String? jsonPath;
  var frameBudgetMs = 16.67;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--device' && i + 1 < args.length) {
      deviceId = args[++i];
      continue;
    }
    if (arg == '--frame-budget-ms' && i + 1 < args.length) {
      frameBudgetMs = double.parse(args[++i]);
      continue;
    }
    if (arg == '--report-path' && i + 1 < args.length) {
      reportPath = args[++i];
      continue;
    }
    if (arg == '--json-report-path' && i + 1 < args.length) {
      jsonPath = args[++i];
      continue;
    }
    if (arg == '-h' || arg == '--help') {
      _printHelp();
      exit(0);
    }
    stderr.writeln('Unknown argument: $arg');
    _printHelp();
    exit(64);
  }

  return _CliConfig(
    deviceId: deviceId,
    frameBudgetMs: frameBudgetMs,
    reportPath: reportPath,
    jsonPath: jsonPath,
  );
}

void _printHelp() {
  stdout.writeln(
    'Usage: dart run benchmarks/run_chip_competitor_comparison.dart [options]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln('  --device <id>            Flutter device id (e.g. linux).');
  stdout.writeln(
    '  --frame-budget-ms <n>    Frame budget for jank classification (default: 16.67).',
  );
  stdout.writeln('  --report-path <p>        Markdown output path.');
  stdout.writeln('  --json-report-path <p>   JSON output path.');
  stdout.writeln('  -h, --help               Show this help.');
}

class _CliConfig {
  const _CliConfig({
    required this.deviceId,
    required this.frameBudgetMs,
    required this.reportPath,
    required this.jsonPath,
  });

  final String? deviceId;
  final double frameBudgetMs;
  final String? reportPath;
  final String? jsonPath;
}

class _ScenarioSpec {
  const _ScenarioSpec({
    required this.scenario,
    required this.label,
    required this.family,
  });

  final String scenario;
  final String label;
  final String family;
}
