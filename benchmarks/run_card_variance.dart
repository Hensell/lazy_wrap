import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const _defaultScenario = 'dynamic_card_50k';
const _p0TargetJankCvPercent = 30.0;
const _metricKeys = <String>[
  'p95_build_ms',
  'p95_raster_ms',
  'jank_percent',
  'peak_memory_mb',
  'time_to_first_interaction_ms',
];

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);

  stdout.writeln('Running variance benchmark');
  stdout.writeln('Scenario: ${config.scenario}');
  stdout.writeln('Device: ${config.deviceId ?? 'default'}');
  stdout.writeln('Frame budget: ${config.frameBudgetMs.toStringAsFixed(2)} ms');
  stdout.writeln('Warmup runs: ${config.warmupRuns}');
  stdout.writeln('Measured runs: ${config.repeats}');
  stdout.writeln('Cooldown between runs: ${config.cooldownMs} ms');
  stdout.writeln(
    'Max jank CV gate: ${config.maxJankCvPercent.toStringAsFixed(2)}%',
  );
  stdout.writeln('Enforce jank CV gate: ${config.enforceMaxJankCv}');
  stdout.writeln(
    'Max jank MAD gate: ${config.maxJankMadPercent.toStringAsFixed(2)}%',
  );
  stdout.writeln('Enforce jank MAD gate: ${config.enforceMaxJankMad}');
  if (config.defines.isNotEmpty) {
    stdout.writeln(
      'Extra defines: ${_formatDefines(config.defines)}',
    );
  }

  final warmupRunIds = <String>[];
  final measuredRuns = <_RunMetrics>[];

  final totalRuns = config.warmupRuns + config.repeats;
  for (var i = 0; i < totalRuns; i++) {
    final isWarmup = i < config.warmupRuns;
    final index = isWarmup ? i + 1 : (i - config.warmupRuns) + 1;
    final label = isWarmup
        ? '[warmup $index/${config.warmupRuns}]'
        : '[run $index/${config.repeats}]';
    stdout.writeln('$label ${config.scenario}');

    final runId = await _runSingleScenario(config);
    stdout.writeln(runId);

    if (isWarmup) {
      warmupRunIds.add(runId);
    } else {
      final metrics = _readScenarioMetrics(runId, config.scenario);
      final scrollDiagnostics = _readRunScrollDiagnostics(
        runId,
        config.scenario,
      );
      final frameDiagnostics = _readRunFrameDiagnostics(runId, config.scenario);
      measuredRuns.add(
        _RunMetrics(
          runId: runId,
          metrics: metrics,
          scrollDiagnostics: scrollDiagnostics,
          frameDiagnostics: frameDiagnostics,
        ),
      );
    }

    if (config.cooldownMs > 0 && i < totalRuns - 1) {
      stdout.writeln(
        '[cooldown] waiting ${config.cooldownMs} ms before next run...',
      );
      await Future<void>.delayed(Duration(milliseconds: config.cooldownMs));
    }
  }

  if (measuredRuns.isEmpty) {
    throw StateError('No measured runs collected. Increase --repeats.');
  }

  final runIdsPath = config.runIdsPath;
  final jsonReportPath = config.jsonReportPath;
  final markdownReportPath = config.markdownReportPath;
  _ensureParentDir(runIdsPath);
  _ensureParentDir(jsonReportPath);
  _ensureParentDir(markdownReportPath);

  File(runIdsPath).writeAsStringSync(
    '${measuredRuns.map((run) => run.runId).join('\n')}\n',
  );

  final metricsStats = <String, _MetricStats>{
    for (final key in _metricKeys)
      key: _computeStats(
        measuredRuns.map((run) => run.metrics[key]!).toList(),
      ),
  };
  final varianceGate = _buildVarianceGate(
    jankCvPercent: metricsStats['jank_percent']!.cvPercent,
    maxJankCvPercent: config.maxJankCvPercent,
  );
  final robustJankDispersion = _computeRobustJankDispersion(
    measuredRuns.map((run) => run.metrics['jank_percent']!).toList(),
  );
  final robustVarianceGate = _buildRobustVarianceGate(
    observedJankMadPercent: robustJankDispersion.madPercentOfMedian,
    maxJankMadPercent: config.maxJankMadPercent,
  );
  final outlierDiagnostics = _buildOutlierDiagnostics(measuredRuns);
  final singleRunAnomalyDiagnostics = _computeSingleRunAnomalyDiagnostics(
    runs: measuredRuns,
    outlierDiagnostics: outlierDiagnostics,
    originalJankCvPercent: metricsStats['jank_percent']!.cvPercent,
    maxJankCvPercent: config.maxJankCvPercent,
    targetJankCvPercent: _p0TargetJankCvPercent,
  );
  final scrollDiagnosticsSummary = _computeScrollDiagnosticsSummary(
    measuredRuns,
  );
  final frameDiagnosticsSummary = _computeFrameDiagnosticsSummary(
    measuredRuns,
  );
  final measuredSegmentSummary = _computeMeasuredSegmentSummary(
    measuredRuns,
  );

  final jsonReport = <String, Object?>{
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'scenario': config.scenario,
    'device_id': config.deviceId,
    'frame_budget_ms': config.frameBudgetMs,
    'repeats': config.repeats,
    'warmup_runs': config.warmupRuns,
    'cooldown_ms_between_runs': config.cooldownMs,
    'max_jank_cv_percent': config.maxJankCvPercent,
    'enforce_max_jank_cv': config.enforceMaxJankCv,
    'max_jank_mad_percent': config.maxJankMadPercent,
    'enforce_max_jank_mad': config.enforceMaxJankMad,
    'defines': config.defines,
    'run_ids': measuredRuns.map((run) => run.runId).toList(),
    'warmup_run_ids': warmupRunIds,
    'variance_gate': varianceGate.toJson(
      enforced: config.enforceMaxJankCv,
    ),
    'outlier_diagnostics': outlierDiagnostics.toJson(),
    if (singleRunAnomalyDiagnostics != null)
      'single_run_anomaly': singleRunAnomalyDiagnostics.toJson(),
    'robust_jank_dispersion': robustJankDispersion.toJson(),
    'robust_variance_gate': robustVarianceGate.toJson(
      enforced: config.enforceMaxJankMad,
    ),
    if (scrollDiagnosticsSummary != null)
      'scroll_diagnostics_summary': scrollDiagnosticsSummary.toJson(),
    if (frameDiagnosticsSummary != null)
      'frame_diagnostics_summary': frameDiagnosticsSummary.toJson(),
    if (measuredSegmentSummary != null)
      'measured_segment_summary': measuredSegmentSummary.toJson(),
    'metrics': {
      for (final entry in metricsStats.entries) entry.key: entry.value.toJson(),
    },
    'runs': measuredRuns
        .map(
          (run) => <String, Object?>{
            'run_id': run.runId,
            ...run.metrics,
            if (run.scrollDiagnostics != null)
              'scroll_diagnostics': run.scrollDiagnostics!.toJson(),
            if (run.frameDiagnostics != null)
              'frame_diagnostics': run.frameDiagnostics!.toJson(),
          },
        )
        .toList(),
  };

  File(jsonReportPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(jsonReport),
  );

  final markdown = _buildMarkdownReport(
    generatedAtUtc: DateTime.now().toUtc().toIso8601String(),
    config: config,
    warmupRunIds: warmupRunIds,
    measuredRuns: measuredRuns,
    metricsStats: metricsStats,
    varianceGate: varianceGate,
    robustJankDispersion: robustJankDispersion,
    robustVarianceGate: robustVarianceGate,
    outlierDiagnostics: outlierDiagnostics,
    singleRunAnomalyDiagnostics: singleRunAnomalyDiagnostics,
    scrollDiagnosticsSummary: scrollDiagnosticsSummary,
    frameDiagnosticsSummary: frameDiagnosticsSummary,
    measuredSegmentSummary: measuredSegmentSummary,
    runIdsPath: runIdsPath,
    jsonReportPath: jsonReportPath,
  );
  File(markdownReportPath).writeAsStringSync(markdown);

  stdout.writeln('run_ids=$runIdsPath');
  stdout.writeln('metrics_json=$jsonReportPath');
  stdout.writeln('report_md=$markdownReportPath');
  var enforceFailed = false;
  if (config.enforceMaxJankCv && !varianceGate.pass) {
    stderr.writeln(
      'Variance gate failed: jank CV '
      '${_fmtNum(varianceGate.observedJankCvPercent, 2)}% '
      'exceeds limit ${_fmtNum(varianceGate.maxJankCvPercent, 2)}%.',
    );
    enforceFailed = true;
  }
  if (config.enforceMaxJankMad && !robustVarianceGate.pass) {
    stderr.writeln(
      'Robust variance gate failed: jank MAD '
      '${_fmtNum(robustVarianceGate.observedJankMadPercent, 2)}% '
      'exceeds limit ${_fmtNum(robustVarianceGate.maxJankMadPercent, 2)}%.',
    );
    enforceFailed = true;
  }
  if (enforceFailed) {
    exitCode = 1;
  }
}

class _Config {
  const _Config({
    required this.scenario,
    required this.deviceId,
    required this.frameBudgetMs,
    required this.repeats,
    required this.warmupRuns,
    required this.maxJankCvPercent,
    required this.enforceMaxJankCv,
    required this.maxJankMadPercent,
    required this.enforceMaxJankMad,
    required this.cooldownMs,
    required this.defines,
    required this.runIdsPath,
    required this.jsonReportPath,
    required this.markdownReportPath,
  });

  final String scenario;
  final String? deviceId;
  final double frameBudgetMs;
  final int repeats;
  final int warmupRuns;
  final double maxJankCvPercent;
  final bool enforceMaxJankCv;
  final double maxJankMadPercent;
  final bool enforceMaxJankMad;
  final int cooldownMs;
  final Map<String, String> defines;
  final String runIdsPath;
  final String jsonReportPath;
  final String markdownReportPath;
}

class _RunMetrics {
  const _RunMetrics({
    required this.runId,
    required this.metrics,
    required this.scrollDiagnostics,
    required this.frameDiagnostics,
  });

  final String runId;
  final Map<String, double> metrics;
  final _RunScrollDiagnostics? scrollDiagnostics;
  final _RunFrameDiagnostics? frameDiagnostics;
}

class _RunScrollDiagnostics {
  const _RunScrollDiagnostics({
    required this.pattern,
    required this.inputMode,
    required this.jumpProfile,
    required this.stepsRequested,
    required this.effectiveSteps,
    required this.noOpSteps,
    required this.edgeHitsMin,
    required this.edgeHitsMax,
    required this.averageAbsDeltaPx,
  });

  final String pattern;
  final String inputMode;
  final String jumpProfile;
  final int stepsRequested;
  final int effectiveSteps;
  final int noOpSteps;
  final int edgeHitsMin;
  final int edgeHitsMax;
  final double averageAbsDeltaPx;

  Map<String, Object> toJson() => <String, Object>{
    'pattern': pattern,
    'input_mode': inputMode,
    'jump_profile': jumpProfile,
    'steps_requested': stepsRequested,
    'effective_steps': effectiveSteps,
    'no_op_steps': noOpSteps,
    'edge_hits_min': edgeHitsMin,
    'edge_hits_max': edgeHitsMax,
    'average_abs_delta_px': _round(averageAbsDeltaPx, decimals: 3),
  };
}

class _RunMeasuredSegmentDiagnostics {
  const _RunMeasuredSegmentDiagnostics({
    required this.segmentIndex,
    required this.stepStart,
    required this.stepEndExclusive,
    required this.sampleCount,
    required this.jankOverBudget,
    required this.jankOver2x,
    required this.p95TotalMs,
    required this.maxTotalMs,
  });

  final int segmentIndex;
  final int stepStart;
  final int stepEndExclusive;
  final int sampleCount;
  final int jankOverBudget;
  final int jankOver2x;
  final double p95TotalMs;
  final double maxTotalMs;

  Map<String, Object> toJson() => <String, Object>{
    'segment_index': segmentIndex,
    'step_start': stepStart,
    'step_end_exclusive': stepEndExclusive,
    'sample_count': sampleCount,
    'jank_frames_over_budget': jankOverBudget,
    'jank_frames_over_2x_budget': jankOver2x,
    'p95_total_ms': _round(p95TotalMs, decimals: 3),
    'max_total_ms': _round(maxTotalMs, decimals: 3),
  };
}

_RunMeasuredSegmentDiagnostics? _selectHotMeasuredSegment(
  List<_RunMeasuredSegmentDiagnostics> segments,
) {
  _RunMeasuredSegmentDiagnostics? best;
  for (final segment in segments) {
    if (segment.sampleCount <= 0) {
      continue;
    }
    if (best == null) {
      best = segment;
      continue;
    }
    final better =
        segment.jankOver2x > best.jankOver2x ||
        (segment.jankOver2x == best.jankOver2x &&
            (segment.maxTotalMs > best.maxTotalMs ||
                (segment.maxTotalMs == best.maxTotalMs &&
                    (segment.p95TotalMs > best.p95TotalMs ||
                        (segment.p95TotalMs == best.p95TotalMs &&
                            segment.segmentIndex < best.segmentIndex)))));
    if (better) {
      best = segment;
    }
  }
  return best;
}

class _RunFrameDiagnostics {
  const _RunFrameDiagnostics({
    required this.sampleCount,
    required this.jankFramesOverBudget,
    required this.jankFramesOver2xBudget,
    required this.jankFramesOver3xBudget,
    required this.p99TotalMs,
    required this.maxTotalMs,
    required this.maxBuildMs,
    required this.maxRasterMs,
    required this.primarySpikePhase,
    required this.measuredScrollOver2xBudget,
    required this.settleOver2xBudget,
    required this.measuredSegments,
  });

  final int sampleCount;
  final int jankFramesOverBudget;
  final int jankFramesOver2xBudget;
  final int jankFramesOver3xBudget;
  final double p99TotalMs;
  final double maxTotalMs;
  final double maxBuildMs;
  final double maxRasterMs;
  final String primarySpikePhase;
  final int measuredScrollOver2xBudget;
  final int settleOver2xBudget;
  final List<_RunMeasuredSegmentDiagnostics> measuredSegments;

  Map<String, Object?> toJson() {
    final hotSegment = _selectHotMeasuredSegment(measuredSegments);
    return <String, Object?>{
      'sample_count': sampleCount,
      'jank_frames_over_budget': jankFramesOverBudget,
      'jank_frames_over_2x_budget': jankFramesOver2xBudget,
      'jank_frames_over_3x_budget': jankFramesOver3xBudget,
      'p99_total_ms': _round(p99TotalMs, decimals: 3),
      'max_total_ms': _round(maxTotalMs, decimals: 3),
      'max_build_ms': _round(maxBuildMs, decimals: 3),
      'max_raster_ms': _round(maxRasterMs, decimals: 3),
      'primary_spike_phase': primarySpikePhase,
      'measured_scroll_over_2x_budget': measuredScrollOver2xBudget,
      'settle_over_2x_budget': settleOver2xBudget,
      if (hotSegment != null) 'hot_measured_segment': hotSegment.toJson(),
      'measured_segments': measuredSegments
          .map((entry) => entry.toJson())
          .toList(),
    };
  }
}

class _FrameDiagnosticsSummary {
  const _FrameDiagnosticsSummary({
    required this.runCount,
    required this.jankFramesAvg,
    required this.over2xAvg,
    required this.over3xAvg,
    required this.maxTotalMsMedian,
    required this.maxTotalMsMax,
    required this.primarySuspectRunId,
    required this.primarySuspectOver2xCount,
  });

  final int runCount;
  final double jankFramesAvg;
  final double over2xAvg;
  final double over3xAvg;
  final double maxTotalMsMedian;
  final double maxTotalMsMax;
  final String? primarySuspectRunId;
  final int primarySuspectOver2xCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'run_count': runCount,
    'jank_frames_over_budget_avg': _round(jankFramesAvg, decimals: 3),
    'jank_frames_over_2x_budget_avg': _round(over2xAvg, decimals: 3),
    'jank_frames_over_3x_budget_avg': _round(over3xAvg, decimals: 3),
    'max_total_ms_median': _round(maxTotalMsMedian, decimals: 3),
    'max_total_ms_max': _round(maxTotalMsMax, decimals: 3),
    'primary_suspect_run_id': primarySuspectRunId,
    'primary_suspect_over_2x_budget_count': primarySuspectOver2xCount,
  };
}

class _MeasuredSegmentSummaryEntry {
  const _MeasuredSegmentSummaryEntry({
    required this.segmentIndex,
    required this.runsWithSamples,
    required this.over2xAvg,
    required this.p95TotalMsAvg,
    required this.maxTotalMsMax,
  });

  final int segmentIndex;
  final int runsWithSamples;
  final double over2xAvg;
  final double p95TotalMsAvg;
  final double maxTotalMsMax;

  Map<String, Object> toJson() => <String, Object>{
    'segment_index': segmentIndex,
    'runs_with_samples': runsWithSamples,
    'jank_frames_over_2x_budget_avg': _round(over2xAvg, decimals: 3),
    'p95_total_ms_avg': _round(p95TotalMsAvg, decimals: 3),
    'max_total_ms_max': _round(maxTotalMsMax, decimals: 3),
  };
}

class _MeasuredSegmentSummary {
  const _MeasuredSegmentSummary({
    required this.runCount,
    required this.segmentCount,
    required this.primaryHotSegmentIndex,
    required this.entries,
  });

  final int runCount;
  final int segmentCount;
  final int? primaryHotSegmentIndex;
  final List<_MeasuredSegmentSummaryEntry> entries;

  Map<String, Object?> toJson() => <String, Object?>{
    'run_count': runCount,
    'segment_count': segmentCount,
    'primary_hot_segment_index': primaryHotSegmentIndex,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };
}

class _ScrollDiagnosticsSummary {
  const _ScrollDiagnosticsSummary({
    required this.runCount,
    required this.noOpAvg,
    required this.noOpMax,
    required this.effectiveStepsAvg,
    required this.edgeHitsMinAvg,
    required this.edgeHitsMaxAvg,
    required this.averageAbsDeltaPxAvg,
  });

  final int runCount;
  final double noOpAvg;
  final int noOpMax;
  final double effectiveStepsAvg;
  final double edgeHitsMinAvg;
  final double edgeHitsMaxAvg;
  final double averageAbsDeltaPxAvg;

  Map<String, Object> toJson() => <String, Object>{
    'run_count': runCount,
    'no_op_steps_avg': _round(noOpAvg, decimals: 3),
    'no_op_steps_max': noOpMax,
    'effective_steps_avg': _round(effectiveStepsAvg, decimals: 3),
    'edge_hits_min_avg': _round(edgeHitsMinAvg, decimals: 3),
    'edge_hits_max_avg': _round(edgeHitsMaxAvg, decimals: 3),
    'average_abs_delta_px_avg': _round(averageAbsDeltaPxAvg, decimals: 3),
  };
}

class _MetricStats {
  const _MetricStats({
    required this.count,
    required this.min,
    required this.median,
    required this.mean,
    required this.max,
    required this.stdev,
    required this.cvPercent,
  });

  final int count;
  final double min;
  final double median;
  final double mean;
  final double max;
  final double stdev;
  final double cvPercent;

  Map<String, Object> toJson() => <String, Object>{
    'count': count,
    'min': _round(min, decimals: 3),
    'median': _round(median, decimals: 3),
    'mean': _round(mean, decimals: 3),
    'max': _round(max, decimals: 3),
    'stdev': _round(stdev, decimals: 3),
    'cv_percent': _round(cvPercent, decimals: 2),
  };
}

class _VarianceGate {
  const _VarianceGate({
    required this.maxJankCvPercent,
    required this.observedJankCvPercent,
    required this.pass,
  });

  final double maxJankCvPercent;
  final double observedJankCvPercent;
  final bool pass;

  Map<String, Object> toJson({required bool enforced}) => <String, Object>{
    'metric': 'jank_percent.cv_percent',
    'max_allowed_percent': _round(maxJankCvPercent, decimals: 2),
    'observed_percent': _round(observedJankCvPercent, decimals: 2),
    'pass': pass,
    'enforced': enforced,
  };
}

class _RobustJankDispersion {
  const _RobustJankDispersion({
    required this.q1,
    required this.q3,
    required this.iqr,
    required this.median,
    required this.mad,
    required this.scaledMad,
    required this.iqrPercentOfMedian,
    required this.madPercentOfMedian,
  });

  final double q1;
  final double q3;
  final double iqr;
  final double median;
  final double mad;
  final double scaledMad;
  final double iqrPercentOfMedian;
  final double madPercentOfMedian;

  Map<String, Object> toJson() => <String, Object>{
    'method': 'iqr_plus_mad',
    'q1': _round(q1, decimals: 3),
    'q3': _round(q3, decimals: 3),
    'iqr': _round(iqr, decimals: 3),
    'median': _round(median, decimals: 3),
    'mad': _round(mad, decimals: 3),
    'scaled_mad': _round(scaledMad, decimals: 3),
    'iqr_percent_of_median': _round(iqrPercentOfMedian, decimals: 2),
    'mad_percent_of_median': _round(madPercentOfMedian, decimals: 2),
  };
}

class _RobustVarianceGate {
  const _RobustVarianceGate({
    required this.maxJankMadPercent,
    required this.observedJankMadPercent,
    required this.pass,
  });

  final double maxJankMadPercent;
  final double observedJankMadPercent;
  final bool pass;

  Map<String, Object> toJson({required bool enforced}) => <String, Object>{
    'metric': 'jank_percent.mad_percent_of_median',
    'max_allowed_percent': _round(maxJankMadPercent, decimals: 2),
    'observed_percent': _round(observedJankMadPercent, decimals: 2),
    'pass': pass,
    'enforced': enforced,
  };
}

class _IqrBounds {
  const _IqrBounds({
    required this.q1,
    required this.q3,
    required this.iqr,
    required this.lowerFence,
    required this.upperFence,
  });

  final double q1;
  final double q3;
  final double iqr;
  final double lowerFence;
  final double upperFence;
}

class _OutlierMetricDiagnostics {
  const _OutlierMetricDiagnostics({
    required this.q1,
    required this.q3,
    required this.iqr,
    required this.lowerFence,
    required this.upperFence,
    required this.outliersByRun,
  });

  final double q1;
  final double q3;
  final double iqr;
  final double lowerFence;
  final double upperFence;
  final Map<String, double> outliersByRun;

  Map<String, Object> toJson() => <String, Object>{
    'q1': _round(q1, decimals: 3),
    'q3': _round(q3, decimals: 3),
    'iqr': _round(iqr, decimals: 3),
    'lower_fence': _round(lowerFence, decimals: 3),
    'upper_fence': _round(upperFence, decimals: 3),
    'outlier_count': outliersByRun.length,
    'outlier_runs': outliersByRun.entries
        .map(
          (entry) => <String, Object>{
            'run_id': entry.key,
            'value': _round(entry.value, decimals: 3),
          },
        )
        .toList(),
  };
}

class _OutlierDiagnostics {
  const _OutlierDiagnostics({
    required this.metrics,
    required this.runOutlierCounts,
    required this.primarySuspectRunId,
    required this.primarySuspectMetricCount,
  });

  final Map<String, _OutlierMetricDiagnostics> metrics;
  final Map<String, int> runOutlierCounts;
  final String? primarySuspectRunId;
  final int primarySuspectMetricCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'method': 'iqr_1.5x',
    'metrics': {
      for (final entry in metrics.entries) entry.key: entry.value.toJson(),
    },
    'run_outlier_counts': runOutlierCounts,
    'primary_suspect_run_id': primarySuspectRunId,
    'primary_suspect_metric_count': primarySuspectMetricCount,
  };
}

class _SingleRunAnomalyDiagnostics {
  const _SingleRunAnomalyDiagnostics({
    required this.suspectRunId,
    required this.suspectOutlierMetricCount,
    required this.totalRuns,
    required this.runsWithoutSuspect,
    required this.originalJankCvPercent,
    required this.jankCvWithoutSuspectPercent,
    required this.jankCvReductionPercentPoints,
    required this.maxJankCvPercent,
    required this.targetJankCvPercent,
    required this.passWithoutSuspect,
    required this.passWithoutSuspectForTarget,
    required this.singleRunDominated,
    required this.singleRunDominatedForTarget,
  });

  final String suspectRunId;
  final int suspectOutlierMetricCount;
  final int totalRuns;
  final int runsWithoutSuspect;
  final double originalJankCvPercent;
  final double jankCvWithoutSuspectPercent;
  final double jankCvReductionPercentPoints;
  final double maxJankCvPercent;
  final double targetJankCvPercent;
  final bool passWithoutSuspect;
  final bool passWithoutSuspectForTarget;
  final bool singleRunDominated;
  final bool singleRunDominatedForTarget;

  Map<String, Object> toJson() => <String, Object>{
    'suspect_run_id': suspectRunId,
    'suspect_outlier_metric_count': suspectOutlierMetricCount,
    'total_runs': totalRuns,
    'runs_without_suspect': runsWithoutSuspect,
    'jank_cv_percent_original': _round(originalJankCvPercent, decimals: 2),
    'jank_cv_percent_without_suspect': _round(
      jankCvWithoutSuspectPercent,
      decimals: 2,
    ),
    'jank_cv_reduction_percent_points': _round(
      jankCvReductionPercentPoints,
      decimals: 2,
    ),
    'max_jank_cv_percent': _round(maxJankCvPercent, decimals: 2),
    'target_jank_cv_percent': _round(targetJankCvPercent, decimals: 2),
    'pass_without_suspect': passWithoutSuspect,
    'pass_without_suspect_for_target': passWithoutSuspectForTarget,
    'single_run_dominated': singleRunDominated,
    'single_run_dominated_for_target': singleRunDominatedForTarget,
  };
}

_Config _parseArgs(List<String> args) {
  var scenario = _defaultScenario;
  String? deviceId;
  var frameBudgetMs = 16.67;
  var repeats = 10;
  var warmupRuns = 0;
  var maxJankCvPercent = 70.0;
  var enforceMaxJankCv = false;
  var maxJankMadPercent = 30.0;
  var enforceMaxJankMad = false;
  var cooldownMs = 0;
  final defines = <String, String>{};
  var stableScrollProfile = false;
  int? scrollSteps;
  double? scrollStepPx;
  int? scrollSettleFrames;
  int? scrollPumpFrameMs;
  int? preMeasureScrollSteps;
  String? scrollInputMode;
  String? scrollJumpProfile;
  String? scrollPattern;
  int? scrollPatternSegmentSteps;
  String? outputPrefix;
  String? runIdsPath;
  String? jsonReportPath;
  String? markdownReportPath;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      _printUsage();
      exit(0);
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
    if (arg == '--enforce-max-jank-cv') {
      enforceMaxJankCv = true;
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
    if (arg == '--enforce-max-jank-mad') {
      enforceMaxJankMad = true;
      continue;
    }
    if (arg == '--cooldown-ms' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed < 0) {
        throw ArgumentError('Invalid --cooldown-ms value.');
      }
      cooldownMs = parsed;
      continue;
    }
    if (arg == '--stable-scroll-profile') {
      stableScrollProfile = true;
      continue;
    }
    if (arg == '--scroll-steps' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --scroll-steps value.');
      }
      scrollSteps = parsed;
      continue;
    }
    if (arg == '--scroll-step-px' && i + 1 < args.length) {
      final parsed = double.tryParse(args[++i]);
      if (parsed == null || parsed == 0) {
        throw ArgumentError('Invalid --scroll-step-px value.');
      }
      scrollStepPx = parsed;
      continue;
    }
    if (arg == '--scroll-settle-frames' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed < 0) {
        throw ArgumentError('Invalid --scroll-settle-frames value.');
      }
      scrollSettleFrames = parsed;
      continue;
    }
    if (arg == '--scroll-pump-frame-ms' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --scroll-pump-frame-ms value.');
      }
      scrollPumpFrameMs = parsed;
      continue;
    }
    if (arg == '--pre-measure-scroll-steps' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed < 0) {
        throw ArgumentError('Invalid --pre-measure-scroll-steps value.');
      }
      preMeasureScrollSteps = parsed;
      continue;
    }
    if (arg == '--scroll-input-mode' && i + 1 < args.length) {
      scrollInputMode = _normalizeScrollInputMode(args[++i]);
      continue;
    }
    if (arg == '--scroll-jump-profile' && i + 1 < args.length) {
      scrollJumpProfile = _normalizeScrollJumpProfile(args[++i]);
      continue;
    }
    if (arg == '--scroll-pattern' && i + 1 < args.length) {
      scrollPattern = _normalizeScrollPattern(args[++i]);
      continue;
    }
    if (arg == '--scroll-pattern-segment-steps' && i + 1 < args.length) {
      final parsed = int.tryParse(args[++i]);
      if (parsed == null || parsed <= 0) {
        throw ArgumentError('Invalid --scroll-pattern-segment-steps value.');
      }
      scrollPatternSegmentSteps = parsed;
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
      defines[key] = value;
      continue;
    }
    if (arg == '--output-prefix' && i + 1 < args.length) {
      outputPrefix = args[++i];
      continue;
    }
    if (arg == '--run-ids-path' && i + 1 < args.length) {
      runIdsPath = args[++i];
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

  if (stableScrollProfile) {
    scrollPattern ??= 'ping_pong';
    scrollPatternSegmentSteps ??= 12;
    scrollStepPx ??= -240;
    scrollSteps ??= 140;
    preMeasureScrollSteps ??= 32;
    scrollSettleFrames ??= 160;
    scrollPumpFrameMs ??= 16;
  }

  if (scrollInputMode == 'jump' &&
      scrollJumpProfile == 'edge_bounce' &&
      scrollStepPx == null) {
    // Default tuned in Sprint 3 to reduce edge saturation noise in card variance.
    scrollStepPx = -280;
  }

  if (scrollSteps != null) {
    defines['BENCH_SCROLL_STEPS'] = '$scrollSteps';
  }
  if (scrollStepPx != null) {
    defines['BENCH_SCROLL_STEP_PX'] = scrollStepPx.toStringAsFixed(3);
  }
  if (scrollSettleFrames != null) {
    defines['BENCH_SCROLL_SETTLE_FRAMES'] = '$scrollSettleFrames';
  }
  if (scrollPumpFrameMs != null) {
    defines['BENCH_SCROLL_PUMP_FRAME_MS'] = '$scrollPumpFrameMs';
  }
  if (preMeasureScrollSteps != null) {
    defines['BENCH_PRE_MEASURE_SCROLL_STEPS'] = '$preMeasureScrollSteps';
  }
  if (scrollInputMode != null) {
    defines['BENCH_SCROLL_INPUT_MODE'] = scrollInputMode;
  }
  if (scrollJumpProfile != null) {
    defines['BENCH_SCROLL_JUMP_PROFILE'] = scrollJumpProfile;
  }
  if (scrollPattern != null) {
    defines['BENCH_SCROLL_PATTERN'] = scrollPattern;
  }
  if (scrollPatternSegmentSteps != null) {
    defines['BENCH_SCROLL_PATTERN_SEGMENT_STEPS'] =
        '$scrollPatternSegmentSteps';
  }

  final finalPrefix =
      outputPrefix ??
      'benchmarks/results/experiments/'
          '${_dateStamp(DateTime.now().toUtc())}_${scenario}_variance_r$repeats';

  return _Config(
    scenario: scenario,
    deviceId: deviceId,
    frameBudgetMs: frameBudgetMs,
    repeats: repeats,
    warmupRuns: warmupRuns,
    maxJankCvPercent: maxJankCvPercent,
    enforceMaxJankCv: enforceMaxJankCv,
    maxJankMadPercent: maxJankMadPercent,
    enforceMaxJankMad: enforceMaxJankMad,
    cooldownMs: cooldownMs,
    defines: Map<String, String>.unmodifiable(defines),
    runIdsPath: runIdsPath ?? '${finalPrefix}_run_ids.txt',
    jsonReportPath: jsonReportPath ?? '${finalPrefix}_metrics.json',
    markdownReportPath: markdownReportPath ?? '${finalPrefix}_report.md',
  );
}

void _printUsage() {
  stdout.writeln('Usage: dart run benchmarks/run_card_variance.dart [options]');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --scenario <name>        Scenario to evaluate (default: dynamic_card_50k).',
  );
  stdout.writeln('  --device <id>            Flutter device id (e.g., linux).');
  stdout.writeln(
    '  --frame-budget-ms <num>  Jank threshold in ms (default: 16.67).',
  );
  stdout.writeln(
    '  --repeats <n>            Measured runs (default: 10).',
  );
  stdout.writeln(
    '  --warmup-runs <n>        Warmup runs discarded before measurement (default: 0).',
  );
  stdout.writeln(
    '  --max-jank-cv <num>      Max allowed jank CV% for gate (default: 70).',
  );
  stdout.writeln(
    '  --enforce-max-jank-cv    Exit with code 1 if jank CV gate fails.',
  );
  stdout.writeln(
    '  --max-jank-mad-percent <num> Max allowed jank MAD%/median gate (default: 30).',
  );
  stdout.writeln(
    '  --enforce-max-jank-mad   Exit with code 1 if jank MAD gate fails.',
  );
  stdout.writeln(
    '  --cooldown-ms <n>        Wait n ms between warmup/measured runs (default: 0).',
  );
  stdout.writeln(
    '  --stable-scroll-profile  Apply deterministic scroll profile preset tuned for variance checks.',
  );
  stdout.writeln(
    '  --scroll-steps <n>       Override BENCH_SCROLL_STEPS.',
  );
  stdout.writeln(
    '  --scroll-step-px <num>   Override BENCH_SCROLL_STEP_PX.',
  );
  stdout.writeln(
    '  --scroll-settle-frames <n> Override BENCH_SCROLL_SETTLE_FRAMES.',
  );
  stdout.writeln(
    '  --scroll-pump-frame-ms <n> Override BENCH_SCROLL_PUMP_FRAME_MS.',
  );
  stdout.writeln(
    '  --pre-measure-scroll-steps <n> Override BENCH_PRE_MEASURE_SCROLL_STEPS.',
  );
  stdout.writeln(
    '  --scroll-input-mode <m>   Override BENCH_SCROLL_INPUT_MODE (drag|jump).',
  );
  stdout.writeln(
    '  --scroll-jump-profile <p> Override BENCH_SCROLL_JUMP_PROFILE (relative|edge_bounce).',
  );
  stdout.writeln(
    '  --scroll-pattern <p>     Override BENCH_SCROLL_PATTERN (forward|ping_pong).',
  );
  stdout.writeln(
    '  --scroll-pattern-segment-steps <n> Override BENCH_SCROLL_PATTERN_SEGMENT_STEPS.',
  );
  stdout.writeln(
    '  --define KEY=VALUE       Extra dart-define passed to run_benchmarks.',
  );
  stdout.writeln(
    '  --output-prefix <path>   Prefix for generated artifacts (default: timestamped in experiments/).',
  );
  stdout.writeln(
    '  --run-ids-path <path>    Output path for measured run ids.',
  );
  stdout.writeln(
    '  --json-report-path <p>   Output path for JSON report.',
  );
  stdout.writeln(
    '  --report-path <path>     Output path for markdown report.',
  );
  stdout.writeln('  -h, --help               Show this help.');
}

Future<String> _runSingleScenario(_Config config) async {
  final args = <String>[
    'run',
    'benchmarks/run_benchmarks.dart',
    '--scenario',
    config.scenario,
    '--frame-budget-ms',
    config.frameBudgetMs.toStringAsFixed(2),
    if (config.deviceId != null) ...['--device', config.deviceId!],
  ];

  final defineEntries = config.defines.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in defineEntries) {
    args.addAll(<String>['--define', '${entry.key}=${entry.value}']);
  }

  final process = await Process.start(
    'dart',
    args,
    runInShell: true,
  );

  final parser = _RunIdParser();
  final stdoutDone = process.stdout.transform(utf8.decoder).listen((chunk) {
    stdout.write(chunk);
    parser.consume(chunk);
  }).asFuture<void>();

  final stderrDone = process.stderr.transform(utf8.decoder).listen((chunk) {
    stderr.write(chunk);
  }).asFuture<void>();

  final exitCode = await process.exitCode;
  await stdoutDone;
  await stderrDone;
  parser.close();

  if (exitCode != 0) {
    throw ProcessException('dart', args, 'Exit code: $exitCode', exitCode);
  }
  if (parser.runId == null) {
    throw StateError(
      'Could not parse run id from run_benchmarks output.',
    );
  }
  return parser.runId!;
}

Map<String, double> _readScenarioMetrics(String runId, String scenario) {
  final raw = _readScenarioJson(runId, scenario);
  return <String, double>{
    for (final key in _metricKeys) key: _asDouble(raw[key]),
  };
}

_RunScrollDiagnostics? _readRunScrollDiagnostics(
  String runId,
  String scenario,
) {
  final raw = _readScenarioJson(runId, scenario);
  final profileRaw = raw['scroll_profile'];
  final diagnosticsRaw = raw['scroll_diagnostics'];
  if (profileRaw is! Map) return null;
  if (diagnosticsRaw is! Map) return null;
  final measuredRaw = diagnosticsRaw['measured'];
  if (measuredRaw is! Map) return null;

  final pattern = profileRaw['pattern']?.toString() ?? '';
  final inputMode = profileRaw['input_mode']?.toString() ?? '';
  final jumpProfile = profileRaw['jump_profile']?.toString() ?? 'relative';
  if (pattern.isEmpty || inputMode.isEmpty) return null;

  return _RunScrollDiagnostics(
    pattern: pattern,
    inputMode: inputMode,
    jumpProfile: jumpProfile,
    stepsRequested: _asInt(measuredRaw['steps_requested']),
    effectiveSteps: _asInt(measuredRaw['effective_steps']),
    noOpSteps: _asInt(measuredRaw['no_op_steps']),
    edgeHitsMin: _asInt(measuredRaw['edge_hits_min']),
    edgeHitsMax: _asInt(measuredRaw['edge_hits_max']),
    averageAbsDeltaPx: _asDouble(measuredRaw['average_abs_delta_px']),
  );
}

_RunFrameDiagnostics? _readRunFrameDiagnostics(
  String runId,
  String scenario,
) {
  final raw = _readScenarioJson(runId, scenario);
  final diagnosticsRaw = _asMap(raw['frame_diagnostics']);
  if (diagnosticsRaw == null) return null;

  final topSpikes = _asList(diagnosticsRaw['top_spikes']);
  final primarySpikeRaw = topSpikes.isEmpty ? null : _asMap(topSpikes.first);
  final hasPrimarySpikePhase =
      primarySpikeRaw?['phase']?.toString().trim().isNotEmpty ?? false;
  final primarySpikePhase = hasPrimarySpikePhase
      ? primarySpikeRaw!['phase']!.toString()
      : 'unknown';

  final phasesRaw = _asMap(diagnosticsRaw['phases']);
  final measuredRaw = _asMap(phasesRaw?['measured_scroll']);
  final settleRaw = _asMap(phasesRaw?['settle']);
  final measuredSegments = _asList(diagnosticsRaw['measured_segments'])
      .map(_asMap)
      .whereType<Map<String, Object?>>()
      .map(
        (entry) => _RunMeasuredSegmentDiagnostics(
          segmentIndex: _asInt(entry['segment_index']),
          stepStart: _asInt(entry['step_start']),
          stepEndExclusive: _asInt(entry['step_end_exclusive']),
          sampleCount: _asInt(entry['sample_count']),
          jankOverBudget: _asInt(entry['jank_frames_over_budget']),
          jankOver2x: _asInt(entry['jank_frames_over_2x_budget']),
          p95TotalMs: _asDouble(entry['p95_total_ms']),
          maxTotalMs: _asDouble(entry['max_total_ms']),
        ),
      )
      .toList(growable: false);

  return _RunFrameDiagnostics(
    sampleCount: _asInt(diagnosticsRaw['sample_count']),
    jankFramesOverBudget: _asInt(diagnosticsRaw['jank_frames_over_budget']),
    jankFramesOver2xBudget: _asInt(
      diagnosticsRaw['jank_frames_over_2x_budget'],
    ),
    jankFramesOver3xBudget: _asInt(
      diagnosticsRaw['jank_frames_over_3x_budget'],
    ),
    p99TotalMs: _asDouble(diagnosticsRaw['p99_total_ms']),
    maxTotalMs: _asDouble(diagnosticsRaw['max_total_ms']),
    maxBuildMs: _asDouble(diagnosticsRaw['max_build_ms']),
    maxRasterMs: _asDouble(diagnosticsRaw['max_raster_ms']),
    primarySpikePhase: primarySpikePhase,
    measuredScrollOver2xBudget: _asInt(
      measuredRaw?['jank_frames_over_2x_budget'],
    ),
    settleOver2xBudget: _asInt(settleRaw?['jank_frames_over_2x_budget']),
    measuredSegments: measuredSegments,
  );
}

Map<String, dynamic> _readScenarioJson(String runId, String scenario) {
  final scenarioFile = File('benchmarks/results/$runId/$scenario.json');
  if (!scenarioFile.existsSync()) {
    throw StateError('Scenario metrics not found: ${scenarioFile.path}');
  }
  final raw = jsonDecode(scenarioFile.readAsStringSync());
  if (raw is! Map<String, dynamic>) {
    throw StateError('Invalid scenario JSON: ${scenarioFile.path}');
  }
  return raw;
}

_FrameDiagnosticsSummary? _computeFrameDiagnosticsSummary(
  List<_RunMetrics> runs,
) {
  final diagnostics = runs
      .where((run) => run.frameDiagnostics != null)
      .map((run) => MapEntry(run.runId, run.frameDiagnostics!))
      .toList();
  if (diagnostics.isEmpty) {
    return null;
  }

  final runCount = diagnostics.length;
  final jankFramesTotal = diagnostics
      .map((entry) => entry.value.jankFramesOverBudget)
      .fold<int>(0, (sum, value) => sum + value);
  final over2xTotal = diagnostics
      .map((entry) => entry.value.jankFramesOver2xBudget)
      .fold<int>(0, (sum, value) => sum + value);
  final over3xTotal = diagnostics
      .map((entry) => entry.value.jankFramesOver3xBudget)
      .fold<int>(0, (sum, value) => sum + value);

  final maxTotals =
      diagnostics.map((entry) => entry.value.maxTotalMs).toList(growable: false)
        ..sort();
  final maxTotalMsMedian = _median(maxTotals);
  final maxTotalMsMax = maxTotals.last;

  String? primarySuspectRunId;
  var primarySuspectOver2xCount = 0;
  var primarySuspectMaxTotal = 0.0;
  for (final entry in diagnostics) {
    final over2x = entry.value.jankFramesOver2xBudget;
    final maxTotal = entry.value.maxTotalMs;
    final isBetter =
        over2x > primarySuspectOver2xCount ||
        (over2x == primarySuspectOver2xCount &&
            maxTotal > primarySuspectMaxTotal);
    if (isBetter) {
      primarySuspectOver2xCount = over2x;
      primarySuspectMaxTotal = maxTotal;
      primarySuspectRunId = entry.key;
    }
  }
  if (primarySuspectOver2xCount <= 0) {
    primarySuspectRunId = null;
  }

  return _FrameDiagnosticsSummary(
    runCount: runCount,
    jankFramesAvg: jankFramesTotal / runCount,
    over2xAvg: over2xTotal / runCount,
    over3xAvg: over3xTotal / runCount,
    maxTotalMsMedian: maxTotalMsMedian,
    maxTotalMsMax: maxTotalMsMax,
    primarySuspectRunId: primarySuspectRunId,
    primarySuspectOver2xCount: primarySuspectOver2xCount,
  );
}

_MeasuredSegmentSummary? _computeMeasuredSegmentSummary(
  List<_RunMetrics> runs,
) {
  final bySegment = <int, List<_RunMeasuredSegmentDiagnostics>>{};

  for (final run in runs) {
    final segments = run.frameDiagnostics?.measuredSegments;
    if (segments == null || segments.isEmpty) {
      continue;
    }
    for (final segment in segments) {
      bySegment
          .putIfAbsent(
            segment.segmentIndex,
            () => <_RunMeasuredSegmentDiagnostics>[],
          )
          .add(segment);
    }
  }

  if (bySegment.isEmpty) {
    return null;
  }

  final entries =
      bySegment.entries
          .map((entry) {
            final segments = entry.value;
            final withSamples = segments
                .where((segment) => segment.sampleCount > 0)
                .toList(growable: false);
            final over2xTotal = segments
                .map((segment) => segment.jankOver2x)
                .fold<int>(0, (sum, value) => sum + value);
            final p95Avg = withSamples.isEmpty
                ? 0.0
                : withSamples
                          .map((segment) => segment.p95TotalMs)
                          .fold<double>(0, (sum, value) => sum + value) /
                      withSamples.length;
            final maxTotalMsMax = withSamples.isEmpty
                ? 0.0
                : withSamples
                      .map((segment) => segment.maxTotalMs)
                      .reduce((a, b) => a > b ? a : b);
            return _MeasuredSegmentSummaryEntry(
              segmentIndex: entry.key,
              runsWithSamples: withSamples.length,
              over2xAvg: over2xTotal / segments.length,
              p95TotalMsAvg: p95Avg,
              maxTotalMsMax: maxTotalMsMax,
            );
          })
          .toList(growable: false)
        ..sort((a, b) {
          final over2xCompare = b.over2xAvg.compareTo(a.over2xAvg);
          if (over2xCompare != 0) {
            return over2xCompare;
          }
          final maxCompare = b.maxTotalMsMax.compareTo(a.maxTotalMsMax);
          if (maxCompare != 0) {
            return maxCompare;
          }
          final p95Compare = b.p95TotalMsAvg.compareTo(a.p95TotalMsAvg);
          if (p95Compare != 0) {
            return p95Compare;
          }
          return a.segmentIndex.compareTo(b.segmentIndex);
        });

  final primary = entries.first;
  final hasPrimarySignal =
      primary.over2xAvg > 0 ||
      primary.maxTotalMsMax > 0 ||
      primary.p95TotalMsAvg > 0;

  return _MeasuredSegmentSummary(
    runCount: runs.length,
    segmentCount: entries.length,
    primaryHotSegmentIndex: hasPrimarySignal ? primary.segmentIndex : null,
    entries: entries,
  );
}

_ScrollDiagnosticsSummary? _computeScrollDiagnosticsSummary(
  List<_RunMetrics> runs,
) {
  final diagnostics = runs
      .map((run) => run.scrollDiagnostics)
      .whereType<_RunScrollDiagnostics>()
      .toList();
  if (diagnostics.isEmpty) {
    return null;
  }

  final runCount = diagnostics.length;
  final noOpTotal = diagnostics
      .map((entry) => entry.noOpSteps)
      .fold<int>(0, (sum, value) => sum + value);
  final noOpMax = diagnostics
      .map((entry) => entry.noOpSteps)
      .reduce((a, b) => a > b ? a : b);
  final effectiveTotal = diagnostics
      .map((entry) => entry.effectiveSteps)
      .fold<int>(0, (sum, value) => sum + value);
  final edgeHitsMinTotal = diagnostics
      .map((entry) => entry.edgeHitsMin)
      .fold<int>(0, (sum, value) => sum + value);
  final edgeHitsMaxTotal = diagnostics
      .map((entry) => entry.edgeHitsMax)
      .fold<int>(0, (sum, value) => sum + value);
  final absDeltaTotal = diagnostics
      .map((entry) => entry.averageAbsDeltaPx)
      .fold<double>(0, (sum, value) => sum + value);

  return _ScrollDiagnosticsSummary(
    runCount: runCount,
    noOpAvg: noOpTotal / runCount,
    noOpMax: noOpMax,
    effectiveStepsAvg: effectiveTotal / runCount,
    edgeHitsMinAvg: edgeHitsMinTotal / runCount,
    edgeHitsMaxAvg: edgeHitsMaxTotal / runCount,
    averageAbsDeltaPxAvg: absDeltaTotal / runCount,
  );
}

_MetricStats _computeStats(List<double> values) {
  if (values.isEmpty) {
    throw StateError('Cannot compute stats for empty values.');
  }
  final sorted = values.toList()..sort();
  final count = sorted.length;
  final min = sorted.first;
  final max = sorted.last;
  final median = _median(sorted);
  final mean = sorted.reduce((a, b) => a + b) / count;
  final variance =
      sorted
          .map((value) => (value - mean) * (value - mean))
          .reduce((a, b) => a + b) /
      count;
  final stdev = math.sqrt(variance);
  final cvPercent = mean == 0 ? 0.0 : (stdev / mean) * 100;
  return _MetricStats(
    count: count,
    min: min,
    median: median,
    mean: mean,
    max: max,
    stdev: stdev,
    cvPercent: cvPercent,
  );
}

double _median(List<double> sortedValues) {
  final length = sortedValues.length;
  if (length.isOdd) {
    return sortedValues[length ~/ 2];
  }
  final right = length ~/ 2;
  final left = right - 1;
  return (sortedValues[left] + sortedValues[right]) / 2;
}

String _buildMarkdownReport({
  required String generatedAtUtc,
  required _Config config,
  required List<String> warmupRunIds,
  required List<_RunMetrics> measuredRuns,
  required Map<String, _MetricStats> metricsStats,
  required _VarianceGate varianceGate,
  required _RobustJankDispersion robustJankDispersion,
  required _RobustVarianceGate robustVarianceGate,
  required _OutlierDiagnostics outlierDiagnostics,
  required _SingleRunAnomalyDiagnostics? singleRunAnomalyDiagnostics,
  required _ScrollDiagnosticsSummary? scrollDiagnosticsSummary,
  required _FrameDiagnosticsSummary? frameDiagnosticsSummary,
  required _MeasuredSegmentSummary? measuredSegmentSummary,
  required String runIdsPath,
  required String jsonReportPath,
}) {
  final buffer = StringBuffer()
    ..writeln(
      '# Variance Report: ${config.scenario} (r${config.repeats}, w${config.warmupRuns})',
    )
    ..writeln()
    ..writeln('- Fecha UTC: `$generatedAtUtc`')
    ..writeln('- Escenario: `${config.scenario}`')
    ..writeln('- Device: `${config.deviceId ?? 'default'}`')
    ..writeln('- Frame budget: `${config.frameBudgetMs.toStringAsFixed(2)} ms`')
    ..writeln('- Corridas medidas: `${config.repeats}`')
    ..writeln('- Warmups descartados: `${config.warmupRuns}`')
    ..writeln('- Cooldown entre corridas: `${config.cooldownMs} ms`')
    ..writeln('- Max jank CV gate: `${_fmtNum(config.maxJankCvPercent, 2)}%`')
    ..writeln('- Enforce jank CV gate: `${config.enforceMaxJankCv}`')
    ..writeln('- Max jank MAD gate: `${_fmtNum(config.maxJankMadPercent, 2)}%`')
    ..writeln('- Enforce jank MAD gate: `${config.enforceMaxJankMad}`')
    ..writeln('- run_ids: `$runIdsPath`')
    ..writeln('- JSON: `$jsonReportPath`');

  if (config.defines.isNotEmpty) {
    buffer.writeln('- Extra defines: `${_formatDefines(config.defines)}`');
  }

  if (warmupRunIds.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(
        'Warmup run_ids descartados: ${warmupRunIds.map((id) => '`$id`').join(', ')}',
      );
  }

  buffer
    ..writeln()
    ..writeln('## Corridas')
    ..writeln()
    ..writeln(
      '| run_id | p95_build_ms | p95_raster_ms | jank% | peak_memory_mb | tti_ms |',
    )
    ..writeln('|---|---:|---:|---:|---:|---:|');

  for (final run in measuredRuns) {
    buffer.writeln(
      '| `${run.runId}` | '
      '${_fmt(run.metrics['p95_build_ms'])} | '
      '${_fmt(run.metrics['p95_raster_ms'])} | '
      '${_fmt(run.metrics['jank_percent'])} | '
      '${_fmt(run.metrics['peak_memory_mb'])} | '
      '${_fmt(run.metrics['time_to_first_interaction_ms'])} |',
    );
  }

  buffer
    ..writeln()
    ..writeln('## Estadisticas agregadas')
    ..writeln()
    ..writeln(
      '| metrica | min | mediana | media | max | stdev | cv% | nivel_varianza |',
    )
    ..writeln('|---|---:|---:|---:|---:|---:|---:|---|');

  for (final metric in _metricKeys) {
    final stats = metricsStats[metric]!;
    buffer.writeln(
      '| `$metric` | '
      '${_fmtNum(stats.min, 3)} | '
      '${_fmtNum(stats.median, 3)} | '
      '${_fmtNum(stats.mean, 3)} | '
      '${_fmtNum(stats.max, 3)} | '
      '${_fmtNum(stats.stdev, 3)} | '
      '${_fmtNum(stats.cvPercent, 2)} | '
      '${_varianceTier(stats.cvPercent)} |',
    );
  }

  final jankCv = metricsStats['jank_percent']!.cvPercent;
  final hasEnoughSamples = measuredRuns.length >= 3;
  final recommendedRepeats = hasEnoughSamples
      ? (jankCv >= 30 ? 7 : (jankCv >= 15 ? 5 : 3))
      : 7;

  buffer
    ..writeln()
    ..writeln('## Gate de varianza (%jank)')
    ..writeln()
    ..writeln('- Threshold CV: `${_fmtNum(varianceGate.maxJankCvPercent, 2)}%`')
    ..writeln(
      '- Observado CV: `${_fmtNum(varianceGate.observedJankCvPercent, 2)}%`',
    )
    ..writeln('- Decision: `${varianceGate.pass ? 'PASS' : 'FAIL'}`')
    ..writeln('- Enforced: `${config.enforceMaxJankCv}`')
    ..writeln()
    ..writeln('## Gate robusto (%jank, MAD)')
    ..writeln()
    ..writeln(
      '- Formula: `robust_cv = (1.4826 * MAD(jank)) / mediana(jank) * 100`',
    )
    ..writeln(
      '- Threshold MAD gate: `${_fmtNum(robustVarianceGate.maxJankMadPercent, 2)}%`',
    )
    ..writeln(
      '- Observado MAD gate: `${_fmtNum(robustVarianceGate.observedJankMadPercent, 2)}%`',
    )
    ..writeln(
      '- Decision MAD gate: `${robustVarianceGate.pass ? 'PASS' : 'FAIL'}`',
    )
    ..writeln('- Enforced MAD gate: `${config.enforceMaxJankMad}`')
    ..writeln(
      '- mediana `%jank`: `${_fmtNum(robustJankDispersion.median, 3)}%`',
    )
    ..writeln('- MAD `%jank`: `${_fmtNum(robustJankDispersion.mad, 3)} pp`')
    ..writeln(
      '- IQR `%jank`: `${_fmtNum(robustJankDispersion.iqr, 3)} pp` '
      '(`IQR/mediana=${_fmtNum(robustJankDispersion.iqrPercentOfMedian, 2)}%`)',
    )
    ..writeln()
    ..writeln('## Diagnostico de outliers (IQR)')
    ..writeln()
    ..writeln('| metrica | q1 | q3 | iqr | lower | upper | outliers |')
    ..writeln('|---|---:|---:|---:|---:|---:|---|');

  for (final metric in _metricKeys) {
    final metricOutliers = outlierDiagnostics.metrics[metric]!;
    final outlierRuns = metricOutliers.outliersByRun.entries
        .map((entry) => '`${entry.key}` (${_fmtNum(entry.value, 3)})')
        .join(', ');
    buffer.writeln(
      '| `$metric` | '
      '${_fmtNum(metricOutliers.q1, 3)} | '
      '${_fmtNum(metricOutliers.q3, 3)} | '
      '${_fmtNum(metricOutliers.iqr, 3)} | '
      '${_fmtNum(metricOutliers.lowerFence, 3)} | '
      '${_fmtNum(metricOutliers.upperFence, 3)} | '
      '${outlierRuns.isEmpty ? '-' : outlierRuns} |',
    );
  }

  final runOutlierSummary = outlierDiagnostics.runOutlierCounts.entries
      .where((entry) => entry.value > 0)
      .map((entry) => '`${entry.key}` (${entry.value})')
      .join(', ');
  if (outlierDiagnostics.primarySuspectRunId == null) {
    buffer.writeln('- Corridas con outliers: `ninguna`');
  } else {
    buffer.writeln('- Corridas con outliers: $runOutlierSummary');
    buffer.writeln(
      '- Run sospechoso principal: `${outlierDiagnostics.primarySuspectRunId}` '
      '(${outlierDiagnostics.primarySuspectMetricCount} metricas outlier).',
    );
  }

  if (singleRunAnomalyDiagnostics != null) {
    buffer
      ..writeln()
      ..writeln('## Diagnostico de corrida anomala (single-run)')
      ..writeln()
      ..writeln(
        '- Run sospechoso IQR: `${singleRunAnomalyDiagnostics.suspectRunId}` '
        '(${singleRunAnomalyDiagnostics.suspectOutlierMetricCount} metricas outlier).',
      )
      ..writeln(
        '- `%jank` CV original: '
        '`${_fmtNum(singleRunAnomalyDiagnostics.originalJankCvPercent, 2)}%`',
      )
      ..writeln(
        '- `%jank` CV sin run sospechoso: '
        '`${_fmtNum(singleRunAnomalyDiagnostics.jankCvWithoutSuspectPercent, 2)}%`',
      )
      ..writeln(
        '- Reduccion CV: '
        '`${_fmtNum(singleRunAnomalyDiagnostics.jankCvReductionPercentPoints, 2)} pp`',
      )
      ..writeln(
        '- Gate CV sin sospechoso (`<=${_fmtNum(singleRunAnomalyDiagnostics.maxJankCvPercent, 2)}%`): '
        '`${singleRunAnomalyDiagnostics.passWithoutSuspect ? 'PASS' : 'FAIL'}`',
      )
      ..writeln(
        '- Objetivo tecnico P0 sin sospechoso (`<=${_fmtNum(singleRunAnomalyDiagnostics.targetJankCvPercent, 2)}%`): '
        '`${singleRunAnomalyDiagnostics.passWithoutSuspectForTarget ? 'PASS' : 'FAIL'}`',
      )
      ..writeln(
        '- Dominancia por corrida unica (gate operativo): '
        '`${singleRunAnomalyDiagnostics.singleRunDominated}`',
      )
      ..writeln(
        '- Dominancia por corrida unica (objetivo P0): '
        '`${singleRunAnomalyDiagnostics.singleRunDominatedForTarget}`',
      );
  }

  if (scrollDiagnosticsSummary != null) {
    buffer
      ..writeln()
      ..writeln('## Diagnostico de scroll (medido)')
      ..writeln()
      ..writeln('| metrica | valor |')
      ..writeln('|---|---:|')
      ..writeln(
        '| `no_op_steps_avg` | ${_fmtNum(scrollDiagnosticsSummary.noOpAvg, 3)} |',
      )
      ..writeln(
        '| `no_op_steps_max` | ${scrollDiagnosticsSummary.noOpMax} |',
      )
      ..writeln(
        '| `effective_steps_avg` | ${_fmtNum(scrollDiagnosticsSummary.effectiveStepsAvg, 3)} |',
      )
      ..writeln(
        '| `edge_hits_min_avg` | ${_fmtNum(scrollDiagnosticsSummary.edgeHitsMinAvg, 3)} |',
      )
      ..writeln(
        '| `edge_hits_max_avg` | ${_fmtNum(scrollDiagnosticsSummary.edgeHitsMaxAvg, 3)} |',
      )
      ..writeln(
        '| `average_abs_delta_px_avg` | ${_fmtNum(scrollDiagnosticsSummary.averageAbsDeltaPxAvg, 3)} |',
      );
  }

  final frameRuns = measuredRuns
      .where((run) => run.frameDiagnostics != null)
      .toList(growable: false);
  if (frameRuns.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## Diagnostico de frames (spikes)')
      ..writeln()
      ..writeln(
        '| run_id | jank>budget | jank>2x | jank>3x | p99_total_ms | max_total_ms | max_build_ms | max_raster_ms | spike_phase | measured>2x | settle>2x | hot_segment |',
      )
      ..writeln(
        '|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---|',
      );

    for (final run in frameRuns) {
      final diagnostics = run.frameDiagnostics!;
      final hotSegment = _selectHotMeasuredSegment(
        diagnostics.measuredSegments,
      );
      final hotSegmentLabel = hotSegment == null
          ? '-'
          : 's${hotSegment.segmentIndex} '
                '(2x=${hotSegment.jankOver2x}, '
                'p95=${_fmtNum(hotSegment.p95TotalMs, 1)}, '
                'max=${_fmtNum(hotSegment.maxTotalMs, 1)})';
      buffer.writeln(
        '| `${run.runId}` | '
        '${diagnostics.jankFramesOverBudget} | '
        '${diagnostics.jankFramesOver2xBudget} | '
        '${diagnostics.jankFramesOver3xBudget} | '
        '${_fmtNum(diagnostics.p99TotalMs, 3)} | '
        '${_fmtNum(diagnostics.maxTotalMs, 3)} | '
        '${_fmtNum(diagnostics.maxBuildMs, 3)} | '
        '${_fmtNum(diagnostics.maxRasterMs, 3)} | '
        '${diagnostics.primarySpikePhase} | '
        '${diagnostics.measuredScrollOver2xBudget} | '
        '${diagnostics.settleOver2xBudget} | '
        '$hotSegmentLabel |',
      );
    }
  }

  if (frameDiagnosticsSummary != null) {
    buffer
      ..writeln()
      ..writeln('### Resumen de frames')
      ..writeln()
      ..writeln(
        '- jank>budget avg: `${_fmtNum(frameDiagnosticsSummary.jankFramesAvg, 3)}`',
      )
      ..writeln(
        '- jank>2x avg: `${_fmtNum(frameDiagnosticsSummary.over2xAvg, 3)}`',
      )
      ..writeln(
        '- jank>3x avg: `${_fmtNum(frameDiagnosticsSummary.over3xAvg, 3)}`',
      )
      ..writeln(
        '- max_total_ms (mediana/max): '
        '`${_fmtNum(frameDiagnosticsSummary.maxTotalMsMedian, 3)}` / '
        '`${_fmtNum(frameDiagnosticsSummary.maxTotalMsMax, 3)}`',
      )
      ..writeln(
        '- run sospechoso por spikes >2x: '
        '${frameDiagnosticsSummary.primarySuspectRunId == null ? '`ninguno`' : '`${frameDiagnosticsSummary.primarySuspectRunId}`'} '
        '(count=${frameDiagnosticsSummary.primarySuspectOver2xCount})',
      );
  }

  if (measuredSegmentSummary != null) {
    buffer
      ..writeln()
      ..writeln('### Hotspots por segmento (measured_scroll)')
      ..writeln()
      ..writeln(
        '| segmento | runs_con_muestras | jank>2x_avg | p95_total_ms_avg | max_total_ms_max |',
      )
      ..writeln('|---|---:|---:|---:|---:|');
    for (final entry in measuredSegmentSummary.entries.take(5)) {
      buffer.writeln(
        '| `s${entry.segmentIndex}` | '
        '${entry.runsWithSamples} | '
        '${_fmtNum(entry.over2xAvg, 3)} | '
        '${_fmtNum(entry.p95TotalMsAvg, 3)} | '
        '${_fmtNum(entry.maxTotalMsMax, 3)} |',
      );
    }
    final primarySegment = measuredSegmentSummary.primaryHotSegmentIndex;
    buffer.writeln(
      '- segmento hotspot primario: '
      '${primarySegment == null ? '`ninguno`' : '`s$primarySegment`'}',
    );
  }

  buffer
    ..writeln()
    ..writeln('## Lectura')
    ..writeln()
    ..writeln(
      hasEnoughSamples
          ? '1. `%jank` tiene CV `${_fmtNum(jankCv, 2)}%` (${_varianceTier(jankCv)}), '
                'por lo que no conviene decidir cambios de default con corridas `r1`.'
          : '1. Muestra insuficiente (`repeats < 3`): el CV observado '
                '(`${_fmtNum(jankCv, 2)}%`) no es estable para decision de gate.',
    )
    ..writeln(
      '2. Recomendacion de gate: usar `repeats >= $recommendedRepeats` y decidir por mediana.',
    )
    ..writeln(
      '3. Gate robusto (MAD) agrega una senal menos sensible a la media que el CV clasico.',
    );

  return buffer.toString();
}

_VarianceGate _buildVarianceGate({
  required double jankCvPercent,
  required double maxJankCvPercent,
}) {
  return _VarianceGate(
    maxJankCvPercent: maxJankCvPercent,
    observedJankCvPercent: jankCvPercent,
    pass: jankCvPercent <= maxJankCvPercent,
  );
}

_RobustJankDispersion _computeRobustJankDispersion(List<double> values) {
  if (values.isEmpty) {
    throw StateError('Cannot compute robust jank dispersion for empty values.');
  }

  final sorted = values.toList()..sort();
  final median = _median(sorted);
  final q1 = _percentile(sorted, 0.25);
  final q3 = _percentile(sorted, 0.75);
  final iqr = q3 - q1;

  final absoluteDeviations =
      sorted.map((value) => (value - median).abs()).toList()..sort();
  final mad = _median(absoluteDeviations);
  final scaledMad = mad * 1.4826;

  final iqrPercentOfMedian = _percentOfBase(iqr, median);
  final madPercentOfMedian = _percentOfBase(scaledMad, median);

  return _RobustJankDispersion(
    q1: q1,
    q3: q3,
    iqr: iqr,
    median: median,
    mad: mad,
    scaledMad: scaledMad,
    iqrPercentOfMedian: iqrPercentOfMedian,
    madPercentOfMedian: madPercentOfMedian,
  );
}

_RobustVarianceGate _buildRobustVarianceGate({
  required double observedJankMadPercent,
  required double maxJankMadPercent,
}) {
  return _RobustVarianceGate(
    maxJankMadPercent: maxJankMadPercent,
    observedJankMadPercent: observedJankMadPercent,
    pass: observedJankMadPercent <= maxJankMadPercent,
  );
}

_OutlierDiagnostics _buildOutlierDiagnostics(List<_RunMetrics> runs) {
  if (runs.isEmpty) {
    throw StateError('Cannot build outlier diagnostics for empty runs.');
  }

  final runOutlierCounts = <String, int>{
    for (final run in runs) run.runId: 0,
  };
  final metrics = <String, _OutlierMetricDiagnostics>{};

  for (final metric in _metricKeys) {
    final values = runs.map((run) => run.metrics[metric]!).toList();
    final bounds = _computeIqrBounds(values);
    final outliersByRun = <String, double>{};

    for (final run in runs) {
      final value = run.metrics[metric]!;
      if (value < bounds.lowerFence || value > bounds.upperFence) {
        outliersByRun[run.runId] = value;
        runOutlierCounts[run.runId] = runOutlierCounts[run.runId]! + 1;
      }
    }

    metrics[metric] = _OutlierMetricDiagnostics(
      q1: bounds.q1,
      q3: bounds.q3,
      iqr: bounds.iqr,
      lowerFence: bounds.lowerFence,
      upperFence: bounds.upperFence,
      outliersByRun: Map<String, double>.unmodifiable(outliersByRun),
    );
  }

  String? primarySuspectRunId;
  var primarySuspectMetricCount = 0;
  for (final run in runs) {
    final metricCount = runOutlierCounts[run.runId]!;
    if (metricCount > primarySuspectMetricCount) {
      primarySuspectMetricCount = metricCount;
      primarySuspectRunId = run.runId;
    }
  }

  return _OutlierDiagnostics(
    metrics: Map<String, _OutlierMetricDiagnostics>.unmodifiable(metrics),
    runOutlierCounts: Map<String, int>.unmodifiable(runOutlierCounts),
    primarySuspectRunId: primarySuspectMetricCount > 0
        ? primarySuspectRunId
        : null,
    primarySuspectMetricCount: primarySuspectMetricCount,
  );
}

_SingleRunAnomalyDiagnostics? _computeSingleRunAnomalyDiagnostics({
  required List<_RunMetrics> runs,
  required _OutlierDiagnostics outlierDiagnostics,
  required double originalJankCvPercent,
  required double maxJankCvPercent,
  required double targetJankCvPercent,
}) {
  final suspectRunId = outlierDiagnostics.primarySuspectRunId;
  if (suspectRunId == null) {
    return null;
  }
  if (outlierDiagnostics.primarySuspectMetricCount <= 0) {
    return null;
  }

  final filteredRuns = runs
      .where((run) => run.runId != suspectRunId)
      .toList(growable: false);
  if (filteredRuns.length < 2) {
    return null;
  }

  final jankCvWithoutSuspect = _computeStats(
    filteredRuns.map((run) => run.metrics['jank_percent']!).toList(),
  ).cvPercent;
  final jankCvReduction = originalJankCvPercent - jankCvWithoutSuspect;
  final passWithoutSuspect = jankCvWithoutSuspect <= maxJankCvPercent;
  final passWithoutSuspectForTarget =
      jankCvWithoutSuspect <= targetJankCvPercent;
  final singleRunDominated =
      originalJankCvPercent > maxJankCvPercent && passWithoutSuspect;
  final singleRunDominatedForTarget =
      originalJankCvPercent > targetJankCvPercent &&
      passWithoutSuspectForTarget;

  return _SingleRunAnomalyDiagnostics(
    suspectRunId: suspectRunId,
    suspectOutlierMetricCount: outlierDiagnostics.primarySuspectMetricCount,
    totalRuns: runs.length,
    runsWithoutSuspect: filteredRuns.length,
    originalJankCvPercent: originalJankCvPercent,
    jankCvWithoutSuspectPercent: jankCvWithoutSuspect,
    jankCvReductionPercentPoints: jankCvReduction,
    maxJankCvPercent: maxJankCvPercent,
    targetJankCvPercent: targetJankCvPercent,
    passWithoutSuspect: passWithoutSuspect,
    passWithoutSuspectForTarget: passWithoutSuspectForTarget,
    singleRunDominated: singleRunDominated,
    singleRunDominatedForTarget: singleRunDominatedForTarget,
  );
}

_IqrBounds _computeIqrBounds(List<double> values) {
  if (values.isEmpty) {
    throw StateError('Cannot compute IQR bounds for empty values.');
  }

  final sorted = values.toList()..sort();
  final q1 = _percentile(sorted, 0.25);
  final q3 = _percentile(sorted, 0.75);
  final iqr = q3 - q1;
  return _IqrBounds(
    q1: q1,
    q3: q3,
    iqr: iqr,
    lowerFence: q1 - (1.5 * iqr),
    upperFence: q3 + (1.5 * iqr),
  );
}

double _percentile(List<double> sortedValues, double fraction) {
  if (sortedValues.isEmpty) {
    throw StateError('Cannot compute percentile for empty values.');
  }
  if (fraction <= 0) {
    return sortedValues.first;
  }
  if (fraction >= 1) {
    return sortedValues.last;
  }
  if (sortedValues.length == 1) {
    return sortedValues.single;
  }

  final rawIndex = (sortedValues.length - 1) * fraction;
  final lowerIndex = rawIndex.floor();
  final upperIndex = rawIndex.ceil();
  if (lowerIndex == upperIndex) {
    return sortedValues[lowerIndex];
  }
  final weight = rawIndex - lowerIndex;
  final lower = sortedValues[lowerIndex];
  final upper = sortedValues[upperIndex];
  return lower + ((upper - lower) * weight);
}

void _ensureParentDir(String path) {
  File(path).absolute.parent.createSync(recursive: true);
}

String _formatDefines(Map<String, String> defines) {
  final entries = defines.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries.map((entry) => '${entry.key}=${entry.value}').join(', ');
}

String _fmt(double? value) => _fmtNum(value ?? 0, 3);

String _fmtNum(double value, int decimals) => value.toStringAsFixed(decimals);

String _dateStamp(DateTime utc) {
  final year = utc.year.toString().padLeft(4, '0');
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '$year$month$day';
}

String _normalizeScrollPattern(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'forward') return 'forward';
  if (normalized == 'ping_pong' ||
      normalized == 'pingpong' ||
      normalized == 'ping-pong') {
    return 'ping_pong';
  }
  throw ArgumentError(
    'Invalid --scroll-pattern value. Use forward or ping_pong.',
  );
}

String _normalizeScrollInputMode(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'drag') return 'drag';
  if (normalized == 'jump') return 'jump';
  throw ArgumentError(
    'Invalid --scroll-input-mode value. Use drag or jump.',
  );
}

String _normalizeScrollJumpProfile(String raw) {
  final normalized = raw.trim().toLowerCase();
  if (normalized == 'relative') return 'relative';
  if (normalized == 'edge_bounce' ||
      normalized == 'edge-bounce' ||
      normalized == 'edgebounce' ||
      normalized == 'bounce') {
    return 'edge_bounce';
  }
  throw ArgumentError(
    'Invalid --scroll-jump-profile value. Use relative or edge_bounce.',
  );
}

double _percentOfBase(double value, double base) {
  final denominator = base.abs() < 0.000001 ? 1.0 : base.abs();
  return (value / denominator) * 100;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map) {
    return value.map(
      (key, entryValue) => MapEntry(key.toString(), entryValue),
    );
  }
  return null;
}

List<Object?> _asList(Object? value) {
  if (value is List) {
    return List<Object?>.from(value);
  }
  return const <Object?>[];
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

String _varianceTier(double cvPercent) {
  if (cvPercent >= 30) return 'alta';
  if (cvPercent >= 10) return 'media';
  return 'baja';
}

class _RunIdParser {
  String? runId;
  String _carry = '';

  static final RegExp _pattern = RegExp(r'Benchmark run id:\s*([0-9_]+Z)');

  void consume(String chunk) {
    final merged = '$_carry$chunk';
    final parts = merged.split('\n');
    _carry = parts.removeLast();
    for (final line in parts) {
      _scanLine(line);
    }
  }

  void close() {
    if (_carry.isNotEmpty) {
      _scanLine(_carry);
      _carry = '';
    }
  }

  void _scanLine(String line) {
    final match = _pattern.firstMatch(line);
    if (match != null) {
      runId = match.group(1);
    }
  }
}
