import 'dart:convert';
import 'dart:io';

const _variants = <String>['dynamic_chip_10k', 'dynamic_card_50k'];

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  stdout.writeln('Running offstageV1 pair benchmark (chip + card)');
  stdout.writeln('Device: ${config.deviceId ?? 'default'}');
  stdout.writeln('Frame budget: ${config.frameBudgetMs.toStringAsFixed(2)} ms');
  stdout.writeln('Repeats per scenario: ${config.repeats}');
  stdout.writeln('Warmup runs descartados: ${config.warmupRuns}');
  stdout.writeln(
    'Run order: ${config.interleavedRuns ? 'interleaved by cycle' : 'grouped by scenario'}',
  );
  stdout.writeln(
    'Outlier filter: ${config.discardOutliers ? 'enabled (IQR x${config.outlierIqrK.toStringAsFixed(2)})' : 'disabled'}',
  );
  stdout.writeln('Baseline summary: ${config.baselineSummaryPath}');
  if (config.coverageReferencePairJsonPath != null) {
    final maxIndexUpper = config.coverageMaxMaxBuiltIndexRatio == null
        ? ''
        : ', max_index_ratio<=${config.coverageMaxMaxBuiltIndexRatio!.toStringAsFixed(2)}';
    final uniqueIndexUpper = config.coverageMaxUniqueBuiltIndicesRatio == null
        ? ''
        : ', unique_idx_ratio<=${config.coverageMaxUniqueBuiltIndicesRatio!.toStringAsFixed(2)}';
    stdout.writeln(
      'Coverage guard: enabled '
      '(reference=${config.coverageReferencePairJsonPath}, '
      'max_index_ratio>=${config.coverageMinMaxBuiltIndexRatio.toStringAsFixed(2)}, '
      'unique_idx_ratio>=${config.coverageMinUniqueBuiltIndicesRatio.toStringAsFixed(2)}'
      '$maxIndexUpper$uniqueIndexUpper)',
    );
  }
  if (config.chipDefines.isNotEmpty || config.cardDefines.isNotEmpty) {
    stdout.writeln(
      'Offstage tuning overrides: '
      'chip=[${_formatDefines(config.chipDefines)}], '
      'card=[${_formatDefines(config.cardDefines)}]',
    );
  }

  final baselineByScenario = _readBaselineMetrics(config.baselineSummaryPath);
  final coverageReferenceByScenario =
      config.coverageReferencePairJsonPath == null
      ? null
      : _readCoverageReferenceMedians(config.coverageReferencePairJsonPath!);

  final batches = await _runAllScenarioBatches(config);

  final reportPath = _writeReport(
    outputPath: config.reportPath,
    baselineSummaryPath: config.baselineSummaryPath,
    deviceId: config.deviceId,
    frameBudgetMs: config.frameBudgetMs,
    repeats: config.repeats,
    warmupRuns: config.warmupRuns,
    discardOutliers: config.discardOutliers,
    outlierIqrK: config.outlierIqrK,
    chipDefines: config.chipDefines,
    cardDefines: config.cardDefines,
    baselineByScenario: baselineByScenario,
    batches: batches,
    coverageReferencePairJsonPath: config.coverageReferencePairJsonPath,
    coverageMinMaxBuiltIndexRatio: config.coverageMinMaxBuiltIndexRatio,
    coverageMinUniqueBuiltIndicesRatio:
        config.coverageMinUniqueBuiltIndicesRatio,
    coverageMaxMaxBuiltIndexRatio: config.coverageMaxMaxBuiltIndexRatio,
    coverageMaxUniqueBuiltIndicesRatio:
        config.coverageMaxUniqueBuiltIndicesRatio,
    coverageReferenceByScenario: coverageReferenceByScenario,
  );

  final jsonReportPath = _writeJsonReport(
    outputPath: config.jsonReportPath,
    baselineSummaryPath: config.baselineSummaryPath,
    deviceId: config.deviceId,
    frameBudgetMs: config.frameBudgetMs,
    repeats: config.repeats,
    warmupRuns: config.warmupRuns,
    discardOutliers: config.discardOutliers,
    outlierIqrK: config.outlierIqrK,
    chipDefines: config.chipDefines,
    cardDefines: config.cardDefines,
    baselineByScenario: baselineByScenario,
    batches: batches,
    coverageReferencePairJsonPath: config.coverageReferencePairJsonPath,
    coverageMinMaxBuiltIndexRatio: config.coverageMinMaxBuiltIndexRatio,
    coverageMinUniqueBuiltIndicesRatio:
        config.coverageMinUniqueBuiltIndicesRatio,
    coverageMaxMaxBuiltIndexRatio: config.coverageMaxMaxBuiltIndexRatio,
    coverageMaxUniqueBuiltIndicesRatio:
        config.coverageMaxUniqueBuiltIndicesRatio,
    coverageReferenceByScenario: coverageReferenceByScenario,
  );

  stdout.writeln('Pair report: $reportPath');
  stdout.writeln('Pair json report: $jsonReportPath');
}

class _Config {
  const _Config({
    required this.deviceId,
    required this.frameBudgetMs,
    required this.repeats,
    required this.warmupRuns,
    required this.interleavedRuns,
    required this.discardOutliers,
    required this.outlierIqrK,
    required this.baselineSummaryPath,
    required this.chipDefines,
    required this.cardDefines,
    required this.reportPath,
    required this.jsonReportPath,
    required this.coverageReferencePairJsonPath,
    required this.coverageMinMaxBuiltIndexRatio,
    required this.coverageMinUniqueBuiltIndicesRatio,
    required this.coverageMaxMaxBuiltIndexRatio,
    required this.coverageMaxUniqueBuiltIndicesRatio,
  });

  final String? deviceId;
  final double frameBudgetMs;
  final int repeats;
  final int warmupRuns;
  final bool interleavedRuns;
  final bool discardOutliers;
  final double outlierIqrK;
  final String baselineSummaryPath;
  final Map<String, String> chipDefines;
  final Map<String, String> cardDefines;
  final String reportPath;
  final String jsonReportPath;
  final String? coverageReferencePairJsonPath;
  final double coverageMinMaxBuiltIndexRatio;
  final double coverageMinUniqueBuiltIndicesRatio;
  final double? coverageMaxMaxBuiltIndexRatio;
  final double? coverageMaxUniqueBuiltIndicesRatio;
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
    required this.defines,
    required this.warmupRunIds,
    required this.runs,
  });

  final String scenario;
  final Map<String, String> defines;
  final List<String> warmupRunIds;
  final List<_ScenarioRunResult> runs;
}

_Config _parseArgs(List<String> args) {
  String? deviceId;
  var frameBudgetMs = 16.67;
  var repeats = 3;
  var warmupRuns = 1;
  var interleavedRuns = false;
  var discardOutliers = true;
  var outlierIqrK = 1.5;
  var baselineSummaryPath = 'benchmarks/results/20260211_232622Z/summary.json';
  var reportPath = 'benchmarks/offstage_v1_pair_report.md';
  var jsonReportPath = 'benchmarks/offstage_v1_pair_report.json';
  String? coverageReferencePairJsonPath;
  var coverageMinMaxBuiltIndexRatio = 0.8;
  var coverageMinUniqueBuiltIndicesRatio = 0.8;
  double? coverageMaxMaxBuiltIndexRatio;
  double? coverageMaxUniqueBuiltIndicesRatio;
  int? chipBatchSize;
  int? chipMeasureBatchSize;
  double? chipLoadThreshold;
  double? chipCacheExtent;
  int? chipVisibleCacheCap;
  var chipSingleMeasureBatch = false;
  var chipAddAutomaticKeepAlives = false;
  var chipAddRepaintBoundaries = false;
  var chipAdaptiveRepaintBoundaries = false;
  var chipIncrementalLoad = false;
  var chipAdaptiveVisibleCache = false;
  int? cardBatchSize;
  int? cardMeasureBatchSize;
  double? cardLoadThreshold;
  double? cardCacheExtent;
  int? cardVisibleCacheCap;
  var cardSingleMeasureBatch = false;
  var cardAddAutomaticKeepAlives = false;
  var cardAddRepaintBoundaries = false;
  var cardAdaptiveRepaintBoundaries = false;
  var cardIncrementalLoad = false;
  var cardAdaptiveVisibleCache = false;

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
    if (arg == '--interleaved-runs') {
      interleavedRuns = true;
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
    if (arg == '--json-report-path' && i + 1 < args.length) {
      jsonReportPath = args[++i];
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
    if (arg == '--coverage-max-max-index-ratio' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed < 1) {
        throw ArgumentError('Invalid --coverage-max-max-index-ratio value.');
      }
      coverageMaxMaxBuiltIndexRatio = parsed;
      continue;
    }
    if (arg == '--coverage-max-unique-index-ratio' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed < 1) {
        throw ArgumentError('Invalid --coverage-max-unique-index-ratio value.');
      }
      coverageMaxUniqueBuiltIndicesRatio = parsed;
      continue;
    }
    if (arg == '--chip-batch-size' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --chip-batch-size value.');
      }
      chipBatchSize = parsed;
      continue;
    }
    if (arg == '--chip-measure-batch-size' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --chip-measure-batch-size value.');
      }
      chipMeasureBatchSize = parsed;
      continue;
    }
    if (arg == '--chip-load-threshold' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed < 0) {
        throw ArgumentError('Invalid --chip-load-threshold value.');
      }
      chipLoadThreshold = parsed;
      continue;
    }
    if (arg == '--chip-cache-extent' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed < 0) {
        throw ArgumentError('Invalid --chip-cache-extent value.');
      }
      chipCacheExtent = parsed;
      continue;
    }
    if (arg == '--chip-visible-cache-cap' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --chip-visible-cache-cap value.');
      }
      chipVisibleCacheCap = parsed;
      continue;
    }
    if (arg == '--chip-single-measure-batch') {
      chipSingleMeasureBatch = true;
      continue;
    }
    if (arg == '--chip-keep-alives') {
      chipAddAutomaticKeepAlives = true;
      continue;
    }
    if (arg == '--chip-repaint-boundaries') {
      chipAddRepaintBoundaries = true;
      continue;
    }
    if (arg == '--chip-adaptive-repaint-boundaries') {
      chipAdaptiveRepaintBoundaries = true;
      continue;
    }
    if (arg == '--chip-incremental-load') {
      chipIncrementalLoad = true;
      continue;
    }
    if (arg == '--chip-adaptive-visible-cache') {
      chipAdaptiveVisibleCache = true;
      continue;
    }
    if (arg == '--card-batch-size' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --card-batch-size value.');
      }
      cardBatchSize = parsed;
      continue;
    }
    if (arg == '--card-measure-batch-size' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --card-measure-batch-size value.');
      }
      cardMeasureBatchSize = parsed;
      continue;
    }
    if (arg == '--card-load-threshold' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed < 0) {
        throw ArgumentError('Invalid --card-load-threshold value.');
      }
      cardLoadThreshold = parsed;
      continue;
    }
    if (arg == '--card-cache-extent' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed < 0) {
        throw ArgumentError('Invalid --card-cache-extent value.');
      }
      cardCacheExtent = parsed;
      continue;
    }
    if (arg == '--card-visible-cache-cap' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --card-visible-cache-cap value.');
      }
      cardVisibleCacheCap = parsed;
      continue;
    }
    if (arg == '--card-single-measure-batch') {
      cardSingleMeasureBatch = true;
      continue;
    }
    if (arg == '--card-keep-alives') {
      cardAddAutomaticKeepAlives = true;
      continue;
    }
    if (arg == '--card-repaint-boundaries') {
      cardAddRepaintBoundaries = true;
      continue;
    }
    if (arg == '--card-adaptive-repaint-boundaries') {
      cardAdaptiveRepaintBoundaries = true;
      continue;
    }
    if (arg == '--card-incremental-load') {
      cardIncrementalLoad = true;
      continue;
    }
    if (arg == '--card-adaptive-visible-cache') {
      cardAdaptiveVisibleCache = true;
      continue;
    }
    throw ArgumentError('Unknown argument: $arg');
  }

  final chipDefines = <String, String>{
    if (chipBatchSize != null) 'OFFSTAGE_CHIP_BATCH_SIZE': '$chipBatchSize',
    if (chipMeasureBatchSize != null)
      'OFFSTAGE_CHIP_MEASURE_BATCH_SIZE': '$chipMeasureBatchSize',
    if (chipLoadThreshold != null)
      'OFFSTAGE_CHIP_LOAD_THRESHOLD': chipLoadThreshold.toStringAsFixed(3),
    if (chipCacheExtent != null)
      'OFFSTAGE_CHIP_CACHE_EXTENT': chipCacheExtent.toStringAsFixed(3),
    if (chipVisibleCacheCap != null)
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '$chipVisibleCacheCap',
    if (chipSingleMeasureBatch) 'OFFSTAGE_SINGLE_MEASURE_BATCH': 'true',
    if (chipAddAutomaticKeepAlives)
      'OFFSTAGE_ADD_AUTOMATIC_KEEP_ALIVES': 'true',
    if (chipAddRepaintBoundaries) 'OFFSTAGE_ADD_REPAINT_BOUNDARIES': 'true',
    if (chipAdaptiveRepaintBoundaries)
      'OFFSTAGE_ADAPTIVE_REPAINT_BOUNDARIES': 'true',
    if (chipIncrementalLoad) 'OFFSTAGE_INCREMENTAL_LOAD': 'true',
    if (chipAdaptiveVisibleCache)
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'true',
  };

  final cardDefines = <String, String>{
    if (cardBatchSize != null) 'OFFSTAGE_CARD_BATCH_SIZE': '$cardBatchSize',
    if (cardMeasureBatchSize != null)
      'OFFSTAGE_CARD_MEASURE_BATCH_SIZE': '$cardMeasureBatchSize',
    if (cardLoadThreshold != null)
      'OFFSTAGE_CARD_LOAD_THRESHOLD': cardLoadThreshold.toStringAsFixed(3),
    if (cardCacheExtent != null)
      'OFFSTAGE_CARD_CACHE_EXTENT': cardCacheExtent.toStringAsFixed(3),
    if (cardVisibleCacheCap != null)
      'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY': '$cardVisibleCacheCap',
    if (cardSingleMeasureBatch) 'OFFSTAGE_SINGLE_MEASURE_BATCH': 'true',
    if (cardAddAutomaticKeepAlives)
      'OFFSTAGE_ADD_AUTOMATIC_KEEP_ALIVES': 'true',
    if (cardAddRepaintBoundaries) 'OFFSTAGE_ADD_REPAINT_BOUNDARIES': 'true',
    if (cardAdaptiveRepaintBoundaries)
      'OFFSTAGE_ADAPTIVE_REPAINT_BOUNDARIES': 'true',
    if (cardIncrementalLoad) 'OFFSTAGE_INCREMENTAL_LOAD': 'true',
    if (cardAdaptiveVisibleCache)
      'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE': 'true',
  };

  return _Config(
    deviceId: deviceId,
    frameBudgetMs: frameBudgetMs,
    repeats: repeats,
    warmupRuns: warmupRuns,
    interleavedRuns: interleavedRuns,
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
    baselineSummaryPath: baselineSummaryPath,
    chipDefines: chipDefines,
    cardDefines: cardDefines,
    reportPath: reportPath,
    jsonReportPath: jsonReportPath,
    coverageReferencePairJsonPath: coverageReferencePairJsonPath,
    coverageMinMaxBuiltIndexRatio: coverageMinMaxBuiltIndexRatio,
    coverageMinUniqueBuiltIndicesRatio: coverageMinUniqueBuiltIndicesRatio,
    coverageMaxMaxBuiltIndexRatio: coverageMaxMaxBuiltIndexRatio,
    coverageMaxUniqueBuiltIndicesRatio: coverageMaxUniqueBuiltIndicesRatio,
  );
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run benchmarks/run_offstage_v1_pair.dart [options]',
  );
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
    '  --interleaved-runs       Alternate scenarios per cycle to reduce drift.',
  );
  stdout.writeln(
    '  --outlier-iqr-k <num>    IQR multiplier for outlier filter (default: 1.5).',
  );
  stdout.writeln(
    '  --no-outlier-filter      Disable outlier filtering in median metrics.',
  );
  stdout.writeln(
    '  --baseline-summary <p>   Baseline file path (run summary.json with "results" or pair JSON with "scenarios[].medians") '
    '(default: benchmarks/results/20260211_232622Z/summary.json).',
  );
  stdout.writeln(
    '  --report-path <p>        Markdown report output path '
    '(default: benchmarks/offstage_v1_pair_report.md).',
  );
  stdout.writeln(
    '  --json-report-path <p>   JSON report output path '
    '(default: benchmarks/offstage_v1_pair_report.json).',
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
  stdout.writeln(
    '  --coverage-max-max-index-ratio <n> Optional max ratio candidate/reference for max_index (>=1, disabled by default).',
  );
  stdout.writeln(
    '  --coverage-max-unique-index-ratio <n> Optional max ratio candidate/reference for uniq_idx (>=1, disabled by default).',
  );
  stdout.writeln('  --chip-batch-size <n>    Override chip batchSize.');
  stdout.writeln(
    '  --chip-measure-batch-size <n> Override chip measureBatchSize.',
  );
  stdout.writeln(
    '  --chip-load-threshold <n> Override chip loadThreshold (pixels).',
  );
  stdout.writeln(
    '  --chip-cache-extent <n>  Override chip cacheExtent (pixels).',
  );
  stdout.writeln(
    '  --chip-visible-cache-cap <n> Visible item widget cache size for chip run.',
  );
  stdout.writeln(
    '  --chip-single-measure-batch Enable single active measure batch for chip run.',
  );
  stdout.writeln(
    '  --chip-keep-alives       Enable addAutomaticKeepAlives for chip run.',
  );
  stdout.writeln(
    '  --chip-repaint-boundaries Enable addRepaintBoundaries for chip run.',
  );
  stdout.writeln(
    '  --chip-adaptive-repaint-boundaries Enable adaptive repaint boundaries for chip run.',
  );
  stdout.writeln(
    '  --chip-incremental-load  Enable OFFSTAGE_INCREMENTAL_LOAD for chip run.',
  );
  stdout.writeln(
    '  --chip-adaptive-visible-cache Enable adaptive visible widget cache for chip run.',
  );
  stdout.writeln('  --card-batch-size <n>    Override card batchSize.');
  stdout.writeln(
    '  --card-measure-batch-size <n> Override card measureBatchSize.',
  );
  stdout.writeln(
    '  --card-load-threshold <n> Override card loadThreshold (pixels).',
  );
  stdout.writeln(
    '  --card-cache-extent <n>  Override card cacheExtent (pixels).',
  );
  stdout.writeln(
    '  --card-visible-cache-cap <n> Visible item widget cache size for card run.',
  );
  stdout.writeln(
    '  --card-single-measure-batch Enable single active measure batch for card run.',
  );
  stdout.writeln(
    '  --card-keep-alives       Enable addAutomaticKeepAlives for card run.',
  );
  stdout.writeln(
    '  --card-repaint-boundaries Enable addRepaintBoundaries for card run.',
  );
  stdout.writeln(
    '  --card-adaptive-repaint-boundaries Enable adaptive repaint boundaries for card run.',
  );
  stdout.writeln(
    '  --card-incremental-load  Enable OFFSTAGE_INCREMENTAL_LOAD for card run.',
  );
  stdout.writeln(
    '  --card-adaptive-visible-cache Enable adaptive visible widget cache for card run.',
  );
  stdout.writeln('  -h, --help               Show this help.');
}

Map<String, Map<String, dynamic>> _readBaselineMetrics(String summaryPath) {
  final file = File(summaryPath);
  if (!file.existsSync()) {
    throw StateError('Baseline summary file not found: $summaryPath');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected baseline summary format: $summaryPath');
  }

  final baselineByScenario = <String, Map<String, dynamic>>{};
  final results = decoded['results'];
  if (results is List) {
    for (final entry in results) {
      if (entry is! Map) continue;
      final asMap = Map<String, dynamic>.from(entry);
      final scenario = asMap['scenario'];
      if (scenario is String) {
        baselineByScenario[scenario] = asMap;
      }
    }
    return baselineByScenario;
  }

  final scenarios = decoded['scenarios'];
  if (scenarios is List) {
    for (final entry in scenarios) {
      if (entry is! Map) continue;
      final asMap = Map<String, dynamic>.from(entry);
      final scenario = asMap['scenario'];
      final medians = asMap['medians'];
      if (scenario is String && medians is Map) {
        final metrics = Map<String, dynamic>.from(medians);
        metrics['scenario'] = scenario;
        baselineByScenario[scenario] = metrics;
      }
    }
    return baselineByScenario;
  }

  throw StateError(
    'Baseline summary missing "results" or "scenarios": $summaryPath',
  );
}

class _CoverageReferenceMedians {
  const _CoverageReferenceMedians({
    required this.maxBuiltIndex,
    required this.uniqueBuiltIndices,
  });

  final double maxBuiltIndex;
  final double uniqueBuiltIndices;
}

Map<String, _CoverageReferenceMedians> _readCoverageReferenceMedians(
  String pairJsonPath,
) {
  final file = File(pairJsonPath);
  if (!file.existsSync()) {
    throw StateError('Coverage reference pair JSON not found: $pairJsonPath');
  }

  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected coverage reference format: $pairJsonPath');
  }

  final scenarios = decoded['scenarios'];
  if (scenarios is! List) {
    throw StateError(
      'Coverage reference JSON missing "scenarios": $pairJsonPath',
    );
  }

  final map = <String, _CoverageReferenceMedians>{};
  for (final entry in scenarios) {
    if (entry is! Map) continue;
    final scenarioMap = Map<String, dynamic>.from(entry);
    final scenario = scenarioMap['scenario'];
    final medians = scenarioMap['medians'];
    if (scenario is! String || medians is! Map) continue;
    final mediansMap = Map<String, dynamic>.from(medians);
    map[scenario] = _CoverageReferenceMedians(
      maxBuiltIndex: _asDouble(mediansMap['max_built_index']),
      uniqueBuiltIndices: _asDouble(mediansMap['unique_built_indices']),
    );
  }
  return map;
}

Future<List<_ScenarioBatchResult>> _runAllScenarioBatches(
  _Config config,
) async {
  if (!config.interleavedRuns) {
    final batches = <_ScenarioBatchResult>[];
    for (final scenario in _variants) {
      stdout.writeln('\n# Scenario: $scenario');
      final batch = await _runScenarioBatch(
        scenario: scenario,
        defines: _scenarioDefines(config, scenario),
        repeats: config.repeats,
        warmupRuns: config.warmupRuns,
        deviceId: config.deviceId,
        frameBudgetMs: config.frameBudgetMs,
      );
      batches.add(batch);
    }
    return batches;
  }

  final warmupRunIdsByScenario = <String, List<String>>{
    for (final scenario in _variants) scenario: <String>[],
  };
  final runsByScenario = <String, List<_ScenarioRunResult>>{
    for (final scenario in _variants) scenario: <_ScenarioRunResult>[],
  };

  for (final scenario in _variants) {
    stdout.writeln('\n# Scenario: $scenario');
  }

  for (var i = 1; i <= config.warmupRuns; i++) {
    final scenarioOrder = i.isOdd
        ? _variants
        : _variants.reversed.toList(growable: false);
    stdout.writeln('\n## Interleaved warmup cycle $i/${config.warmupRuns}');
    for (final scenario in scenarioOrder) {
      stdout.writeln(
        '\n## $scenario warmup $i/${config.warmupRuns} (discarded)',
      );
      final warmup = await _runScenarioOnce(
        scenario: scenario,
        defines: _scenarioDefines(config, scenario),
        deviceId: config.deviceId,
        frameBudgetMs: config.frameBudgetMs,
      );
      warmupRunIdsByScenario[scenario]!.add(warmup.runId);
    }
  }

  for (var i = 1; i <= config.repeats; i++) {
    final scenarioOrder = i.isOdd
        ? _variants
        : _variants.reversed.toList(growable: false);
    stdout.writeln('\n## Interleaved run cycle $i/${config.repeats}');
    for (final scenario in scenarioOrder) {
      stdout.writeln('\n## $scenario run $i/${config.repeats} (interleaved)');
      final run = await _runScenarioOnce(
        scenario: scenario,
        defines: _scenarioDefines(config, scenario),
        deviceId: config.deviceId,
        frameBudgetMs: config.frameBudgetMs,
      );
      runsByScenario[scenario]!.add(run);
    }
  }

  return _variants
      .map(
        (scenario) => _ScenarioBatchResult(
          scenario: scenario,
          defines: _scenarioDefines(config, scenario),
          warmupRunIds: warmupRunIdsByScenario[scenario]!,
          runs: runsByScenario[scenario]!,
        ),
      )
      .toList(growable: false);
}

Map<String, String> _scenarioDefines(_Config config, String scenario) {
  switch (scenario) {
    case 'dynamic_chip_10k':
      return config.chipDefines;
    case 'dynamic_card_50k':
      return config.cardDefines;
    default:
      return const <String, String>{};
  }
}

Future<_ScenarioBatchResult> _runScenarioBatch({
  required String scenario,
  required Map<String, String> defines,
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
      defines: defines,
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
        defines: defines,
        deviceId: deviceId,
        frameBudgetMs: frameBudgetMs,
      ),
    );
  }

  return _ScenarioBatchResult(
    scenario: scenario,
    defines: defines,
    warmupRunIds: warmupRunIds,
    runs: runs,
  );
}

Future<_ScenarioRunResult> _runScenarioOnce({
  required String scenario,
  required Map<String, String> defines,
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
    ..._defineArgs(defines),
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
  required String baselineSummaryPath,
  required String? deviceId,
  required double frameBudgetMs,
  required int repeats,
  required int warmupRuns,
  required bool discardOutliers,
  required double outlierIqrK,
  required Map<String, String> chipDefines,
  required Map<String, String> cardDefines,
  required Map<String, Map<String, dynamic>> baselineByScenario,
  required List<_ScenarioBatchResult> batches,
  required String? coverageReferencePairJsonPath,
  required double coverageMinMaxBuiltIndexRatio,
  required double coverageMinUniqueBuiltIndicesRatio,
  required double? coverageMaxMaxBuiltIndexRatio,
  required double? coverageMaxUniqueBuiltIndicesRatio,
  required Map<String, _CoverageReferenceMedians>? coverageReferenceByScenario,
}) {
  final summaries = batches
      .map(
        (batch) => _summarizeScenario(
          batch: batch,
          baselineByScenario: baselineByScenario,
          discardOutliers: discardOutliers,
          outlierIqrK: outlierIqrK,
        ),
      )
      .toList();
  final coverageGuardByScenario = _evaluateCoverageGuardByScenario(
    summaries: summaries,
    coverageReferenceByScenario: coverageReferenceByScenario,
    coverageMinMaxBuiltIndexRatio: coverageMinMaxBuiltIndexRatio,
    coverageMinUniqueBuiltIndicesRatio: coverageMinUniqueBuiltIndicesRatio,
    coverageMaxMaxBuiltIndexRatio: coverageMaxMaxBuiltIndexRatio,
    coverageMaxUniqueBuiltIndicesRatio: coverageMaxUniqueBuiltIndicesRatio,
  );

  final report = StringBuffer()
    ..writeln('# OffstageV1 Pair Benchmark (chip + card)')
    ..writeln()
    ..writeln('- Fecha UTC: `${DateTime.now().toUtc().toIso8601String()}`')
    ..writeln('- Device: `${deviceId ?? 'default'}`')
    ..writeln('- Frame budget: `${frameBudgetMs.toStringAsFixed(2)} ms`')
    ..writeln('- Repeticiones por escenario: `$repeats`')
    ..writeln('- Warmups descartados por escenario: `$warmupRuns`')
    ..writeln(
      '- Outlier filter: `${discardOutliers ? 'enabled (IQR x${outlierIqrK.toStringAsFixed(2)})' : 'disabled'}`',
    )
    ..writeln('- Chip tuning defines: `${_formatDefines(chipDefines)}`')
    ..writeln('- Card tuning defines: `${_formatDefines(cardDefines)}`')
    ..writeln()
    ..writeln('## Resultados por escenario')
    ..writeln();

  for (final summary in summaries) {
    final batch = summary.batch;

    report
      ..writeln('### `${batch.scenario}`')
      ..writeln()
      ..writeln(
        '| run_id | p95_build | p95_raster | jank% | peak_mb | tti_ms | build_calls | visible_calls | offstage_calls | uniq_idx | uniq_visible | uniq_offstage | builds_per_idx | visible_per_idx | offstage_per_idx | max_index | max_visible | max_offstage |',
      )
      ..writeln(
        '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|',
      );

    for (final run in batch.runs) {
      report.writeln(
        '| `${run.runId}` | '
        '${_fmt(run.metrics['p95_build_ms'])} | '
        '${_fmt(run.metrics['p95_raster_ms'])} | '
        '${_fmt(run.metrics['jank_percent'])} | '
        '${_fmt(run.metrics['peak_memory_mb'])} | '
        '${_fmt(run.metrics['time_to_first_interaction_ms'])} | '
        '${_fmt(run.metrics['item_build_calls'])} | '
        '${_fmt(run.metrics['visible_item_build_calls'])} | '
        '${_fmt(run.metrics['offstage_item_build_calls'])} | '
        '${_fmt(run.metrics['unique_built_indices'])} | '
        '${_fmt(run.metrics['unique_visible_built_indices'])} | '
        '${_fmt(run.metrics['unique_offstage_built_indices'])} | '
        '${_fmt(run.metrics['builds_per_unique_index'])} | '
        '${_fmt(run.metrics['visible_builds_per_unique_index'])} | '
        '${_fmt(run.metrics['offstage_builds_per_unique_index'])} | '
        '${_fmt(run.metrics['max_built_index'])} | '
        '${_fmt(run.metrics['max_visible_built_index'])} | '
        '${_fmt(run.metrics['max_offstage_built_index'])} |',
      );
    }

    report
      ..writeln()
      ..writeln('Defines aplicados: `${_formatDefines(batch.defines)}`')
      ..writeln()
      ..writeln(
        'Warmup run_ids descartados: '
        '${batch.warmupRunIds.isEmpty ? 'ninguno' : batch.warmupRunIds.map((id) => '`$id`').join(', ')}',
      )
      ..writeln()
      ..writeln('Medianas:')
      ..writeln()
      ..writeln(
        '| build | raster | jank | memoria | tti | build_calls | visible_calls | offstage_calls | uniq_idx | uniq_visible | uniq_offstage | builds_per_idx | visible_per_idx | offstage_per_idx | max_index | max_visible | max_offstage |',
      )
      ..writeln(
        '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|',
      )
      ..writeln(
        '| ${_fmt(summary.buildStats.median)}'
        ' | ${_fmt(summary.rasterStats.median)}'
        ' | ${_fmt(summary.jankStats.median)}'
        ' | ${_fmt(summary.memoryStats.median)}'
        ' | ${_fmt(summary.ttiStats.median)}'
        ' | ${_fmt(summary.itemBuildCallsStats.median)}'
        ' | ${_fmt(summary.visibleItemBuildCallsStats.median)}'
        ' | ${_fmt(summary.offstageItemBuildCallsStats.median)}'
        ' | ${_fmt(summary.uniqueBuiltIndicesStats.median)}'
        ' | ${_fmt(summary.uniqueVisibleBuiltIndicesStats.median)}'
        ' | ${_fmt(summary.uniqueOffstageBuiltIndicesStats.median)}'
        ' | ${_fmt(summary.buildsPerUniqueIndexStats.median)}'
        ' | ${_fmt(summary.visibleBuildsPerUniqueIndexStats.median)}'
        ' | ${_fmt(summary.offstageBuildsPerUniqueIndexStats.median)}'
        ' | ${_fmt(summary.maxBuiltIndexStats.median)}'
        ' | ${_fmt(summary.maxVisibleBuiltIndexStats.median)}'
        ' | ${_fmt(summary.maxOffstageBuiltIndexStats.median)} |',
      )
      ..writeln()
      ..writeln(
        'Muestras usadas (build/raster/jank/memoria/tti/build_calls/visible_calls/offstage_calls/uniq_idx/uniq_visible/uniq_offstage/builds_per_idx/visible_per_idx/offstage_per_idx/max_index/max_visible/max_offstage): '
        '${summary.buildStats.usedCount}/${batch.runs.length}, '
        '${summary.rasterStats.usedCount}/${batch.runs.length}, '
        '${summary.jankStats.usedCount}/${batch.runs.length}, '
        '${summary.memoryStats.usedCount}/${batch.runs.length}, '
        '${summary.ttiStats.usedCount}/${batch.runs.length}, '
        '${summary.itemBuildCallsStats.usedCount}/${batch.runs.length}, '
        '${summary.visibleItemBuildCallsStats.usedCount}/${batch.runs.length}, '
        '${summary.offstageItemBuildCallsStats.usedCount}/${batch.runs.length}, '
        '${summary.uniqueBuiltIndicesStats.usedCount}/${batch.runs.length}, '
        '${summary.uniqueVisibleBuiltIndicesStats.usedCount}/${batch.runs.length}, '
        '${summary.uniqueOffstageBuiltIndicesStats.usedCount}/${batch.runs.length}, '
        '${summary.buildsPerUniqueIndexStats.usedCount}/${batch.runs.length}, '
        '${summary.visibleBuildsPerUniqueIndexStats.usedCount}/${batch.runs.length}, '
        '${summary.offstageBuildsPerUniqueIndexStats.usedCount}/${batch.runs.length}, '
        '${summary.maxBuiltIndexStats.usedCount}/${batch.runs.length}, '
        '${summary.maxVisibleBuiltIndexStats.usedCount}/${batch.runs.length}, '
        '${summary.maxOffstageBuiltIndexStats.usedCount}/${batch.runs.length}.',
      )
      ..writeln();

    final coverageGuard = coverageGuardByScenario[batch.scenario];
    if (coverageGuard != null && !coverageGuard.comparisonValid) {
      report
        ..writeln(
          'Coverage guard: **invalid comparison** '
          '(`status=${coverageGuard.status}`); '
          'usar KPIs con cautela para este escenario.',
        )
        ..writeln();
    }
  }

  if (coverageReferencePairJsonPath != null) {
    report
      ..writeln('## Coverage Guard (vs referencia)')
      ..writeln()
      ..writeln('- Referencia: `$coverageReferencePairJsonPath`')
      ..writeln(
        '- Umbral `max_built_index` ratio: `${coverageMinMaxBuiltIndexRatio.toStringAsFixed(2)}`',
      )
      ..writeln(
        '- Umbral `unique_built_indices` ratio: `${coverageMinUniqueBuiltIndicesRatio.toStringAsFixed(2)}`',
      )
      ..writeln(
        '- Umbral superior `max_built_index` ratio: '
        '${coverageMaxMaxBuiltIndexRatio == null ? 'disabled' : coverageMaxMaxBuiltIndexRatio.toStringAsFixed(2)}',
      )
      ..writeln(
        '- Umbral superior `unique_built_indices` ratio: '
        '${coverageMaxUniqueBuiltIndicesRatio == null ? 'disabled' : coverageMaxUniqueBuiltIndicesRatio.toStringAsFixed(2)}',
      )
      ..writeln()
      ..writeln(
        '| Escenario | cand_max | ref_max | ratio_max | cand_uniq | ref_uniq | ratio_uniq | estado |',
      )
      ..writeln('|---|---:|---:|---:|---:|---:|---:|---|');

    for (final summary in summaries) {
      final guard = coverageGuardByScenario[summary.batch.scenario]!;
      report.writeln(
        '| `${summary.batch.scenario}` | '
        '${_fmt(guard.candidateMaxBuiltIndex)} | '
        '${_fmt(guard.referenceMaxBuiltIndex)} | '
        '${_fmt(guard.maxBuiltIndexRatio)} | '
        '${_fmt(guard.candidateUniqueBuiltIndices)} | '
        '${_fmt(guard.referenceUniqueBuiltIndices)} | '
        '${_fmt(guard.uniqueBuiltIndicesRatio)} | '
        '${guard.status} |',
      );
    }
    report.writeln();
  }

  report
    ..writeln(
      '## Variacion vs baseline (`$baselineSummaryPath`) (lower-is-better)',
    )
    ..writeln()
    ..writeln('| Escenario | build | raster | jank | memoria | tti |')
    ..writeln('|---|---:|---:|---:|---:|---:|');

  var hasCoverageInvalidation = false;
  for (final summary in summaries) {
    final coverageGuard = coverageGuardByScenario[summary.batch.scenario];
    if (coverageGuard != null && !coverageGuard.comparisonValid) {
      hasCoverageInvalidation = true;
      report.writeln(
        '| `${summary.batch.scenario}` | n/a* | n/a* | n/a* | n/a* | n/a* |',
      );
      continue;
    }
    final improvement = summary.improvementVsBaseline;
    if (improvement == null) {
      report.writeln(
        '| `${summary.batch.scenario}` | n/a | n/a | n/a | n/a | n/a |',
      );
      continue;
    }

    report.writeln(
      '| `${summary.batch.scenario}` | '
      '${_fmtPct(improvement['p95_build_ms'] ?? 0)} | '
      '${_fmtPct(improvement['p95_raster_ms'] ?? 0)} | '
      '${_fmtPct(improvement['jank_percent'] ?? 0)} | '
      '${_fmtPct(improvement['peak_memory_mb'] ?? 0)} | '
      '${_fmtPct(improvement['time_to_first_interaction_ms'] ?? 0)} |',
    );
  }
  if (hasCoverageInvalidation) {
    report
      ..writeln()
      ..writeln(
        '`n/a*`: comparacion invalidada por coverage guard '
        '(caida de cobertura relativa vs referencia).',
      );
  }

  File(outputPath).writeAsStringSync(report.toString());
  return outputPath;
}

String _writeJsonReport({
  required String outputPath,
  required String baselineSummaryPath,
  required String? deviceId,
  required double frameBudgetMs,
  required int repeats,
  required int warmupRuns,
  required bool discardOutliers,
  required double outlierIqrK,
  required Map<String, String> chipDefines,
  required Map<String, String> cardDefines,
  required Map<String, Map<String, dynamic>> baselineByScenario,
  required List<_ScenarioBatchResult> batches,
  required String? coverageReferencePairJsonPath,
  required double coverageMinMaxBuiltIndexRatio,
  required double coverageMinUniqueBuiltIndicesRatio,
  required double? coverageMaxMaxBuiltIndexRatio,
  required double? coverageMaxUniqueBuiltIndicesRatio,
  required Map<String, _CoverageReferenceMedians>? coverageReferenceByScenario,
}) {
  final summaries = batches
      .map(
        (batch) => _summarizeScenario(
          batch: batch,
          baselineByScenario: baselineByScenario,
          discardOutliers: discardOutliers,
          outlierIqrK: outlierIqrK,
        ),
      )
      .toList();
  final coverageGuardByScenario = _evaluateCoverageGuardByScenario(
    summaries: summaries,
    coverageReferenceByScenario: coverageReferenceByScenario,
    coverageMinMaxBuiltIndexRatio: coverageMinMaxBuiltIndexRatio,
    coverageMinUniqueBuiltIndicesRatio: coverageMinUniqueBuiltIndicesRatio,
    coverageMaxMaxBuiltIndexRatio: coverageMaxMaxBuiltIndexRatio,
    coverageMaxUniqueBuiltIndicesRatio: coverageMaxUniqueBuiltIndicesRatio,
  );

  final data = <String, Object?>{
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'device_id': deviceId,
    'frame_budget_ms': frameBudgetMs,
    'repeats': repeats,
    'warmup_runs': warmupRuns,
    'baseline_summary_path': baselineSummaryPath,
    'outlier_filter': <String, Object>{
      'enabled': discardOutliers,
      'iqr_k': outlierIqrK,
    },
    'chip_defines': chipDefines,
    'card_defines': cardDefines,
    'coverage_guard': <String, Object?>{
      'enabled': coverageReferencePairJsonPath != null,
      'reference_pair_json_path': coverageReferencePairJsonPath,
      'min_max_built_index_ratio': coverageMinMaxBuiltIndexRatio,
      'min_unique_built_indices_ratio': coverageMinUniqueBuiltIndicesRatio,
      'max_max_built_index_ratio': coverageMaxMaxBuiltIndexRatio,
      'max_unique_built_indices_ratio': coverageMaxUniqueBuiltIndicesRatio,
      'scenarios': summaries
          .map(
            (summary) =>
                coverageGuardByScenario[summary.batch.scenario]?.toJson(),
          )
          .toList(),
    },
    'scenarios': summaries
        .map(
          (summary) => summary.toJson(
            coverageGuard: coverageGuardByScenario[summary.batch.scenario],
          ),
        )
        .toList(),
  };

  File(outputPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(data),
  );
  return outputPath;
}

class _CoverageGuardScenario {
  const _CoverageGuardScenario({
    required this.scenario,
    required this.enabled,
    required this.referenceAvailable,
    required this.minMaxBuiltIndexRatio,
    required this.minUniqueBuiltIndicesRatio,
    required this.maxMaxBuiltIndexRatio,
    required this.maxUniqueBuiltIndicesRatio,
    required this.candidateMaxBuiltIndex,
    required this.referenceMaxBuiltIndex,
    required this.maxBuiltIndexRatio,
    required this.candidateUniqueBuiltIndices,
    required this.referenceUniqueBuiltIndices,
    required this.uniqueBuiltIndicesRatio,
    required this.passed,
  });

  final String scenario;
  final bool enabled;
  final bool referenceAvailable;
  final double minMaxBuiltIndexRatio;
  final double minUniqueBuiltIndicesRatio;
  final double? maxMaxBuiltIndexRatio;
  final double? maxUniqueBuiltIndicesRatio;
  final double candidateMaxBuiltIndex;
  final double referenceMaxBuiltIndex;
  final double maxBuiltIndexRatio;
  final double candidateUniqueBuiltIndices;
  final double referenceUniqueBuiltIndices;
  final double uniqueBuiltIndicesRatio;
  final bool passed;

  bool get comparisonValid => !enabled || (referenceAvailable && passed);

  String get status {
    if (!enabled) return 'disabled';
    if (!referenceAvailable) return 'missing_reference';
    if (maxBuiltIndexRatio < minMaxBuiltIndexRatio) {
      return 'fail_below_min_max_index';
    }
    if (uniqueBuiltIndicesRatio < minUniqueBuiltIndicesRatio) {
      return 'fail_below_min_unique_index';
    }
    if (maxMaxBuiltIndexRatio != null &&
        maxBuiltIndexRatio > maxMaxBuiltIndexRatio!) {
      return 'fail_above_max_max_index';
    }
    if (maxUniqueBuiltIndicesRatio != null &&
        uniqueBuiltIndicesRatio > maxUniqueBuiltIndicesRatio!) {
      return 'fail_above_max_unique_index';
    }
    return passed ? 'pass' : 'fail';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'scenario': scenario,
      'enabled': enabled,
      'reference_available': referenceAvailable,
      'min_max_built_index_ratio': minMaxBuiltIndexRatio,
      'min_unique_built_indices_ratio': minUniqueBuiltIndicesRatio,
      'max_max_built_index_ratio': maxMaxBuiltIndexRatio,
      'max_unique_built_indices_ratio': maxUniqueBuiltIndicesRatio,
      'candidate_median_max_built_index': candidateMaxBuiltIndex,
      'reference_median_max_built_index': referenceMaxBuiltIndex,
      'observed_max_built_index_ratio': maxBuiltIndexRatio,
      'candidate_median_unique_built_indices': candidateUniqueBuiltIndices,
      'reference_median_unique_built_indices': referenceUniqueBuiltIndices,
      'observed_unique_built_indices_ratio': uniqueBuiltIndicesRatio,
      'passed': passed,
      'comparison_valid': comparisonValid,
      'status': status,
    };
  }
}

Map<String, _CoverageGuardScenario> _evaluateCoverageGuardByScenario({
  required List<_ScenarioSummary> summaries,
  required Map<String, _CoverageReferenceMedians>? coverageReferenceByScenario,
  required double coverageMinMaxBuiltIndexRatio,
  required double coverageMinUniqueBuiltIndicesRatio,
  required double? coverageMaxMaxBuiltIndexRatio,
  required double? coverageMaxUniqueBuiltIndicesRatio,
}) {
  final enabled = coverageReferenceByScenario != null;
  final byScenario = <String, _CoverageGuardScenario>{};

  for (final summary in summaries) {
    final scenario = summary.batch.scenario;
    final candidateMax = summary.maxBuiltIndexStats.median;
    final candidateUnique = summary.uniqueBuiltIndicesStats.median;
    final reference = coverageReferenceByScenario?[scenario];
    final referenceAvailable = reference != null;
    final referenceMax = reference?.maxBuiltIndex ?? 0;
    final referenceUnique = reference?.uniqueBuiltIndices ?? 0;
    final ratioMax = _safeCoverageRatio(candidateMax, referenceMax);
    final ratioUnique = _safeCoverageRatio(candidateUnique, referenceUnique);
    final passMaxUpper =
        coverageMaxMaxBuiltIndexRatio == null ||
        ratioMax <= coverageMaxMaxBuiltIndexRatio;
    final passUniqueUpper =
        coverageMaxUniqueBuiltIndicesRatio == null ||
        ratioUnique <= coverageMaxUniqueBuiltIndicesRatio;
    final passed =
        !enabled ||
        (referenceAvailable &&
            ratioMax >= coverageMinMaxBuiltIndexRatio &&
            ratioUnique >= coverageMinUniqueBuiltIndicesRatio &&
            passMaxUpper &&
            passUniqueUpper);

    byScenario[scenario] = _CoverageGuardScenario(
      scenario: scenario,
      enabled: enabled,
      referenceAvailable: referenceAvailable,
      minMaxBuiltIndexRatio: coverageMinMaxBuiltIndexRatio,
      minUniqueBuiltIndicesRatio: coverageMinUniqueBuiltIndicesRatio,
      maxMaxBuiltIndexRatio: coverageMaxMaxBuiltIndexRatio,
      maxUniqueBuiltIndicesRatio: coverageMaxUniqueBuiltIndicesRatio,
      candidateMaxBuiltIndex: candidateMax,
      referenceMaxBuiltIndex: referenceMax,
      maxBuiltIndexRatio: ratioMax,
      candidateUniqueBuiltIndices: candidateUnique,
      referenceUniqueBuiltIndices: referenceUnique,
      uniqueBuiltIndicesRatio: ratioUnique,
      passed: passed,
    );
  }
  return byScenario;
}

double _safeCoverageRatio(double candidate, double reference) {
  if (reference <= 0) return 1;
  return candidate / reference;
}

class _ScenarioSummary {
  const _ScenarioSummary({
    required this.batch,
    required this.buildStats,
    required this.rasterStats,
    required this.jankStats,
    required this.memoryStats,
    required this.ttiStats,
    required this.itemBuildCallsStats,
    required this.visibleItemBuildCallsStats,
    required this.offstageItemBuildCallsStats,
    required this.uniqueBuiltIndicesStats,
    required this.uniqueVisibleBuiltIndicesStats,
    required this.uniqueOffstageBuiltIndicesStats,
    required this.buildsPerUniqueIndexStats,
    required this.visibleBuildsPerUniqueIndexStats,
    required this.offstageBuildsPerUniqueIndexStats,
    required this.maxBuiltIndexStats,
    required this.maxVisibleBuiltIndexStats,
    required this.maxOffstageBuiltIndexStats,
    required this.improvementVsBaseline,
  });

  final _ScenarioBatchResult batch;
  final _MetricStats buildStats;
  final _MetricStats rasterStats;
  final _MetricStats jankStats;
  final _MetricStats memoryStats;
  final _MetricStats ttiStats;
  final _MetricStats itemBuildCallsStats;
  final _MetricStats visibleItemBuildCallsStats;
  final _MetricStats offstageItemBuildCallsStats;
  final _MetricStats uniqueBuiltIndicesStats;
  final _MetricStats uniqueVisibleBuiltIndicesStats;
  final _MetricStats uniqueOffstageBuiltIndicesStats;
  final _MetricStats buildsPerUniqueIndexStats;
  final _MetricStats visibleBuildsPerUniqueIndexStats;
  final _MetricStats offstageBuildsPerUniqueIndexStats;
  final _MetricStats maxBuiltIndexStats;
  final _MetricStats maxVisibleBuiltIndexStats;
  final _MetricStats maxOffstageBuiltIndexStats;
  final Map<String, double>? improvementVsBaseline;

  Map<String, Object?> toJson({_CoverageGuardScenario? coverageGuard}) {
    final comparisonValid = coverageGuard?.comparisonValid ?? true;
    return <String, Object?>{
      'scenario': batch.scenario,
      'defines': batch.defines,
      'comparison_valid': comparisonValid,
      'coverage_guard': coverageGuard?.toJson(),
      'warmup_run_ids': batch.warmupRunIds,
      'runs': batch.runs
          .map(
            (run) => <String, Object?>{
              'run_id': run.runId,
              'summary_path': run.summaryPath,
              'metrics': run.metrics,
            },
          )
          .toList(),
      'medians': <String, double>{
        'p95_build_ms': buildStats.median,
        'p95_raster_ms': rasterStats.median,
        'jank_percent': jankStats.median,
        'peak_memory_mb': memoryStats.median,
        'time_to_first_interaction_ms': ttiStats.median,
        'item_build_calls': itemBuildCallsStats.median,
        'visible_item_build_calls': visibleItemBuildCallsStats.median,
        'offstage_item_build_calls': offstageItemBuildCallsStats.median,
        'unique_built_indices': uniqueBuiltIndicesStats.median,
        'unique_visible_built_indices': uniqueVisibleBuiltIndicesStats.median,
        'unique_offstage_built_indices': uniqueOffstageBuiltIndicesStats.median,
        'builds_per_unique_index': buildsPerUniqueIndexStats.median,
        'visible_builds_per_unique_index':
            visibleBuildsPerUniqueIndexStats.median,
        'offstage_builds_per_unique_index':
            offstageBuildsPerUniqueIndexStats.median,
        'max_built_index': maxBuiltIndexStats.median,
        'max_visible_built_index': maxVisibleBuiltIndexStats.median,
        'max_offstage_built_index': maxOffstageBuiltIndexStats.median,
      },
      'samples_used': <String, int>{
        'p95_build_ms': buildStats.usedCount,
        'p95_raster_ms': rasterStats.usedCount,
        'jank_percent': jankStats.usedCount,
        'peak_memory_mb': memoryStats.usedCount,
        'time_to_first_interaction_ms': ttiStats.usedCount,
        'item_build_calls': itemBuildCallsStats.usedCount,
        'visible_item_build_calls': visibleItemBuildCallsStats.usedCount,
        'offstage_item_build_calls': offstageItemBuildCallsStats.usedCount,
        'unique_built_indices': uniqueBuiltIndicesStats.usedCount,
        'unique_visible_built_indices':
            uniqueVisibleBuiltIndicesStats.usedCount,
        'unique_offstage_built_indices':
            uniqueOffstageBuiltIndicesStats.usedCount,
        'builds_per_unique_index': buildsPerUniqueIndexStats.usedCount,
        'visible_builds_per_unique_index':
            visibleBuildsPerUniqueIndexStats.usedCount,
        'offstage_builds_per_unique_index':
            offstageBuildsPerUniqueIndexStats.usedCount,
        'max_built_index': maxBuiltIndexStats.usedCount,
        'max_visible_built_index': maxVisibleBuiltIndexStats.usedCount,
        'max_offstage_built_index': maxOffstageBuiltIndexStats.usedCount,
      },
      'improvement_vs_baseline_percent': comparisonValid
          ? improvementVsBaseline
          : null,
      'improvement_vs_baseline_percent_raw': improvementVsBaseline,
    };
  }
}

_ScenarioSummary _summarizeScenario({
  required _ScenarioBatchResult batch,
  required Map<String, Map<String, dynamic>> baselineByScenario,
  required bool discardOutliers,
  required double outlierIqrK,
}) {
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
  final itemBuildCallsStats = _metricStats(
    batch.runs,
    'item_build_calls',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final visibleItemBuildCallsStats = _metricStats(
    batch.runs,
    'visible_item_build_calls',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final offstageItemBuildCallsStats = _metricStats(
    batch.runs,
    'offstage_item_build_calls',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final uniqueBuiltIndicesStats = _metricStats(
    batch.runs,
    'unique_built_indices',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final uniqueVisibleBuiltIndicesStats = _metricStats(
    batch.runs,
    'unique_visible_built_indices',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final uniqueOffstageBuiltIndicesStats = _metricStats(
    batch.runs,
    'unique_offstage_built_indices',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final buildsPerUniqueIndexStats = _metricStats(
    batch.runs,
    'builds_per_unique_index',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final visibleBuildsPerUniqueIndexStats = _metricStats(
    batch.runs,
    'visible_builds_per_unique_index',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final offstageBuildsPerUniqueIndexStats = _metricStats(
    batch.runs,
    'offstage_builds_per_unique_index',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final maxBuiltIndexStats = _metricStats(
    batch.runs,
    'max_built_index',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final maxVisibleBuiltIndexStats = _metricStats(
    batch.runs,
    'max_visible_built_index',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );
  final maxOffstageBuiltIndexStats = _metricStats(
    batch.runs,
    'max_offstage_built_index',
    discardOutliers: discardOutliers,
    outlierIqrK: outlierIqrK,
  );

  final baseline = baselineByScenario[batch.scenario];
  Map<String, double>? improvement;
  if (baseline != null) {
    improvement = <String, double>{
      'p95_build_ms': _improvement(
        _asDouble(baseline['p95_build_ms']),
        buildStats.median,
      ),
      'p95_raster_ms': _improvement(
        _asDouble(baseline['p95_raster_ms']),
        rasterStats.median,
      ),
      'jank_percent': _improvement(
        _asDouble(baseline['jank_percent']),
        jankStats.median,
      ),
      'peak_memory_mb': _improvement(
        _asDouble(baseline['peak_memory_mb']),
        memoryStats.median,
      ),
      'time_to_first_interaction_ms': _improvement(
        _asDouble(baseline['time_to_first_interaction_ms']),
        ttiStats.median,
      ),
    };
  }

  return _ScenarioSummary(
    batch: batch,
    buildStats: buildStats,
    rasterStats: rasterStats,
    jankStats: jankStats,
    memoryStats: memoryStats,
    ttiStats: ttiStats,
    itemBuildCallsStats: itemBuildCallsStats,
    visibleItemBuildCallsStats: visibleItemBuildCallsStats,
    offstageItemBuildCallsStats: offstageItemBuildCallsStats,
    uniqueBuiltIndicesStats: uniqueBuiltIndicesStats,
    uniqueVisibleBuiltIndicesStats: uniqueVisibleBuiltIndicesStats,
    uniqueOffstageBuiltIndicesStats: uniqueOffstageBuiltIndicesStats,
    buildsPerUniqueIndexStats: buildsPerUniqueIndexStats,
    visibleBuildsPerUniqueIndexStats: visibleBuildsPerUniqueIndexStats,
    offstageBuildsPerUniqueIndexStats: offstageBuildsPerUniqueIndexStats,
    maxBuiltIndexStats: maxBuiltIndexStats,
    maxVisibleBuiltIndexStats: maxVisibleBuiltIndexStats,
    maxOffstageBuiltIndexStats: maxOffstageBuiltIndexStats,
    improvementVsBaseline: improvement,
  );
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

List<String> _defineArgs(Map<String, String> defines) {
  if (defines.isEmpty) return const <String>[];
  final entries = defines.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final args = <String>[];
  for (final entry in entries) {
    args.add('--define');
    args.add('${entry.key}=${entry.value}');
  }
  return args;
}

String _formatDefines(Map<String, String> defines) {
  if (defines.isEmpty) return 'default';
  final entries = defines.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((entry) => '${entry.key}=${entry.value}').join(', ');
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _fmt(Object? value) => _asDouble(value).toStringAsFixed(3);

String _fmtPct(double value) => '${value.toStringAsFixed(2)}%';
