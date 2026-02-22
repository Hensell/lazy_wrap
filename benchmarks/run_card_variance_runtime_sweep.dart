import 'dart:convert';
import 'dart:io';

const _defaultScenario = 'dynamic_card_50k';
const _defaultReportPath = 'benchmarks/card_variance_runtime_sweep_report.md';

class _Preset {
  const _Preset({
    required this.id,
    required this.description,
    required this.defines,
  });

  final String id;
  final String description;
  final Map<String, String> defines;
}

const _presets = <_Preset>[
  _Preset(
    id: 'default',
    description: 'Configuracion default actual de Offstage V1 para card.',
    defines: <String, String>{},
  ),
  _Preset(
    id: 'conservative_batches',
    description: 'Reduce lote y prefetch para suavizar churn por corrida.',
    defines: <String, String>{
      'OFFSTAGE_CARD_BATCH_SIZE': '64',
      'OFFSTAGE_CARD_MEASURE_BATCH_SIZE': '16',
      'OFFSTAGE_CARD_LOAD_THRESHOLD': '240',
      'OFFSTAGE_CARD_CACHE_EXTENT': '260',
    },
  ),
  _Preset(
    id: 'incremental_load',
    description: 'Activa carga incremental para evitar picos de append.',
    defines: <String, String>{
      'OFFSTAGE_INCREMENTAL_LOAD': 'true',
    },
  ),
  _Preset(
    id: 'single_measure_batch',
    description: 'Solo un batch de medicion activo por frame.',
    defines: <String, String>{
      'OFFSTAGE_SINGLE_MEASURE_BATCH': 'true',
    },
  ),
  _Preset(
    id: 'incremental_plus_single_measure',
    description: 'Combina carga incremental con una sola medicion concurrente.',
    defines: <String, String>{
      'OFFSTAGE_INCREMENTAL_LOAD': 'true',
      'OFFSTAGE_SINGLE_MEASURE_BATCH': 'true',
    },
  ),
  _Preset(
    id: 'adaptive_measure_cap4',
    description:
        'Measure batch adaptativo con cap agresivo para items grandes.',
    defines: <String, String>{
      'OFFSTAGE_ADAPTIVE_MEASURE_BATCH': 'true',
      'OFFSTAGE_LARGE_ITEM_MEASURE_BATCH_CAP': '4',
    },
  ),
  _Preset(
    id: 'no_visible_cache',
    description: 'Desactiva cache de widgets visibles para aislar su efecto.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '0',
    },
  ),
  _Preset(
    id: 'fixed_visible_cache_128',
    description: 'Cache visible fija (128) sin adaptivo.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '128',
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'false',
    },
  ),
  _Preset(
    id: 'fixed_visible_cache_192',
    description: 'Cache visible fija (192) sin adaptivo.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '192',
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'false',
    },
  ),
  _Preset(
    id: 'fixed_visible_cache_256',
    description: 'Cache visible fija (sin adaptivo) para comparar estabilidad.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '256',
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'false',
    },
  ),
  _Preset(
    id: 'fixed_visible_cache_320',
    description: 'Cache visible fija (320) sin adaptivo.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '320',
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'false',
    },
  ),
  _Preset(
    id: 'fixed_visible_cache_384',
    description: 'Cache visible fija (384) sin adaptivo.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '384',
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'false',
    },
  ),
  _Preset(
    id: 'fixed384_single_measure',
    description: 'Cache fija 384 + single measure batch.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '384',
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'false',
      'OFFSTAGE_SINGLE_MEASURE_BATCH': 'true',
    },
  ),
  _Preset(
    id: 'fixed384_incremental',
    description: 'Cache fija 384 + carga incremental.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '384',
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'false',
      'OFFSTAGE_INCREMENTAL_LOAD': 'true',
    },
  ),
  _Preset(
    id: 'fixed384_single_measure_conservative',
    description: 'Cache fija 384 + single measure + batches conservadores.',
    defines: <String, String>{
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '384',
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'false',
      'OFFSTAGE_SINGLE_MEASURE_BATCH': 'true',
      'OFFSTAGE_CARD_BATCH_SIZE': '64',
      'OFFSTAGE_CARD_MEASURE_BATCH_SIZE': '16',
      'OFFSTAGE_CARD_LOAD_THRESHOLD': '240',
      'OFFSTAGE_CARD_CACHE_EXTENT': '260',
    },
  ),
];

class _Config {
  const _Config({
    required this.scenario,
    required this.deviceId,
    required this.frameBudgetMs,
    required this.repeats,
    required this.warmupRuns,
    required this.maxJankCvPercent,
    required this.maxJankMadPercent,
    required this.stableScrollProfile,
    required this.outputDir,
    required this.reportPath,
    required this.selectedPresetIds,
    required this.listPresetsOnly,
    required this.extraDefines,
  });

  final String scenario;
  final String? deviceId;
  final double frameBudgetMs;
  final int repeats;
  final int warmupRuns;
  final double maxJankCvPercent;
  final double maxJankMadPercent;
  final bool stableScrollProfile;
  final String outputDir;
  final String reportPath;
  final Set<String> selectedPresetIds;
  final bool listPresetsOnly;
  final Map<String, String> extraDefines;
}

class _PresetResult {
  const _PresetResult({
    required this.preset,
    required this.metricsJsonPath,
    required this.reportPath,
    required this.runIdsPath,
    required this.command,
    required this.appliedDefines,
    required this.jankCvPercent,
    required this.jankMadPercent,
    required this.jankMedian,
    required this.p95BuildMedian,
    required this.p95RasterMedian,
    required this.peakMemoryMedian,
    required this.ttiMedian,
    required this.cvGatePass,
    required this.madGatePass,
  });

  final _Preset preset;
  final String metricsJsonPath;
  final String reportPath;
  final String runIdsPath;
  final String command;
  final Map<String, String> appliedDefines;
  final double jankCvPercent;
  final double jankMadPercent;
  final double jankMedian;
  final double p95BuildMedian;
  final double p95RasterMedian;
  final double peakMemoryMedian;
  final double ttiMedian;
  final bool cvGatePass;
  final bool madGatePass;

  bool get bothGatesPass => cvGatePass && madGatePass;
}

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  if (config.listPresetsOnly) {
    _printPresetList();
    return;
  }

  final selectedPresets = _selectPresets(config.selectedPresetIds);
  if (selectedPresets.isEmpty) {
    throw StateError('No hay presets seleccionados para el sweep runtime.');
  }

  final outputDir = Directory(config.outputDir)..createSync(recursive: true);

  stdout.writeln('Running card variance runtime sweep');
  stdout.writeln('Scenario: ${config.scenario}');
  stdout.writeln('Device: ${config.deviceId ?? 'default'}');
  stdout.writeln('Frame budget: ${config.frameBudgetMs.toStringAsFixed(2)} ms');
  stdout.writeln('Repeats: ${config.repeats}');
  stdout.writeln('Warmup runs: ${config.warmupRuns}');
  stdout.writeln(
    'CV threshold: ${config.maxJankCvPercent.toStringAsFixed(2)}%',
  );
  stdout.writeln(
    'MAD threshold: ${config.maxJankMadPercent.toStringAsFixed(2)}%',
  );
  stdout.writeln('Stable scroll profile: ${config.stableScrollProfile}');
  if (config.extraDefines.isNotEmpty) {
    stdout.writeln('Extra defines: ${_formatDefines(config.extraDefines)}');
  }
  stdout.writeln(
    'Selected presets: ${selectedPresets.map((preset) => preset.id).join(', ')}',
  );

  final results = <_PresetResult>[];
  for (var i = 0; i < selectedPresets.length; i++) {
    final preset = selectedPresets[i];
    stdout.writeln(
      '\n# Preset ${i + 1}/${selectedPresets.length}: ${preset.id}',
    );
    stdout.writeln('- ${preset.description}');

    final outputPrefix = '${outputDir.path}/${preset.id}';
    final metricsJsonPath = '${outputPrefix}_metrics.json';
    final reportPath = '${outputPrefix}_report.md';
    final runIdsPath = '${outputPrefix}_run_ids.txt';

    final appliedDefines = <String, String>{
      ...preset.defines,
      ...config.extraDefines,
    };

    final command = _buildVarianceCommand(
      config: config,
      outputPrefix: outputPrefix,
      appliedDefines: appliedDefines,
    );

    stdout.writeln('==> dart ${command.join(' ')}');
    await _runProcessWithPrefix(
      executable: 'dart',
      arguments: command,
      prefix: '[${preset.id}] ',
    );

    final result = _readPresetResult(
      preset: preset,
      metricsJsonPath: metricsJsonPath,
      reportPath: reportPath,
      runIdsPath: runIdsPath,
      command: 'dart ${command.join(' ')}',
      appliedDefines: appliedDefines,
      cvThreshold: config.maxJankCvPercent,
      madThreshold: config.maxJankMadPercent,
    );
    results.add(result);
  }

  final rankedResults = results.toList()..sort(_comparePresetResult);
  final recommended = rankedResults.first;

  final reportText = _buildMarkdownReport(
    generatedAtUtc: DateTime.now().toUtc().toIso8601String(),
    config: config,
    results: rankedResults,
    recommended: recommended,
  );

  final reportFile = File(config.reportPath);
  reportFile.parent.createSync(recursive: true);
  reportFile.writeAsStringSync(reportText);

  final summaryPath = '${outputDir.path}/summary.json';
  final summaryJson = <String, Object?>{
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'scenario': config.scenario,
    'device_id': config.deviceId,
    'frame_budget_ms': config.frameBudgetMs,
    'repeats': config.repeats,
    'warmup_runs': config.warmupRuns,
    'stable_scroll_profile': config.stableScrollProfile,
    'thresholds': <String, double>{
      'cv_percent': config.maxJankCvPercent,
      'mad_percent_of_median': config.maxJankMadPercent,
    },
    'selected_presets': selectedPresets.map((preset) => preset.id).toList(),
    'recommended_preset': recommended.preset.id,
    'results': rankedResults
        .map(
          (result) => <String, Object?>{
            'preset': result.preset.id,
            'description': result.preset.description,
            'applied_defines': result.appliedDefines,
            'jank_cv_percent': _round(result.jankCvPercent, decimals: 2),
            'jank_mad_percent_of_median': _round(
              result.jankMadPercent,
              decimals: 2,
            ),
            'jank_median_percent': _round(result.jankMedian, decimals: 3),
            'p95_build_median_ms': _round(result.p95BuildMedian, decimals: 3),
            'p95_raster_median_ms': _round(
              result.p95RasterMedian,
              decimals: 3,
            ),
            'peak_memory_median_mb': _round(
              result.peakMemoryMedian,
              decimals: 3,
            ),
            'tti_median_ms': _round(result.ttiMedian, decimals: 3),
            'cv_gate_pass': result.cvGatePass,
            'mad_gate_pass': result.madGatePass,
            'both_gates_pass': result.bothGatesPass,
            'artifacts': <String, String>{
              'metrics_json': result.metricsJsonPath,
              'report_md': result.reportPath,
              'run_ids': result.runIdsPath,
            },
            'command': result.command,
          },
        )
        .toList(),
    'report_path': config.reportPath,
  };

  File(summaryPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(summaryJson),
  );

  stdout.writeln('\nRuntime sweep report: ${config.reportPath}');
  stdout.writeln('Runtime sweep summary: $summaryPath');
  stdout.writeln('Recommended preset: ${recommended.preset.id}');
}

_Config _parseArgs(List<String> args) {
  var scenario = _defaultScenario;
  String? deviceId;
  var frameBudgetMs = 16.67;
  var repeats = 7;
  var warmupRuns = 2;
  var maxJankCvPercent = 30.0;
  var maxJankMadPercent = 30.0;
  var stableScrollProfile = false;
  var reportPath = _defaultReportPath;
  var outputDir =
      'benchmarks/results/experiments/'
      '${_dateStamp(DateTime.now().toUtc())}_card_variance_runtime_sweep';
  var listPresetsOnly = false;
  final selectedPresetIds = <String>{};
  final extraDefines = <String, String>{};

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
    if (arg == '--scenario' && i + 1 < args.length) {
      scenario = args[++i];
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
    if (arg == '--max-jank-cv' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --max-jank-cv value.');
      }
      maxJankCvPercent = parsed;
      continue;
    }
    if (arg == '--max-jank-mad-percent' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --max-jank-mad-percent value.');
      }
      maxJankMadPercent = parsed;
      continue;
    }
    if (arg == '--stable-scroll-profile') {
      stableScrollProfile = true;
      continue;
    }
    if (arg == '--output-dir' && i + 1 < args.length) {
      outputDir = args[++i];
      continue;
    }
    if (arg == '--report-path' && i + 1 < args.length) {
      reportPath = args[++i];
      continue;
    }
    if (arg == '--define' && i + 1 < args.length) {
      final raw = args[++i];
      final separator = raw.indexOf('=');
      if (separator <= 0 || separator == raw.length - 1) {
        throw ArgumentError('Invalid --define format. Use KEY=VALUE.');
      }
      final key = raw.substring(0, separator).trim();
      final value = raw.substring(separator + 1).trim();
      if (key.isEmpty || value.isEmpty) {
        throw ArgumentError('Invalid --define format. Use KEY=VALUE.');
      }
      extraDefines[key] = value;
      continue;
    }

    throw ArgumentError('Unknown argument: $arg');
  }

  return _Config(
    scenario: scenario,
    deviceId: deviceId,
    frameBudgetMs: frameBudgetMs,
    repeats: repeats,
    warmupRuns: warmupRuns,
    maxJankCvPercent: maxJankCvPercent,
    maxJankMadPercent: maxJankMadPercent,
    stableScrollProfile: stableScrollProfile,
    outputDir: outputDir,
    reportPath: reportPath,
    selectedPresetIds: selectedPresetIds,
    listPresetsOnly: listPresetsOnly,
    extraDefines: Map<String, String>.unmodifiable(extraDefines),
  );
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run benchmarks/run_card_variance_runtime_sweep.dart [options]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --list-presets              List available runtime presets and exit.',
  );
  stdout.writeln('  --preset <id>               Select preset (repeatable).');
  stdout.writeln(
    '  --scenario <name>           Scenario to evaluate (default: $_defaultScenario).',
  );
  stdout.writeln(
    '  --device <id>               Flutter device id (e.g., linux).',
  );
  stdout.writeln(
    '  --frame-budget-ms <num>     Jank frame budget (default: 16.67).',
  );
  stdout.writeln(
    '  --repeats <n>               Measured runs per preset (default: 7).',
  );
  stdout.writeln(
    '  --warmup-runs <n>           Warmup runs per preset (default: 2).',
  );
  stdout.writeln(
    '  --max-jank-cv <num>         CV threshold for ranking/pass (default: 30).',
  );
  stdout.writeln(
    '  --max-jank-mad-percent <n>  MAD threshold for ranking/pass (default: 30).',
  );
  stdout.writeln(
    '  --stable-scroll-profile     Run all presets using stable scroll profile.',
  );
  stdout.writeln(
    '  --output-dir <path>         Directory for per-preset artifacts.',
  );
  stdout.writeln(
    '  --report-path <path>        Markdown summary output '
    '(default: $_defaultReportPath).',
  );
  stdout.writeln(
    '  --define KEY=VALUE          Extra dart-define for all presets (overrides preset key).',
  );
  stdout.writeln('  -h, --help                  Show this help.');
}

void _printPresetList() {
  stdout.writeln('Available card variance runtime presets:');
  for (final preset in _presets) {
    stdout.writeln('- ${preset.id}: ${preset.description}');
    if (preset.defines.isEmpty) {
      stdout.writeln('  defines: <none>');
      continue;
    }
    stdout.writeln('  defines: ${_formatDefines(preset.defines)}');
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

List<String> _buildVarianceCommand({
  required _Config config,
  required String outputPrefix,
  required Map<String, String> appliedDefines,
}) {
  final command = <String>[
    'run',
    'benchmarks/run_card_variance.dart',
    '--scenario',
    config.scenario,
    '--frame-budget-ms',
    config.frameBudgetMs.toStringAsFixed(2),
    '--repeats',
    '${config.repeats}',
    '--warmup-runs',
    '${config.warmupRuns}',
    '--max-jank-cv',
    config.maxJankCvPercent.toStringAsFixed(2),
    '--max-jank-mad-percent',
    config.maxJankMadPercent.toStringAsFixed(2),
    '--output-prefix',
    outputPrefix,
    if (config.deviceId != null) ...['--device', config.deviceId!],
    if (config.stableScrollProfile) '--stable-scroll-profile',
  ];

  final defineEntries = appliedDefines.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in defineEntries) {
    command.addAll(<String>['--define', '${entry.key}=${entry.value}']);
  }

  return command;
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

_PresetResult _readPresetResult({
  required _Preset preset,
  required String metricsJsonPath,
  required String reportPath,
  required String runIdsPath,
  required String command,
  required Map<String, String> appliedDefines,
  required double cvThreshold,
  required double madThreshold,
}) {
  final file = File(metricsJsonPath);
  if (!file.existsSync()) {
    throw StateError('Variance metrics JSON not found: $metricsJsonPath');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Invalid JSON format in $metricsJsonPath');
  }

  final jankCvPercent = _asDouble(
    _readPath(decoded, <Object>['metrics', 'jank_percent', 'cv_percent']),
  );
  final jankMadPercent = _asDouble(
    _readPath(
      decoded,
      <Object>['robust_jank_dispersion', 'mad_percent_of_median'],
    ),
  );
  final jankMedian = _asDouble(
    _readPath(decoded, <Object>['metrics', 'jank_percent', 'median']),
  );
  final p95BuildMedian = _asDouble(
    _readPath(decoded, <Object>['metrics', 'p95_build_ms', 'median']),
  );
  final p95RasterMedian = _asDouble(
    _readPath(decoded, <Object>['metrics', 'p95_raster_ms', 'median']),
  );
  final peakMemoryMedian = _asDouble(
    _readPath(decoded, <Object>['metrics', 'peak_memory_mb', 'median']),
  );
  final ttiMedian = _asDouble(
    _readPath(
      decoded,
      <Object>['metrics', 'time_to_first_interaction_ms', 'median'],
    ),
  );

  final cvGatePass = jankCvPercent <= cvThreshold;
  final madGatePass = jankMadPercent <= madThreshold;

  return _PresetResult(
    preset: preset,
    metricsJsonPath: metricsJsonPath,
    reportPath: reportPath,
    runIdsPath: runIdsPath,
    command: command,
    appliedDefines: Map<String, String>.unmodifiable(appliedDefines),
    jankCvPercent: jankCvPercent,
    jankMadPercent: jankMadPercent,
    jankMedian: jankMedian,
    p95BuildMedian: p95BuildMedian,
    p95RasterMedian: p95RasterMedian,
    peakMemoryMedian: peakMemoryMedian,
    ttiMedian: ttiMedian,
    cvGatePass: cvGatePass,
    madGatePass: madGatePass,
  );
}

int _comparePresetResult(_PresetResult a, _PresetResult b) {
  final passComparison = _boolScore(b.bothGatesPass).compareTo(
    _boolScore(a.bothGatesPass),
  );
  if (passComparison != 0) return passComparison;

  final cvComparison = a.jankCvPercent.compareTo(b.jankCvPercent);
  if (cvComparison != 0) return cvComparison;

  final madComparison = a.jankMadPercent.compareTo(b.jankMadPercent);
  if (madComparison != 0) return madComparison;

  final jankMedianComparison = a.jankMedian.compareTo(b.jankMedian);
  if (jankMedianComparison != 0) return jankMedianComparison;

  final buildComparison = a.p95BuildMedian.compareTo(b.p95BuildMedian);
  if (buildComparison != 0) return buildComparison;

  final rasterComparison = a.p95RasterMedian.compareTo(b.p95RasterMedian);
  if (rasterComparison != 0) return rasterComparison;

  final memoryComparison = a.peakMemoryMedian.compareTo(b.peakMemoryMedian);
  if (memoryComparison != 0) return memoryComparison;

  return a.ttiMedian.compareTo(b.ttiMedian);
}

int _boolScore(bool value) => value ? 1 : 0;

String _buildMarkdownReport({
  required String generatedAtUtc,
  required _Config config,
  required List<_PresetResult> results,
  required _PresetResult recommended,
}) {
  final buffer = StringBuffer()
    ..writeln(
      '# Card Variance Runtime Sweep (${config.scenario}, r${config.repeats}, w${config.warmupRuns})',
    )
    ..writeln()
    ..writeln('- Fecha UTC: `$generatedAtUtc`')
    ..writeln('- Device: `${config.deviceId ?? 'default'}`')
    ..writeln('- Frame budget: `${config.frameBudgetMs.toStringAsFixed(2)} ms`')
    ..writeln(
      '- Stable scroll profile: `${config.stableScrollProfile}`',
    )
    ..writeln(
      '- Threshold CV: `${config.maxJankCvPercent.toStringAsFixed(2)}%`',
    )
    ..writeln(
      '- Threshold MAD: `${config.maxJankMadPercent.toStringAsFixed(2)}%`',
    )
    ..writeln('- Preset recomendado: `${recommended.preset.id}`')
    ..writeln()
    ..writeln('## Resultados')
    ..writeln()
    ..writeln(
      '| preset | cv%jank | mad%/mediana | mediana_jank% | mediana_p95_build | mediana_p95_raster | mediana_memoria_mb | mediana_tti_ms | pass_cv | pass_mad | pass_ambos |',
    )
    ..writeln('|---|---:|---:|---:|---:|---:|---:|---:|---|---|---|');

  for (final result in results) {
    buffer.writeln(
      '| `${result.preset.id}` | '
      '${_fmtNum(result.jankCvPercent, 2)} | '
      '${_fmtNum(result.jankMadPercent, 2)} | '
      '${_fmtNum(result.jankMedian, 3)} | '
      '${_fmtNum(result.p95BuildMedian, 3)} | '
      '${_fmtNum(result.p95RasterMedian, 3)} | '
      '${_fmtNum(result.peakMemoryMedian, 3)} | '
      '${_fmtNum(result.ttiMedian, 3)} | '
      '${result.cvGatePass ? 'PASS' : 'FAIL'} | '
      '${result.madGatePass ? 'PASS' : 'FAIL'} | '
      '${result.bothGatesPass ? 'PASS' : 'FAIL'} |',
    );
  }

  buffer
    ..writeln()
    ..writeln('## Defines aplicados por preset')
    ..writeln();

  for (final result in results) {
    final definesText = result.appliedDefines.isEmpty
        ? '<none>'
        : _formatDefines(result.appliedDefines);
    buffer.writeln('- `${result.preset.id}`: `$definesText`');
  }

  buffer
    ..writeln()
    ..writeln('## Artefactos por preset')
    ..writeln();

  for (final result in results) {
    buffer
      ..writeln('- `${result.preset.id}`:')
      ..writeln('  - metrics_json: `${result.metricsJsonPath}`')
      ..writeln('  - report_md: `${result.reportPath}`')
      ..writeln('  - run_ids: `${result.runIdsPath}`')
      ..writeln('  - command: `${result.command}`');
  }

  buffer
    ..writeln()
    ..writeln('## Lectura')
    ..writeln()
    ..writeln(
      '1. Ranking prioriza estabilidad de `%jank` (pass CV+MAD, luego menor CV y menor MAD).',
    )
    ..writeln(
      '2. Si ningun preset pasa ambos gates, tratar el recomendado como siguiente candidato de experimento, no como cambio de default.',
    );

  return buffer.toString();
}

Object? _readPath(Map<String, dynamic> source, List<Object> path) {
  Object? current = source;
  for (final segment in path) {
    if (current is Map && current.containsKey(segment)) {
      current = current[segment];
      continue;
    }
    return null;
  }
  return current;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double _round(double value, {required int decimals}) {
  final factor = _pow10(decimals);
  return (value * factor).round() / factor;
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

String _fmtNum(double value, int decimals) => value.toStringAsFixed(decimals);

String _dateStamp(DateTime utc) {
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '$year$month$day';
}

String _formatDefines(Map<String, String> defines) {
  final entries = defines.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((entry) => '${entry.key}=${entry.value}').join(', ');
}
