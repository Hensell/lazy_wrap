import 'dart:convert';
import 'dart:io';

const _requiredScenarios = <String>[
  'dynamic_chip_10k',
  'dynamic_card_50k',
];

const _metricKeys = <String>[
  'p95_build_ms',
  'p95_raster_ms',
  'jank_percent',
  'peak_memory_mb',
  'time_to_first_interaction_ms',
];

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  stdout.writeln('Running Sprint 6 Go/No-Go gate');
  stdout.writeln('Baseline summary: ${config.baselineSummaryPath}');
  stdout.writeln('Candidate A/B JSON: ${config.candidateAbJsonPath}');
  stdout.writeln(
    'Functional tests pass: ${config.functionalTestsPass ? 'yes' : 'no'}',
  );
  stdout.writeln('No P0/P1 open: ${config.noP0P1Open ? 'yes' : 'no'}');
  stdout.writeln('Min repeats required: ${config.minRepeats}');

  final baseline = _readBaselineByScenario(config.baselineSummaryPath);
  final candidate = _readCandidateByScenario(config.candidateAbJsonPath);
  final candidateMeta = _readCandidateMeta(config.candidateAbJsonPath);

  final improvements = <String, Map<String, double>>{};
  for (final scenario in _requiredScenarios) {
    final baselineMetrics = baseline[scenario]!;
    final candidateMetrics = candidate[scenario]!;
    improvements[scenario] = {
      for (final metric in _metricKeys)
        metric: _improvementLowerIsBetter(
          baselineMetrics[metric]!,
          candidateMetrics[metric]!,
        ),
    };
  }

  final chipJankImprovement =
      improvements['dynamic_chip_10k']!['jank_percent']!;
  final cardMemoryImprovement =
      improvements['dynamic_card_50k']!['peak_memory_mb']!;
  final chipBuildImprovement =
      improvements['dynamic_chip_10k']!['p95_build_ms']!;
  final cardBuildImprovement =
      improvements['dynamic_card_50k']!['p95_build_ms']!;

  final checks = <_GateCheck>[
    _GateCheck(
      id: 'chip_jank_30',
      description: '% jank en dynamic_chip_10k mejora >= 30%',
      target: '>= 30%',
      observed: _fmtPct(chipJankImprovement),
      pass: chipJankImprovement >= 30,
    ),
    _GateCheck(
      id: 'card_memory_20',
      description: 'peak_memory_mb en dynamic_card_50k mejora >= 20%',
      target: '>= 20%',
      observed: _fmtPct(cardMemoryImprovement),
      pass: cardMemoryImprovement >= 20,
    ),
    _GateCheck(
      id: 'chip_build_20',
      description: 'p95_build_ms en dynamic_chip_10k mejora >= 20%',
      target: '>= 20%',
      observed: _fmtPct(chipBuildImprovement),
      pass: chipBuildImprovement >= 20,
    ),
    _GateCheck(
      id: 'card_build_20',
      description: 'p95_build_ms en dynamic_card_50k mejora >= 20%',
      target: '>= 20%',
      observed: _fmtPct(cardBuildImprovement),
      pass: cardBuildImprovement >= 20,
    ),
    _GateCheck(
      id: 'functional_suite',
      description: 'Suite funcional sin regresiones',
      target: 'true',
      observed: '${config.functionalTestsPass}',
      pass: config.functionalTestsPass,
    ),
    _GateCheck(
      id: 'p0_p1_clear',
      description: 'Sin P0/P1 abiertos en rutas nuevas',
      target: 'true',
      observed: '${config.noP0P1Open}',
      pass: config.noP0P1Open,
    ),
    _GateCheck(
      id: 'min_repeats',
      description: 'Calidad de evidencia: repeats >= ${config.minRepeats}',
      target: '>= ${config.minRepeats}',
      observed: '${candidateMeta.repeats}',
      pass: candidateMeta.repeats >= config.minRepeats,
    ),
  ];

  final go = checks.every((check) => check.pass);

  final reportPath = _writeMarkdownReport(
    outputPath: config.reportPath,
    baselineSummaryPath: config.baselineSummaryPath,
    candidateAbJsonPath: config.candidateAbJsonPath,
    candidateMeta: candidateMeta,
    baseline: baseline,
    candidate: candidate,
    improvements: improvements,
    checks: checks,
    go: go,
  );

  final jsonReportPath = _writeJsonReport(
    outputPath: config.jsonReportPath,
    baselineSummaryPath: config.baselineSummaryPath,
    candidateAbJsonPath: config.candidateAbJsonPath,
    candidateMeta: candidateMeta,
    baseline: baseline,
    candidate: candidate,
    improvements: improvements,
    checks: checks,
    go: go,
  );

  stdout.writeln('Sprint 6 gate report: $reportPath');
  stdout.writeln('Sprint 6 gate JSON: $jsonReportPath');
}

class _Config {
  const _Config({
    required this.baselineSummaryPath,
    required this.candidateAbJsonPath,
    required this.functionalTestsPass,
    required this.noP0P1Open,
    required this.minRepeats,
    required this.reportPath,
    required this.jsonReportPath,
  });

  final String baselineSummaryPath;
  final String candidateAbJsonPath;
  final bool functionalTestsPass;
  final bool noP0P1Open;
  final int minRepeats;
  final String reportPath;
  final String jsonReportPath;
}

class _CandidateMeta {
  const _CandidateMeta({
    required this.repeats,
    required this.warmupRuns,
    required this.device,
  });

  final int repeats;
  final int warmupRuns;
  final String device;
}

class _GateCheck {
  const _GateCheck({
    required this.id,
    required this.description,
    required this.target,
    required this.observed,
    required this.pass,
  });

  final String id;
  final String description;
  final String target;
  final String observed;
  final bool pass;
}

_Config _parseArgs(List<String> args) {
  var baselineSummaryPath = 'benchmarks/results/20260211_232622Z/summary.json';
  var candidateAbJsonPath = 'benchmarks/sliver_v2_ab_report.json';
  var functionalTestsPass = false;
  var noP0P1Open = false;
  var minRepeats = 3;
  var reportPath = 'benchmarks/sprint6_gate_report.md';
  var jsonReportPath = 'benchmarks/sprint6_gate_report.json';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      _printUsage();
      exit(0);
    }
    if (arg == '--baseline-summary' && i + 1 < args.length) {
      baselineSummaryPath = args[++i];
      continue;
    }
    if (arg == '--candidate-ab-json' && i + 1 < args.length) {
      candidateAbJsonPath = args[++i];
      continue;
    }
    if (arg == '--functional-tests-pass') {
      functionalTestsPass = true;
      continue;
    }
    if (arg == '--no-p0-p1-open') {
      noP0P1Open = true;
      continue;
    }
    if (arg == '--min-repeats' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --min-repeats value.');
      }
      minRepeats = parsed;
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
    baselineSummaryPath: baselineSummaryPath,
    candidateAbJsonPath: candidateAbJsonPath,
    functionalTestsPass: functionalTestsPass,
    noP0P1Open: noP0P1Open,
    minRepeats: minRepeats,
    reportPath: reportPath,
    jsonReportPath: jsonReportPath,
  );
}

void _printUsage() {
  stdout.writeln('Usage: dart run benchmarks/run_sprint6_gate.dart [options]');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --baseline-summary <p>   Baseline summary path (results[] or scenarios[].medians).',
  );
  stdout.writeln(
    '  --candidate-ab-json <p>  Candidate A/B JSON path from run_sliver_v2_ab.',
  );
  stdout.writeln(
    '  --functional-tests-pass  Mark functional suite as passing (manual evidence).',
  );
  stdout.writeln(
    '  --no-p0-p1-open          Mark no P0/P1 open issues in new routes.',
  );
  stdout.writeln(
    '  --min-repeats <n>        Minimum repeats required for evidence quality (default: 3).',
  );
  stdout.writeln(
    '  --report-path <p>        Markdown output path (default: benchmarks/sprint6_gate_report.md).',
  );
  stdout.writeln(
    '  --json-report-path <p>   JSON output path (default: benchmarks/sprint6_gate_report.json).',
  );
  stdout.writeln('  -h, --help               Show this help.');
}

Map<String, Map<String, double>> _readBaselineByScenario(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Baseline summary file not found: $path');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected baseline format: $path');
  }

  final map = <String, Map<String, double>>{};

  final results = decoded['results'];
  if (results is List) {
    for (final entry in results) {
      if (entry is! Map) continue;
      final metricMap = Map<String, dynamic>.from(entry);
      final scenario = metricMap['scenario'];
      if (scenario is! String) continue;
      map[scenario] = _metricSubset(metricMap);
    }
  }

  final scenarios = decoded['scenarios'];
  if (scenarios is List) {
    for (final entry in scenarios) {
      if (entry is! Map) continue;
      final asMap = Map<String, dynamic>.from(entry);
      final scenario = asMap['scenario'];
      final medians = asMap['medians'];
      if (scenario is! String || medians is! Map) continue;
      map[scenario] = _metricSubset(Map<String, dynamic>.from(medians));
    }
  }

  for (final scenario in _requiredScenarios) {
    if (!map.containsKey(scenario)) {
      throw StateError(
        'Baseline summary missing required scenario "$scenario": $path',
      );
    }
  }

  return map;
}

Map<String, Map<String, double>> _readCandidateByScenario(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Candidate A/B JSON file not found: $path');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected candidate A/B format: $path');
  }

  final pairs = decoded['pairs'];
  if (pairs is! List) {
    throw StateError('Candidate A/B JSON missing "pairs": $path');
  }

  final map = <String, Map<String, double>>{};
  for (final entry in pairs) {
    if (entry is! Map) continue;
    final pair = Map<String, dynamic>.from(entry);
    final label = pair['label'];
    final v2 = pair['v2'];
    if (label is! String || v2 is! Map) continue;
    final medians = v2['medians'];
    if (medians is! Map) continue;
    map[label] = _metricSubset(Map<String, dynamic>.from(medians));
  }

  for (final scenario in _requiredScenarios) {
    if (!map.containsKey(scenario)) {
      throw StateError(
        'Candidate A/B JSON missing required scenario "$scenario": $path',
      );
    }
  }

  return map;
}

_CandidateMeta _readCandidateMeta(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Candidate A/B JSON file not found: $path');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected candidate A/B format: $path');
  }

  return _CandidateMeta(
    repeats: _asInt(decoded['repeats']),
    warmupRuns: _asInt(decoded['warmup_runs']),
    device: (decoded['device'] as String?) ?? 'unknown',
  );
}

Map<String, double> _metricSubset(Map<String, dynamic> source) {
  return {
    for (final key in _metricKeys) key: _asDouble(source[key]),
  };
}

String _writeMarkdownReport({
  required String outputPath,
  required String baselineSummaryPath,
  required String candidateAbJsonPath,
  required _CandidateMeta candidateMeta,
  required Map<String, Map<String, double>> baseline,
  required Map<String, Map<String, double>> candidate,
  required Map<String, Map<String, double>> improvements,
  required List<_GateCheck> checks,
  required bool go,
}) {
  final report = StringBuffer()
    ..writeln('# Sprint 6 Gate Report (Automatizado)')
    ..writeln()
    ..writeln('- Fecha UTC: `${DateTime.now().toUtc().toIso8601String()}`')
    ..writeln('- Baseline summary: `$baselineSummaryPath`')
    ..writeln('- Candidate A/B JSON: `$candidateAbJsonPath`')
    ..writeln('- Device candidate: `${candidateMeta.device}`')
    ..writeln('- Repeats candidate: `${candidateMeta.repeats}`')
    ..writeln('- Warmup runs candidate: `${candidateMeta.warmupRuns}`')
    ..writeln()
    ..writeln('## Comparacion vs baseline Sprint 1 (lower-is-better)')
    ..writeln()
    ..writeln('| Scenario | Metric | Baseline | Candidate | Improvement |')
    ..writeln('|---|---|---:|---:|---:|');

  for (final scenario in _requiredScenarios) {
    for (final metric in _metricKeys) {
      report.writeln(
        '| `$scenario` | `$metric` | '
        '${_fmt(baseline[scenario]![metric]!)} | '
        '${_fmt(candidate[scenario]![metric]!)} | '
        '${_fmtPct(improvements[scenario]![metric]!)} |',
      );
    }
  }

  report
    ..writeln()
    ..writeln('## Checklist Go/No-Go')
    ..writeln()
    ..writeln('| Check | Target | Observed | Status |')
    ..writeln('|---|---|---|---|');

  for (final check in checks) {
    report.writeln(
      '| ${check.description} | ${check.target} | ${check.observed} | ${check.pass ? 'PASS' : 'FAIL'} |',
    );
  }

  report
    ..writeln()
    ..writeln('## Decision')
    ..writeln()
    ..writeln('**${go ? 'GO' : 'NO-GO'}**')
    ..writeln()
    ..writeln(
      go
          ? 'Todos los checks obligatorios pasan.'
          : 'Al menos un check obligatorio falla.',
    );

  File(outputPath).writeAsStringSync(report.toString());
  return outputPath;
}

String _writeJsonReport({
  required String outputPath,
  required String baselineSummaryPath,
  required String candidateAbJsonPath,
  required _CandidateMeta candidateMeta,
  required Map<String, Map<String, double>> baseline,
  required Map<String, Map<String, double>> candidate,
  required Map<String, Map<String, double>> improvements,
  required List<_GateCheck> checks,
  required bool go,
}) {
  final payload = <String, dynamic>{
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'baseline_summary_path': baselineSummaryPath,
    'candidate_ab_json_path': candidateAbJsonPath,
    'candidate_meta': {
      'device': candidateMeta.device,
      'repeats': candidateMeta.repeats,
      'warmup_runs': candidateMeta.warmupRuns,
    },
    'baseline_metrics': baseline,
    'candidate_metrics': candidate,
    'improvements_percent': improvements,
    'checks': checks
        .map(
          (check) => {
            'id': check.id,
            'description': check.description,
            'target': check.target,
            'observed': check.observed,
            'pass': check.pass,
          },
        )
        .toList(),
    'decision': {
      'go': go,
      'label': go ? 'GO' : 'NO-GO',
      'failed_checks': checks
          .where((check) => !check.pass)
          .map((check) => check.id)
          .toList(),
    },
  };

  File(outputPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(payload),
  );
  return outputPath;
}

double _improvementLowerIsBetter(double baseline, double candidate) {
  if (baseline == 0) return 0;
  return ((baseline - candidate) / baseline) * 100;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _fmt(double value) => value.toStringAsFixed(3);

String _fmtPct(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}
