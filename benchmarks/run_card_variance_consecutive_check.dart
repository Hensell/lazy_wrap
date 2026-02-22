import 'dart:convert';
import 'dart:io';

const _DecisionMode _defaultMode = _DecisionMode.cv;
const _defaultCvThreshold = 30.0;
const _defaultMadThreshold = 30.0;

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  final runA = _loadRunSnapshot(config.runAJsonPath);
  final runB = _loadRunSnapshot(config.runBJsonPath);

  final evalA = _evaluateRun(runA, config);
  final evalB = _evaluateRun(runB, config);
  final consecutivePass = evalA.modePass && evalB.modePass;

  final jsonReport = <String, Object?>{
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'criterion': 'two_consecutive_runs',
    'mode': config.mode.name,
    'thresholds': <String, Object>{
      'cv_percent': config.cvThreshold,
      'mad_percent_of_median': config.madThreshold,
    },
    'run_a': evalA.toJson(),
    'run_b': evalB.toJson(),
    'consecutive_pass': consecutivePass,
    'decision': consecutivePass ? 'PASS' : 'FAIL',
  };

  _ensureParentDir(config.jsonReportPath);
  File(config.jsonReportPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(jsonReport),
  );

  final markdownReport = _buildMarkdownReport(
    config: config,
    evalA: evalA,
    evalB: evalB,
    consecutivePass: consecutivePass,
  );
  _ensureParentDir(config.markdownReportPath);
  File(config.markdownReportPath).writeAsStringSync(markdownReport);

  stdout.writeln('consecutive_json=${config.jsonReportPath}');
  stdout.writeln('consecutive_md=${config.markdownReportPath}');
  stdout.writeln('decision=${consecutivePass ? 'PASS' : 'FAIL'}');
}

enum _DecisionMode { cv, mad, cvOrMad, cvAndMad }

extension on _DecisionMode {
  String get name {
    switch (this) {
      case _DecisionMode.cv:
        return 'cv';
      case _DecisionMode.mad:
        return 'mad';
      case _DecisionMode.cvOrMad:
        return 'cv_or_mad';
      case _DecisionMode.cvAndMad:
        return 'cv_and_mad';
    }
  }
}

class _Config {
  const _Config({
    required this.runAJsonPath,
    required this.runBJsonPath,
    required this.mode,
    required this.cvThreshold,
    required this.madThreshold,
    required this.jsonReportPath,
    required this.markdownReportPath,
  });

  final String runAJsonPath;
  final String runBJsonPath;
  final _DecisionMode mode;
  final double cvThreshold;
  final double madThreshold;
  final String jsonReportPath;
  final String markdownReportPath;
}

class _RunSnapshot {
  const _RunSnapshot({
    required this.path,
    required this.scenario,
    required this.repeats,
    required this.warmupRuns,
    required this.jankCvPercent,
    required this.jankMadPercentOfMedian,
    required this.primarySuspectRunId,
  });

  final String path;
  final String? scenario;
  final int? repeats;
  final int? warmupRuns;
  final double? jankCvPercent;
  final double? jankMadPercentOfMedian;
  final String? primarySuspectRunId;
}

class _RunEvaluation {
  const _RunEvaluation({
    required this.path,
    required this.scenario,
    required this.repeats,
    required this.warmupRuns,
    required this.jankCvPercent,
    required this.jankMadPercentOfMedian,
    required this.cvPass,
    required this.madPass,
    required this.modePass,
    required this.primarySuspectRunId,
    required this.notes,
  });

  final String path;
  final String? scenario;
  final int? repeats;
  final int? warmupRuns;
  final double? jankCvPercent;
  final double? jankMadPercentOfMedian;
  final bool cvPass;
  final bool madPass;
  final bool modePass;
  final String? primarySuspectRunId;
  final List<String> notes;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'scenario': scenario,
    'repeats': repeats,
    'warmup_runs': warmupRuns,
    'jank_cv_percent': jankCvPercent,
    'jank_mad_percent_of_median': jankMadPercentOfMedian,
    'cv_available': jankCvPercent != null,
    'mad_available': jankMadPercentOfMedian != null,
    'cv_pass': cvPass,
    'mad_pass': madPass,
    'mode_pass': modePass,
    'primary_suspect_run_id': primarySuspectRunId,
    'notes': notes,
  };
}

_Config _parseArgs(List<String> args) {
  String? runAJsonPath;
  String? runBJsonPath;
  var mode = _defaultMode;
  var cvThreshold = _defaultCvThreshold;
  var madThreshold = _defaultMadThreshold;
  String? outputPrefix;
  String? jsonReportPath;
  String? markdownReportPath;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      _printUsage();
      exit(0);
    }
    if (arg == '--run-a-json' && i + 1 < args.length) {
      runAJsonPath = args[++i];
      continue;
    }
    if (arg == '--run-b-json' && i + 1 < args.length) {
      runBJsonPath = args[++i];
      continue;
    }
    if (arg == '--mode' && i + 1 < args.length) {
      mode = _parseMode(args[++i]);
      continue;
    }
    if (arg == '--cv-threshold' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --cv-threshold value.');
      }
      cvThreshold = parsed;
      continue;
    }
    if (arg == '--mad-threshold' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --mad-threshold value.');
      }
      madThreshold = parsed;
      continue;
    }
    if (arg == '--output-prefix' && i + 1 < args.length) {
      outputPrefix = args[++i];
      continue;
    }
    if (arg == '--json-report-path' && i + 1 < args.length) {
      jsonReportPath = args[++i];
      continue;
    }
    if (arg == '--report-path' && i + 1 < args.length) {
      markdownReportPath = args[++i];
      continue;
    }
    throw ArgumentError('Unknown argument: $arg');
  }

  if (runAJsonPath == null || runAJsonPath.isEmpty) {
    throw ArgumentError('Missing required --run-a-json.');
  }
  if (runBJsonPath == null || runBJsonPath.isEmpty) {
    throw ArgumentError('Missing required --run-b-json.');
  }

  final finalPrefix =
      outputPrefix ??
      'benchmarks/results/experiments/'
          '${_dateStamp(DateTime.now().toUtc())}_card_variance_consecutive_${mode.name}';

  return _Config(
    runAJsonPath: runAJsonPath,
    runBJsonPath: runBJsonPath,
    mode: mode,
    cvThreshold: cvThreshold,
    madThreshold: madThreshold,
    jsonReportPath: jsonReportPath ?? '$finalPrefix.json',
    markdownReportPath: markdownReportPath ?? '$finalPrefix.md',
  );
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run benchmarks/run_card_variance_consecutive_check.dart [options]',
  );
  stdout.writeln();
  stdout.writeln('Required:');
  stdout.writeln('  --run-a-json <path>      First variance metrics JSON.');
  stdout.writeln('  --run-b-json <path>      Second variance metrics JSON.');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --mode <name>            Decision mode: cv|mad|cv_or_mad|cv_and_mad (default: cv).',
  );
  stdout.writeln(
    '  --cv-threshold <num>     Threshold for jank CV% (default: 30).',
  );
  stdout.writeln(
    '  --mad-threshold <num>    Threshold for jank MAD%/median (default: 30).',
  );
  stdout.writeln(
    '  --output-prefix <path>   Prefix for output files (default: timestamped).',
  );
  stdout.writeln(
    '  --json-report-path <p>   Output path for JSON report.',
  );
  stdout.writeln(
    '  --report-path <path>     Output path for markdown report.',
  );
  stdout.writeln('  -h, --help               Show this help.');
}

_DecisionMode _parseMode(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'cv') return _DecisionMode.cv;
  if (normalized == 'mad') return _DecisionMode.mad;
  if (normalized == 'cv_or_mad' || normalized == 'cvormad') {
    return _DecisionMode.cvOrMad;
  }
  if (normalized == 'cv_and_mad' || normalized == 'cvandmad') {
    return _DecisionMode.cvAndMad;
  }
  throw ArgumentError(
    'Invalid --mode value. Use cv, mad, cv_or_mad or cv_and_mad.',
  );
}

_RunSnapshot _loadRunSnapshot(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw ArgumentError('Run JSON not found: $path');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Invalid run JSON: $path');
  }

  final scenario = _asString(decoded['scenario']);
  final repeats = _asInt(decoded['repeats']);
  final warmupRuns = _asInt(decoded['warmup_runs']);
  final jankCvPercent = _lookupDouble(
    decoded,
    <Object>['metrics', 'jank_percent', 'cv_percent'],
  );

  final madFromDispersion = _lookupDouble(
    decoded,
    <Object>['robust_jank_dispersion', 'mad_percent_of_median'],
  );
  final madFromGate = _lookupDouble(
    decoded,
    <Object>['robust_variance_gate', 'observed_percent'],
  );
  final jankMadPercentOfMedian = madFromDispersion ?? madFromGate;

  final primarySuspectRunId = _lookupString(
    decoded,
    <Object>['outlier_diagnostics', 'primary_suspect_run_id'],
  );

  return _RunSnapshot(
    path: path,
    scenario: scenario,
    repeats: repeats,
    warmupRuns: warmupRuns,
    jankCvPercent: jankCvPercent,
    jankMadPercentOfMedian: jankMadPercentOfMedian,
    primarySuspectRunId: primarySuspectRunId,
  );
}

_RunEvaluation _evaluateRun(_RunSnapshot run, _Config config) {
  final notes = <String>[];
  final cvAvailable = run.jankCvPercent != null;
  final madAvailable = run.jankMadPercentOfMedian != null;
  final cvPass = cvAvailable && run.jankCvPercent! <= config.cvThreshold;
  final madPass =
      madAvailable && run.jankMadPercentOfMedian! <= config.madThreshold;

  final modePass = switch (config.mode) {
    _DecisionMode.cv => cvPass,
    _DecisionMode.mad => madPass,
    _DecisionMode.cvOrMad => _evaluateCvOrMad(
      cvAvailable: cvAvailable,
      madAvailable: madAvailable,
      cvPass: cvPass,
      madPass: madPass,
      notes: notes,
    ),
    _DecisionMode.cvAndMad => _evaluateCvAndMad(
      cvAvailable: cvAvailable,
      madAvailable: madAvailable,
      cvPass: cvPass,
      madPass: madPass,
      notes: notes,
    ),
  };

  if (!cvAvailable) {
    notes.add('Missing jank CV metric in source JSON.');
  }
  if (!madAvailable) {
    notes.add('Missing robust MAD metric in source JSON.');
  }

  return _RunEvaluation(
    path: run.path,
    scenario: run.scenario,
    repeats: run.repeats,
    warmupRuns: run.warmupRuns,
    jankCvPercent: run.jankCvPercent,
    jankMadPercentOfMedian: run.jankMadPercentOfMedian,
    cvPass: cvPass,
    madPass: madPass,
    modePass: modePass,
    primarySuspectRunId: run.primarySuspectRunId,
    notes: List<String>.unmodifiable(notes),
  );
}

bool _evaluateCvOrMad({
  required bool cvAvailable,
  required bool madAvailable,
  required bool cvPass,
  required bool madPass,
  required List<String> notes,
}) {
  if (cvAvailable && madAvailable) {
    return cvPass || madPass;
  }
  if (cvAvailable) {
    notes.add('Mode cv_or_mad fallback: MAD missing, using CV only.');
    return cvPass;
  }
  if (madAvailable) {
    notes.add('Mode cv_or_mad fallback: CV missing, using MAD only.');
    return madPass;
  }
  return false;
}

bool _evaluateCvAndMad({
  required bool cvAvailable,
  required bool madAvailable,
  required bool cvPass,
  required bool madPass,
  required List<String> notes,
}) {
  if (!cvAvailable || !madAvailable) {
    notes.add('Mode cv_and_mad requires both CV and MAD metrics.');
    return false;
  }
  return cvPass && madPass;
}

String _buildMarkdownReport({
  required _Config config,
  required _RunEvaluation evalA,
  required _RunEvaluation evalB,
  required bool consecutivePass,
}) {
  String fmtMaybe(double? value, {int decimals = 2}) =>
      value == null ? 'n/a' : value.toStringAsFixed(decimals);
  String fmtMaybeInt(int? value) => value == null ? 'n/a' : '$value';
  String fmtSuspect(String? value) => value == null ? '`none`' : '`$value`';
  String notesText(List<String> notes) =>
      notes.isEmpty ? '-' : notes.join(' | ');

  final buffer = StringBuffer()
    ..writeln('# Consecutive Check: card variance')
    ..writeln()
    ..writeln('- mode: `${config.mode.name}`')
    ..writeln('- criterion: `two_consecutive_runs`')
    ..writeln('- cv_threshold: `${config.cvThreshold.toStringAsFixed(2)}%`')
    ..writeln(
      '- mad_threshold: `${config.madThreshold.toStringAsFixed(2)}%`',
    )
    ..writeln('- decision: `${consecutivePass ? 'PASS' : 'FAIL'}`')
    ..writeln()
    ..writeln(
      '| run | scenario | repeats | warmup | jank_cv% | jank_mad%/median | cv_pass | mad_pass | mode_pass | primary_suspect | notes |',
    )
    ..writeln(
      '|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|',
    )
    ..writeln(
      '| run_a | `${evalA.scenario ?? 'unknown'}` | '
      '${fmtMaybeInt(evalA.repeats)} | '
      '${fmtMaybeInt(evalA.warmupRuns)} | '
      '${fmtMaybe(evalA.jankCvPercent)} | '
      '${fmtMaybe(evalA.jankMadPercentOfMedian)} | '
      '${evalA.cvPass} | '
      '${evalA.madPass} | '
      '${evalA.modePass} | '
      '${fmtSuspect(evalA.primarySuspectRunId)} | '
      '${notesText(evalA.notes)} |',
    )
    ..writeln(
      '| run_b | `${evalB.scenario ?? 'unknown'}` | '
      '${fmtMaybeInt(evalB.repeats)} | '
      '${fmtMaybeInt(evalB.warmupRuns)} | '
      '${fmtMaybe(evalB.jankCvPercent)} | '
      '${fmtMaybe(evalB.jankMadPercentOfMedian)} | '
      '${evalB.cvPass} | '
      '${evalB.madPass} | '
      '${evalB.modePass} | '
      '${fmtSuspect(evalB.primarySuspectRunId)} | '
      '${notesText(evalB.notes)} |',
    )
    ..writeln()
    ..writeln('## Sources')
    ..writeln()
    ..writeln('- run_a_json: `${evalA.path}`')
    ..writeln('- run_b_json: `${evalB.path}`');

  return buffer.toString();
}

double? _lookupDouble(Map<String, dynamic> root, List<Object> path) {
  Object? current = root;
  for (final segment in path) {
    if (current is! Map<String, dynamic>) return null;
    current = current['$segment'];
  }
  if (current is num) return current.toDouble();
  if (current is String) return double.tryParse(current);
  return null;
}

String? _lookupString(Map<String, dynamic> root, List<Object> path) {
  Object? current = root;
  for (final segment in path) {
    if (current is! Map<String, dynamic>) return null;
    current = current['$segment'];
  }
  return _asString(current);
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _asString(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

void _ensureParentDir(String path) {
  File(path).absolute.parent.createSync(recursive: true);
}

String _dateStamp(DateTime utc) {
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '$year$month$day';
}
