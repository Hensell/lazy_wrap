import 'dart:convert';
import 'dart:io';

const _defaultBaselineSummary =
    'benchmarks/results/20260211_232622Z/summary.json';

class _ScenarioTuning {
  const _ScenarioTuning({
    this.batchSize,
    this.measureBatchSize,
    this.loadThreshold,
    this.cacheExtent,
  });

  final int? batchSize;
  final int? measureBatchSize;
  final double? loadThreshold;
  final double? cacheExtent;

  List<String> toArgs(String scenarioPrefix) {
    final args = <String>[];
    if (batchSize != null) {
      args.add('--$scenarioPrefix-batch-size');
      args.add('$batchSize');
    }
    if (measureBatchSize != null) {
      args.add('--$scenarioPrefix-measure-batch-size');
      args.add('$measureBatchSize');
    }
    if (loadThreshold != null) {
      args.add('--$scenarioPrefix-load-threshold');
      args.add(loadThreshold!.toStringAsFixed(3));
    }
    if (cacheExtent != null) {
      args.add('--$scenarioPrefix-cache-extent');
      args.add(cacheExtent!.toStringAsFixed(3));
    }
    return args;
  }

  String pretty() {
    final parts = <String>[];
    if (batchSize != null) parts.add('batch=$batchSize');
    if (measureBatchSize != null) parts.add('measure=$measureBatchSize');
    if (loadThreshold != null) {
      parts.add('threshold=${loadThreshold!.toStringAsFixed(0)}');
    }
    if (cacheExtent != null) {
      parts.add('cache=${cacheExtent!.toStringAsFixed(0)}');
    }
    return parts.isEmpty ? 'default' : parts.join(', ');
  }
}

class _Preset {
  const _Preset({
    required this.id,
    required this.description,
    required this.chip,
    required this.card,
  });

  final String id;
  final String description;
  final _ScenarioTuning chip;
  final _ScenarioTuning card;
}

const _presets = <_Preset>[
  _Preset(
    id: 'default',
    description: 'Baseline de la app benchmark sin overrides.',
    chip: _ScenarioTuning(),
    card: _ScenarioTuning(),
  ),
  _Preset(
    id: 'balanced_v1',
    description: 'Baja batch/measure y prefetch moderado en ambos escenarios.',
    chip: _ScenarioTuning(
      batchSize: 48,
      measureBatchSize: 16,
      loadThreshold: 220,
      cacheExtent: 260,
    ),
    card: _ScenarioTuning(
      batchSize: 64,
      measureBatchSize: 16,
      loadThreshold: 240,
      cacheExtent: 260,
    ),
  ),
  _Preset(
    id: 'aggressive_low_prefetch',
    description:
        'Minimiza trabajo inmediato con lotes chicos y menor prefetch.',
    chip: _ScenarioTuning(
      batchSize: 40,
      measureBatchSize: 12,
      loadThreshold: 180,
      cacheExtent: 220,
    ),
    card: _ScenarioTuning(
      batchSize: 56,
      measureBatchSize: 12,
      loadThreshold: 200,
      cacheExtent: 220,
    ),
  ),
  _Preset(
    id: 'memory_guard',
    description: 'Prioriza memoria con cacheExtent mas corto en cards.',
    chip: _ScenarioTuning(
      batchSize: 56,
      measureBatchSize: 16,
      loadThreshold: 240,
      cacheExtent: 220,
    ),
    card: _ScenarioTuning(
      batchSize: 64,
      measureBatchSize: 16,
      loadThreshold: 220,
      cacheExtent: 180,
    ),
  ),
  _Preset(
    id: 'hybrid_throughput_chip_balanced_card',
    description:
        'Combina chip de alto throughput con card balanceado para evitar regresiones fuertes en card.',
    chip: _ScenarioTuning(
      batchSize: 72,
      measureBatchSize: 24,
      loadThreshold: 300,
      cacheExtent: 320,
    ),
    card: _ScenarioTuning(
      batchSize: 64,
      measureBatchSize: 16,
      loadThreshold: 240,
      cacheExtent: 260,
    ),
  ),
  _Preset(
    id: 'throughput_high_batch',
    description: 'Favorece throughput con lotes grandes y mayor prefetch.',
    chip: _ScenarioTuning(
      batchSize: 72,
      measureBatchSize: 24,
      loadThreshold: 300,
      cacheExtent: 320,
    ),
    card: _ScenarioTuning(
      batchSize: 96,
      measureBatchSize: 24,
      loadThreshold: 320,
      cacheExtent: 320,
    ),
  ),
];

class _Config {
  const _Config({
    required this.deviceId,
    required this.frameBudgetMs,
    required this.repeats,
    required this.warmupRuns,
    required this.discardOutliers,
    required this.outlierIqrK,
    required this.baselineSummaryPath,
    required this.reportPath,
    required this.selectedPresetIds,
    required this.listPresetsOnly,
    required this.coverageReferencePairJsonPath,
    required this.coverageMinMaxBuiltIndexRatio,
    required this.coverageMinUniqueBuiltIndicesRatio,
  });

  final String? deviceId;
  final double frameBudgetMs;
  final int repeats;
  final int warmupRuns;
  final bool discardOutliers;
  final double outlierIqrK;
  final String baselineSummaryPath;
  final String reportPath;
  final Set<String> selectedPresetIds;
  final bool listPresetsOnly;
  final String? coverageReferencePairJsonPath;
  final double coverageMinMaxBuiltIndexRatio;
  final double coverageMinUniqueBuiltIndicesRatio;
}

class _ScenarioResult {
  const _ScenarioResult({
    required this.name,
    required this.medians,
    required this.improvement,
    required this.comparisonValid,
    required this.coverageGuardStatus,
  });

  final String name;
  final Map<String, double> medians;
  final Map<String, double> improvement;
  final bool comparisonValid;
  final String coverageGuardStatus;
}

class _PresetResult {
  const _PresetResult({
    required this.preset,
    required this.reportMarkdownPath,
    required this.reportJsonPath,
    required this.scenarioByName,
    required this.score,
    required this.severeRegressions,
    required this.invalidCoverageScenarios,
    required this.command,
  });

  final _Preset preset;
  final String reportMarkdownPath;
  final String reportJsonPath;
  final Map<String, _ScenarioResult> scenarioByName;
  final double score;
  final List<String> severeRegressions;
  final List<String> invalidCoverageScenarios;
  final String command;
}

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  if (config.listPresetsOnly) {
    _printPresetList();
    return;
  }

  final selectedPresets = _selectPresets(config.selectedPresetIds);
  if (selectedPresets.isEmpty) {
    throw StateError('No hay presets seleccionados.');
  }

  final sweepId = _timestampId(DateTime.now().toUtc());
  final outputDir = Directory('benchmarks/results/tuning_sweep/$sweepId')
    ..createSync(recursive: true);

  stdout.writeln('Running OffstageV1 tuning sweep');
  stdout.writeln('Sweep id: $sweepId');
  stdout.writeln('Device: ${config.deviceId ?? 'default'}');
  stdout.writeln('Frame budget: ${config.frameBudgetMs.toStringAsFixed(2)} ms');
  stdout.writeln('Repeats per scenario: ${config.repeats}');
  stdout.writeln('Warmups per scenario: ${config.warmupRuns}');
  stdout.writeln(
    'Outlier filter: ${config.discardOutliers ? 'enabled (IQR x${config.outlierIqrK.toStringAsFixed(2)})' : 'disabled'}',
  );
  stdout.writeln('Baseline summary: ${config.baselineSummaryPath}');
  if (config.coverageReferencePairJsonPath != null) {
    stdout.writeln(
      'Coverage guard: enabled '
      '(reference=${config.coverageReferencePairJsonPath}, '
      'max_index_ratio>=${config.coverageMinMaxBuiltIndexRatio.toStringAsFixed(2)}, '
      'unique_idx_ratio>=${config.coverageMinUniqueBuiltIndicesRatio.toStringAsFixed(2)})',
    );
  }
  stdout.writeln(
    'Selected presets: ${selectedPresets.map((p) => p.id).join(', ')}',
  );

  final results = <_PresetResult>[];

  for (var i = 0; i < selectedPresets.length; i++) {
    final preset = selectedPresets[i];
    stdout.writeln(
      '\n# Preset ${i + 1}/${selectedPresets.length}: ${preset.id}',
    );
    stdout.writeln('- Chip: ${preset.chip.pretty()}');
    stdout.writeln('- Card: ${preset.card.pretty()}');

    final presetMdPath = '${outputDir.path}/${preset.id}.md';
    final presetJsonPath = '${outputDir.path}/${preset.id}.json';

    final command = _buildPairCommand(
      config: config,
      preset: preset,
      reportMarkdownPath: presetMdPath,
      reportJsonPath: presetJsonPath,
    );

    stdout.writeln('==> dart ${command.join(' ')}');
    await _runProcessWithPrefix(
      executable: 'dart',
      arguments: command,
      prefix: '[${preset.id}] ',
    );

    final parsed = _parsePairJsonReport(presetJsonPath);
    final invalidCoverage = _findCoverageInvalidScenarios(parsed);
    final score = _computeScore(parsed);
    final severe = _findSevereRegressions(parsed, threshold: -15);
    final severeWithCoverage = <String>[
      ...severe,
      ...invalidCoverage.map((scenario) => 'coverage_guard.$scenario'),
    ];

    results.add(
      _PresetResult(
        preset: preset,
        reportMarkdownPath: presetMdPath,
        reportJsonPath: presetJsonPath,
        scenarioByName: parsed,
        score: score,
        severeRegressions: severeWithCoverage,
        invalidCoverageScenarios: invalidCoverage,
        command: 'dart ${command.join(' ')}',
      ),
    );
  }

  results.sort((a, b) => b.score.compareTo(a.score));

  final bestCandidate = results.first;
  final recommended = results
      .where(
        (entry) =>
            entry.invalidCoverageScenarios.isEmpty &&
            entry.severeRegressions.isEmpty &&
            entry.score > 0,
      )
      .firstOrNull;

  final reportText = _buildSweepReport(
    config: config,
    sweepId: sweepId,
    outputDir: outputDir.path,
    results: results,
    bestCandidate: bestCandidate,
    recommended: recommended,
  );

  File(config.reportPath).writeAsStringSync(reportText);

  final summaryJsonPath = '${outputDir.path}/summary.json';
  final summaryJson = <String, Object?>{
    'sweep_id': sweepId,
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'report_path': config.reportPath,
    'coverage_guard': <String, Object?>{
      'enabled': config.coverageReferencePairJsonPath != null,
      'reference_pair_json_path': config.coverageReferencePairJsonPath,
      'min_max_built_index_ratio': config.coverageMinMaxBuiltIndexRatio,
      'min_unique_built_indices_ratio':
          config.coverageMinUniqueBuiltIndicesRatio,
    },
    'recommended_preset': recommended?.preset.id,
    'best_candidate_preset': bestCandidate.preset.id,
    'results': results
        .map(
          (entry) => <String, Object?>{
            'preset': entry.preset.id,
            'score': entry.score,
            'severe_regressions': entry.severeRegressions,
            'invalid_coverage_scenarios': entry.invalidCoverageScenarios,
            'pair_report_markdown_path': entry.reportMarkdownPath,
            'pair_report_json_path': entry.reportJsonPath,
            'command': entry.command,
          },
        )
        .toList(),
  };
  File(summaryJsonPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(summaryJson),
  );

  stdout.writeln('\nSweep report: ${config.reportPath}');
  stdout.writeln('Sweep summary json: $summaryJsonPath');
  if (recommended == null) {
    stdout.writeln(
      'No hard recommendation (all presets have severe regressions or score <= 0).',
    );
    stdout.writeln(
      'Best candidate for further study: ${bestCandidate.preset.id}',
    );
  } else {
    stdout.writeln('Recommended preset: ${recommended.preset.id}');
  }
}

_Config _parseArgs(List<String> args) {
  String? deviceId;
  var frameBudgetMs = 16.67;
  var repeats = 2;
  var warmupRuns = 1;
  var discardOutliers = true;
  var outlierIqrK = 1.5;
  var baselineSummaryPath = _defaultBaselineSummary;
  var reportPath = 'benchmarks/offstage_v1_tuning_sweep_report.md';
  var listPresetsOnly = false;
  String? coverageReferencePairJsonPath;
  var coverageMinMaxBuiltIndexRatio = 0.8;
  var coverageMinUniqueBuiltIndicesRatio = 0.8;
  final selectedPresetIds = <String>{};

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      _printUsage();
      exit(0);
    }
    if (arg == '--list-presets') {
      listPresetsOnly = true;
      continue;
    }
    if (arg == '--preset' && i + 1 < args.length) {
      selectedPresetIds.add(args[++i]);
      continue;
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
    if (arg == '--baseline-summary' && i + 1 < args.length) {
      baselineSummaryPath = args[++i];
      continue;
    }
    if (arg == '--report-path' && i + 1 < args.length) {
      reportPath = args[++i];
      continue;
    }
    if (arg == '--coverage-reference-pair-json' && i + 1 < args.length) {
      coverageReferencePairJsonPath = args[++i];
      continue;
    }
    if (arg == '--coverage-min-max-index-ratio' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0 || parsed > 1) {
        throw ArgumentError('Invalid --coverage-min-max-index-ratio value.');
      }
      coverageMinMaxBuiltIndexRatio = parsed;
      continue;
    }
    if (arg == '--coverage-min-unique-index-ratio' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0 || parsed > 1) {
        throw ArgumentError(
          'Invalid --coverage-min-unique-index-ratio value.',
        );
      }
      coverageMinUniqueBuiltIndicesRatio = parsed;
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
    baselineSummaryPath: baselineSummaryPath,
    reportPath: reportPath,
    selectedPresetIds: selectedPresetIds,
    listPresetsOnly: listPresetsOnly,
    coverageReferencePairJsonPath: coverageReferencePairJsonPath,
    coverageMinMaxBuiltIndexRatio: coverageMinMaxBuiltIndexRatio,
    coverageMinUniqueBuiltIndicesRatio: coverageMinUniqueBuiltIndicesRatio,
  );
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run benchmarks/run_offstage_v1_tuning_sweep.dart [options]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --list-presets           Show available preset ids and exit.',
  );
  stdout.writeln('  --preset <id>            Filter preset (repeatable).');
  stdout.writeln('  --device <id>            Flutter device id (e.g., linux).');
  stdout.writeln(
    '  --frame-budget-ms <num> Jank threshold in ms (default: 16.67).',
  );
  stdout.writeln(
    '  --repeats <n>           Repetitions per scenario (default: 2).',
  );
  stdout.writeln(
    '  --warmup-runs <n>       Warmup runs discarded per scenario (default: 1).',
  );
  stdout.writeln(
    '  --outlier-iqr-k <num>   IQR multiplier for outlier filter (default: 1.5).',
  );
  stdout.writeln(
    '  --no-outlier-filter     Disable outlier filtering in median metrics.',
  );
  stdout.writeln(
    '  --baseline-summary <p>  Baseline summary path '
    '(default: $_defaultBaselineSummary).',
  );
  stdout.writeln(
    '  --report-path <p>       Sweep report markdown output '
    '(default: benchmarks/offstage_v1_tuning_sweep_report.md).',
  );
  stdout.writeln(
    '  --coverage-reference-pair-json <p> Reference pair JSON for coverage guard.',
  );
  stdout.writeln(
    '  --coverage-min-max-index-ratio <n> Min ratio candidate/reference for max_index (0-1, default: 0.8).',
  );
  stdout.writeln(
    '  --coverage-min-unique-index-ratio <n> Min ratio candidate/reference for uniq_idx (0-1, default: 0.8).',
  );
  stdout.writeln('  -h, --help              Show this help.');
}

void _printPresetList() {
  stdout.writeln('Available presets:');
  for (final preset in _presets) {
    stdout.writeln('- ${preset.id}: ${preset.description}');
    stdout.writeln('  chip: ${preset.chip.pretty()}');
    stdout.writeln('  card: ${preset.card.pretty()}');
  }
}

List<_Preset> _selectPresets(Set<String> selectedIds) {
  if (selectedIds.isEmpty) {
    return _presets;
  }

  final selected = <_Preset>[];
  final unknown = <String>[];

  for (final id in selectedIds) {
    final preset = _presets.where((entry) => entry.id == id).firstOrNull;
    if (preset == null) {
      unknown.add(id);
    } else {
      selected.add(preset);
    }
  }

  if (unknown.isNotEmpty) {
    throw ArgumentError('Unknown preset ids: ${unknown.join(', ')}');
  }

  return selected;
}

List<String> _buildPairCommand({
  required _Config config,
  required _Preset preset,
  required String reportMarkdownPath,
  required String reportJsonPath,
}) {
  return <String>[
    'run',
    'benchmarks/run_offstage_v1_pair.dart',
    '--frame-budget-ms',
    config.frameBudgetMs.toStringAsFixed(2),
    '--repeats',
    '${config.repeats}',
    '--warmup-runs',
    '${config.warmupRuns}',
    '--baseline-summary',
    config.baselineSummaryPath,
    '--report-path',
    reportMarkdownPath,
    '--json-report-path',
    reportJsonPath,
    if (config.coverageReferencePairJsonPath != null) ...[
      '--coverage-reference-pair-json',
      config.coverageReferencePairJsonPath!,
      '--coverage-min-max-index-ratio',
      config.coverageMinMaxBuiltIndexRatio.toStringAsFixed(3),
      '--coverage-min-unique-index-ratio',
      config.coverageMinUniqueBuiltIndicesRatio.toStringAsFixed(3),
    ],
    if (config.discardOutliers) ...[
      '--outlier-iqr-k',
      config.outlierIqrK.toStringAsFixed(3),
    ] else
      '--no-outlier-filter',
    if (config.deviceId != null) ...['--device', config.deviceId!],
    ...preset.chip.toArgs('chip'),
    ...preset.card.toArgs('card'),
  ];
}

Future<void> _runProcessWithPrefix({
  required String executable,
  required List<String> arguments,
  required String prefix,
}) async {
  final process = await Process.start(executable, arguments, runInShell: true);

  final stdoutDone = process.stdout.transform(utf8.decoder).listen((chunk) {
    stdout.write('$prefix$chunk');
  }).asFuture<void>();

  final stderrDone = process.stderr.transform(utf8.decoder).listen((chunk) {
    stderr.write('$prefix$chunk');
  }).asFuture<void>();

  final code = await process.exitCode;
  await stdoutDone;
  await stderrDone;

  if (code != 0) {
    throw ProcessException(executable, arguments, 'Exit code: $code', code);
  }
}

Map<String, _ScenarioResult> _parsePairJsonReport(String reportPath) {
  final file = File(reportPath);
  if (!file.existsSync()) {
    throw StateError('Pair JSON report not found: $reportPath');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected JSON report format: $reportPath');
  }

  final scenarios = decoded['scenarios'];
  if (scenarios is! List) {
    throw StateError('JSON report missing scenarios list: $reportPath');
  }

  final byName = <String, _ScenarioResult>{};
  for (final entry in scenarios) {
    if (entry is! Map) continue;
    final asMap = Map<String, dynamic>.from(entry);
    final name = asMap['scenario'];
    if (name is! String) continue;

    final mediansRaw = asMap['medians'];
    final improvementsRaw = asMap['improvement_vs_baseline_percent'];
    final comparisonValidRaw = asMap['comparison_valid'];
    final coverageGuardRaw = asMap['coverage_guard'];

    final medians = _asDoubleMap(mediansRaw);
    final improvements = _asDoubleMap(improvementsRaw);
    final comparisonValid = comparisonValidRaw is! bool || comparisonValidRaw;
    var coverageGuardStatus = comparisonValid ? 'pass' : 'invalid';
    if (coverageGuardRaw is Map) {
      final asGuardMap = Map<String, dynamic>.from(coverageGuardRaw);
      final status = asGuardMap['status'];
      if (status is String && status.isNotEmpty) {
        coverageGuardStatus = status;
      }
    }

    byName[name] = _ScenarioResult(
      name: name,
      medians: medians,
      improvement: improvements,
      comparisonValid: comparisonValid,
      coverageGuardStatus: coverageGuardStatus,
    );
  }

  return byName;
}

List<String> _findCoverageInvalidScenarios(
  Map<String, _ScenarioResult> scenarioByName,
) {
  final invalid = <String>[];
  for (final entry in scenarioByName.entries) {
    if (!entry.value.comparisonValid) {
      invalid.add(entry.key);
    }
  }
  return invalid;
}

Map<String, double> _asDoubleMap(Object? source) {
  if (source is! Map) return const <String, double>{};

  final values = <String, double>{};
  for (final entry in source.entries) {
    final key = entry.key;
    if (key is! String) continue;
    final value = _asDouble(entry.value);
    values[key] = value;
  }
  return values;
}

double _computeScore(Map<String, _ScenarioResult> scenarioByName) {
  const weights = <String, double>{
    'p95_build_ms': 0.25,
    'p95_raster_ms': 0.20,
    'jank_percent': 0.25,
    'peak_memory_mb': 0.20,
    'time_to_first_interaction_ms': 0.10,
  };

  final coverageInvalidCount = _findCoverageInvalidScenarios(
    scenarioByName,
  ).length;
  if (coverageInvalidCount > 0) {
    return -10000.0 - (coverageInvalidCount * 100.0);
  }

  final scenarioNames = <String>['dynamic_chip_10k', 'dynamic_card_50k'];
  var accumulated = 0.0;
  var count = 0;

  for (final scenarioName in scenarioNames) {
    final scenario = scenarioByName[scenarioName];
    if (scenario == null) continue;

    var scenarioScore = 0.0;
    for (final entry in weights.entries) {
      final improvement = scenario.improvement[entry.key] ?? 0.0;
      scenarioScore += improvement * entry.value;
    }

    accumulated += scenarioScore;
    count++;
  }

  if (count == 0) return -9999;

  final average = accumulated / count;
  final severe = _findSevereRegressions(scenarioByName, threshold: -15);
  return average - (severe.length * 10.0);
}

List<String> _findSevereRegressions(
  Map<String, _ScenarioResult> scenarioByName, {
  required double threshold,
}) {
  final severe = <String>[];

  for (final scenarioEntry in scenarioByName.entries) {
    for (final metricEntry in scenarioEntry.value.improvement.entries) {
      if (metricEntry.value < threshold) {
        severe.add('${scenarioEntry.key}.${metricEntry.key}');
      }
    }
  }

  return severe;
}

String _buildSweepReport({
  required _Config config,
  required String sweepId,
  required String outputDir,
  required List<_PresetResult> results,
  required _PresetResult bestCandidate,
  required _PresetResult? recommended,
}) {
  final report = StringBuffer()
    ..writeln('# OffstageV1 Tuning Sweep Report')
    ..writeln()
    ..writeln('- Fecha UTC: `${DateTime.now().toUtc().toIso8601String()}`')
    ..writeln('- Sweep id: `$sweepId`')
    ..writeln('- Device: `${config.deviceId ?? 'default'}`')
    ..writeln('- Frame budget: `${config.frameBudgetMs.toStringAsFixed(2)} ms`')
    ..writeln('- Repeticiones por escenario: `${config.repeats}`')
    ..writeln('- Warmups descartados por escenario: `${config.warmupRuns}`')
    ..writeln(
      '- Outlier filter: `${config.discardOutliers ? 'enabled (IQR x${config.outlierIqrK.toStringAsFixed(2)})' : 'disabled'}`',
    )
    ..writeln('- Baseline summary: `${config.baselineSummaryPath}`')
    ..writeln(
      '- Coverage guard: '
      '${config.coverageReferencePairJsonPath == null ? 'disabled' : 'enabled (ref=${config.coverageReferencePairJsonPath}, max_ratio>=${config.coverageMinMaxBuiltIndexRatio.toStringAsFixed(2)}, unique_ratio>=${config.coverageMinUniqueBuiltIndicesRatio.toStringAsFixed(2)})'}',
    )
    ..writeln('- Output dir: `$outputDir`')
    ..writeln()
    ..writeln('## Ranking')
    ..writeln()
    ..writeln(
      '| Rank | Preset | Score | Coverage | Chip jank | Chip build | Card memoria | Card build | Regr. severas |',
    )
    ..writeln('|---:|---|---:|---|---:|---:|---:|---:|---|');

  for (var i = 0; i < results.length; i++) {
    final entry = results[i];
    final chip = entry.scenarioByName['dynamic_chip_10k'];
    final card = entry.scenarioByName['dynamic_card_50k'];

    final chipJank = chip?.improvement['jank_percent'];
    final chipBuild = chip?.improvement['p95_build_ms'];
    final cardMem = card?.improvement['peak_memory_mb'];
    final cardBuild = card?.improvement['p95_build_ms'];
    final coverageStatus = entry.invalidCoverageScenarios.isEmpty
        ? 'pass'
        : 'fail (${entry.invalidCoverageScenarios.join(', ')})';

    report.writeln(
      '| ${i + 1} | `${entry.preset.id}` | '
      '${entry.score.toStringAsFixed(2)} | '
      '$coverageStatus | '
      '${_fmtPct(chipJank)} | '
      '${_fmtPct(chipBuild)} | '
      '${_fmtPct(cardMem)} | '
      '${_fmtPct(cardBuild)} | '
      '${entry.severeRegressions.isEmpty ? 'none' : entry.severeRegressions.join(', ')} |',
    );
  }

  report
    ..writeln()
    ..writeln('## Recomendacion')
    ..writeln()
    ..writeln('- Mejor candidato observado: `${bestCandidate.preset.id}`')
    ..writeln('- Score: `${bestCandidate.score.toStringAsFixed(2)}`');

  if (recommended == null) {
    report
      ..writeln(
        '- Decision: **No-Go para tuning preset** en esta tanda; mantener configuracion actual.',
      )
      ..writeln(
        '- Motivo: ningun preset obtuvo score positivo sin regresiones severas.',
      )
      ..writeln('- Comando del mejor candidato (solo exploratorio):')
      ..writeln()
      ..writeln('```bash')
      ..writeln(bestCandidate.command)
      ..writeln('```')
      ..writeln();
  } else {
    report
      ..writeln('- Preset recomendado: `${recommended.preset.id}`')
      ..writeln(
        '- Motivo: mejor score global con riesgo controlado (sin regresiones severas).',
      )
      ..writeln('- Comando de reproduccion:')
      ..writeln()
      ..writeln('```bash')
      ..writeln(recommended.command)
      ..writeln('```')
      ..writeln();
  }

  report
    ..writeln('## Detalle por preset')
    ..writeln();

  for (final entry in results) {
    report
      ..writeln('### `${entry.preset.id}`')
      ..writeln()
      ..writeln('- Score: `${entry.score.toStringAsFixed(2)}`')
      ..writeln('- Descripcion: ${entry.preset.description}')
      ..writeln('- Chip tuning: `${entry.preset.chip.pretty()}`')
      ..writeln('- Card tuning: `${entry.preset.card.pretty()}`')
      ..writeln('- Pair report (md): `${entry.reportMarkdownPath}`')
      ..writeln('- Pair report (json): `${entry.reportJsonPath}`')
      ..writeln(
        '- Coverage guard: '
        '${entry.invalidCoverageScenarios.isEmpty ? 'pass' : 'fail (${entry.invalidCoverageScenarios.join(', ')})'}',
      )
      ..writeln(
        '- Regresiones severas: '
        '${entry.severeRegressions.isEmpty ? 'none' : entry.severeRegressions.join(', ')}',
      )
      ..writeln()
      ..writeln('| Escenario | build | raster | jank | memoria | tti |')
      ..writeln('|---|---:|---:|---:|---:|---:|');

    final scenarioNames = <String>['dynamic_chip_10k', 'dynamic_card_50k'];
    for (final scenarioName in scenarioNames) {
      final scenario = entry.scenarioByName[scenarioName];
      if (scenario == null) {
        report.writeln('| `$scenarioName` | n/a | n/a | n/a | n/a | n/a |');
        continue;
      }
      if (!scenario.comparisonValid) {
        report.writeln(
          '| `$scenarioName` | n/a* | n/a* | n/a* | n/a* | n/a* |',
        );
        continue;
      }

      report.writeln(
        '| `$scenarioName` | '
        '${_fmtPct(scenario.improvement['p95_build_ms'])} | '
        '${_fmtPct(scenario.improvement['p95_raster_ms'])} | '
        '${_fmtPct(scenario.improvement['jank_percent'])} | '
        '${_fmtPct(scenario.improvement['peak_memory_mb'])} | '
        '${_fmtPct(scenario.improvement['time_to_first_interaction_ms'])} |',
      );
    }

    report
      ..writeln()
      ..writeln('| Escenario | p95_build | p95_raster | jank | memoria | tti |')
      ..writeln('|---|---:|---:|---:|---:|---:|');

    for (final scenarioName in scenarioNames) {
      final scenario = entry.scenarioByName[scenarioName];
      if (scenario == null) {
        report.writeln('| `$scenarioName` | n/a | n/a | n/a | n/a | n/a |');
        continue;
      }

      report.writeln(
        '| `$scenarioName` | '
        '${_fmtNumber(scenario.medians['p95_build_ms'])} | '
        '${_fmtNumber(scenario.medians['p95_raster_ms'])} | '
        '${_fmtNumber(scenario.medians['jank_percent'])} | '
        '${_fmtNumber(scenario.medians['peak_memory_mb'])} | '
        '${_fmtNumber(scenario.medians['time_to_first_interaction_ms'])} |',
      );
    }

    if (entry.invalidCoverageScenarios.isNotEmpty) {
      report
        ..writeln()
        ..writeln(
          '`n/a*`: comparacion invalidada por coverage guard para este preset.',
        );
    }

    report.writeln();
  }

  return report.toString();
}

String _timestampId(DateTime dateTime) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}${two(dateTime.month)}${two(dateTime.day)}_'
      '${two(dateTime.hour)}${two(dateTime.minute)}${two(dateTime.second)}Z';
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _fmtNumber(double? value) {
  if (value == null) return 'n/a';
  return value.toStringAsFixed(3);
}

String _fmtPct(double? value) {
  if (value == null) return 'n/a';
  return '${value.toStringAsFixed(2)}%';
}

extension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
