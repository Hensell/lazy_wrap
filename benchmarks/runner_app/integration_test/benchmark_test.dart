import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lazy_wrap/lazy_wrap.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap_sliver_v3.dart';

const _chipBatchSizeRaw = String.fromEnvironment(
  'OFFSTAGE_CHIP_BATCH_SIZE',
  defaultValue: '',
);
const _chipMeasureBatchSizeRaw = String.fromEnvironment(
  'OFFSTAGE_CHIP_MEASURE_BATCH_SIZE',
  defaultValue: '',
);
const _chipLoadThresholdRaw = String.fromEnvironment(
  'OFFSTAGE_CHIP_LOAD_THRESHOLD',
  defaultValue: '',
);
const _chipCacheExtentRaw = String.fromEnvironment(
  'OFFSTAGE_CHIP_CACHE_EXTENT',
  defaultValue: '',
);
const _cardBatchSizeRaw = String.fromEnvironment(
  'OFFSTAGE_CARD_BATCH_SIZE',
  defaultValue: '',
);
const _cardMeasureBatchSizeRaw = String.fromEnvironment(
  'OFFSTAGE_CARD_MEASURE_BATCH_SIZE',
  defaultValue: '',
);
const _cardLoadThresholdRaw = String.fromEnvironment(
  'OFFSTAGE_CARD_LOAD_THRESHOLD',
  defaultValue: '',
);
const _cardCacheExtentRaw = String.fromEnvironment(
  'OFFSTAGE_CARD_CACHE_EXTENT',
  defaultValue: '',
);
const _scrollStepsRaw = String.fromEnvironment(
  'BENCH_SCROLL_STEPS',
  defaultValue: '',
);
const _scrollStepPxRaw = String.fromEnvironment(
  'BENCH_SCROLL_STEP_PX',
  defaultValue: '',
);
const _scrollSettleFramesRaw = String.fromEnvironment(
  'BENCH_SCROLL_SETTLE_FRAMES',
  defaultValue: '',
);
const _scrollPumpFrameMsRaw = String.fromEnvironment(
  'BENCH_SCROLL_PUMP_FRAME_MS',
  defaultValue: '',
);
const _preMeasureScrollStepsRaw = String.fromEnvironment(
  'BENCH_PRE_MEASURE_SCROLL_STEPS',
  defaultValue: '',
);
const _scrollPatternRaw = String.fromEnvironment(
  'BENCH_SCROLL_PATTERN',
  defaultValue: 'forward',
);
const _scrollPatternSegmentStepsRaw = String.fromEnvironment(
  'BENCH_SCROLL_PATTERN_SEGMENT_STEPS',
  defaultValue: '',
);
const _measuredScrollSegmentsRaw = String.fromEnvironment(
  'BENCH_MEASURED_SCROLL_SEGMENTS',
  defaultValue: '',
);
const _scrollInputModeRaw = String.fromEnvironment(
  'BENCH_SCROLL_INPUT_MODE',
  defaultValue: 'drag',
);
const _scrollJumpProfileRaw = String.fromEnvironment(
  'BENCH_SCROLL_JUMP_PROFILE',
  defaultValue: 'relative',
);
const _autoPreMeasureEdgeBounce = bool.fromEnvironment(
  'BENCH_AUTO_PRE_MEASURE_EDGE_BOUNCE',
  defaultValue: true,
);
const _edgeBounceAutoPreMeasureSteps = int.fromEnvironment(
  'BENCH_EDGE_BOUNCE_AUTO_PRE_MEASURE_STEPS',
  defaultValue: 24,
);

int _itemBuildCalls = 0;
int _visibleItemBuildCalls = 0;
int _offstageItemBuildCalls = 0;
int _maxBuiltIndex = -1;
int _maxVisibleBuiltIndex = -1;
int _maxOffstageBuiltIndex = -1;
final Set<int> _builtIndices = <int>{};
final Set<int> _visibleBuiltIndices = <int>{};
final Set<int> _offstageBuiltIndices = <int>{};

void _resetBuildCounters() {
  _itemBuildCalls = 0;
  _visibleItemBuildCalls = 0;
  _offstageItemBuildCalls = 0;
  _maxBuiltIndex = -1;
  _maxVisibleBuiltIndex = -1;
  _maxOffstageBuiltIndex = -1;
  _builtIndices.clear();
  _visibleBuiltIndices.clear();
  _offstageBuiltIndices.clear();
}

void _recordItemBuild({required int index, required bool isOffstageBuild}) {
  _itemBuildCalls++;
  _builtIndices.add(index);
  if (isOffstageBuild) {
    _offstageItemBuildCalls++;
    _offstageBuiltIndices.add(index);
    if (index > _maxOffstageBuiltIndex) {
      _maxOffstageBuiltIndex = index;
    }
  } else {
    _visibleItemBuildCalls++;
    _visibleBuiltIndices.add(index);
    if (index > _maxVisibleBuiltIndex) {
      _maxVisibleBuiltIndex = index;
    }
  }
  if (index > _maxBuiltIndex) {
    _maxBuiltIndex = index;
  }
}

Widget _trackItemBuild({required int index, required Widget child}) {
  return Builder(
    builder: (context) {
      final offstageAncestor = context
          .findAncestorWidgetOfExactType<Offstage>();
      final isOffstageBuild = offstageAncestor?.offstage ?? false;
      _recordItemBuild(index: index, isOffstageBuild: isOffstageBuild);
      return child;
    },
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('run lazy_wrap benchmark scenario', (tester) async {
    const scenarioName = String.fromEnvironment(
      'SCENARIO',
      defaultValue: 'dynamic_chip_10k',
    );
    final frameBudgetMs = double.parse(
      const String.fromEnvironment('FRAME_BUDGET_MS', defaultValue: '16.67'),
    );

    final scenario = _BenchmarkScenario.fromName(scenarioName);
    final metrics = await _runScenario(
      tester: tester,
      scenario: scenario,
      frameBudgetMs: frameBudgetMs,
    );

    binding.reportData = metrics;
  });
}

class _BenchmarkScenario {
  const _BenchmarkScenario({required this.name, required this.builder});

  final String name;
  final Widget Function() builder;

  static _BenchmarkScenario fromName(String name) {
    switch (name) {
      case 'dynamic_chip_10k':
        return _BenchmarkScenario(
          name: name,
          builder: _buildDynamicChipScenario,
        );
      case 'dynamic_card_50k':
        return _BenchmarkScenario(
          name: name,
          builder: _buildDynamicCardScenario,
        );
      case 'fixed_grid_10k':
        return _BenchmarkScenario(name: name, builder: _buildFixedGridScenario);
      case 'dynamic_card_50k_sliver_v2':
        return _BenchmarkScenario(
          name: name,
          builder: _buildDynamicCardScenarioSliverV2,
        );
      case 'dynamic_card_50k_sliver_v3':
        return _BenchmarkScenario(
          name: name,
          builder: _buildDynamicCardScenarioSliverV3,
        );
      case 'dynamic_chip_10k_sliver_v2':
        return _BenchmarkScenario(
          name: name,
          builder: _buildDynamicChipScenarioSliverV2,
        );
      case 'dynamic_chip_10k_sliver_v3':
        return _BenchmarkScenario(
          name: name,
          builder: _buildDynamicChipScenarioSliverV3,
        );
      case 'chip_compare_lazy_wrap_2k':
        return _BenchmarkScenario(
          name: name,
          builder: _buildChipCompareLazyWrap2kScenario,
        );
      case 'chip_compare_listview_2k':
        return _BenchmarkScenario(
          name: name,
          builder: _buildChipCompareListView2kScenario,
        );
      case 'chip_compare_wrap_2k':
        return _BenchmarkScenario(
          name: name,
          builder: _buildChipCompareWrap2kScenario,
        );
      default:
        throw ArgumentError.value(
          name,
          'SCENARIO',
          'Unknown scenario. Use dynamic_chip_10k, dynamic_card_50k, '
              'fixed_grid_10k, dynamic_card_50k_sliver_v2, '
              'dynamic_card_50k_sliver_v3, dynamic_chip_10k_sliver_v2 or '
              'dynamic_chip_10k_sliver_v3, chip_compare_lazy_wrap_2k, '
              'chip_compare_listview_2k or chip_compare_wrap_2k.',
        );
    }
  }
}

enum _ScrollPattern { forward, pingPong }

enum _ScrollInputMode { drag, jump }

enum _ScrollJumpProfile { relative, edgeBounce }

enum _FrameTimingPhase { warmup, measuredScroll, settle }

class _ScrollProfile {
  const _ScrollProfile({
    required this.pattern,
    required this.inputMode,
    required this.jumpProfile,
    required this.patternSegmentSteps,
    required this.scrollSteps,
    required this.scrollStepPx,
    required this.preMeasureScrollSteps,
    required this.settleFrames,
    required this.pumpFrameMs,
  });

  final _ScrollPattern pattern;
  final _ScrollInputMode inputMode;
  final _ScrollJumpProfile jumpProfile;
  final int patternSegmentSteps;
  final int scrollSteps;
  final double scrollStepPx;
  final int preMeasureScrollSteps;
  final int settleFrames;
  final int pumpFrameMs;

  static _ScrollProfile fromEnvironment() {
    final normalizedPattern = _scrollPatternRaw.trim().toLowerCase();
    final pattern = switch (normalizedPattern) {
      'ping_pong' || 'pingpong' || 'ping-pong' => _ScrollPattern.pingPong,
      _ => _ScrollPattern.forward,
    };
    final normalizedInputMode = _scrollInputModeRaw.trim().toLowerCase();
    final inputMode = switch (normalizedInputMode) {
      'jump' => _ScrollInputMode.jump,
      _ => _ScrollInputMode.drag,
    };
    final normalizedJumpProfile = _scrollJumpProfileRaw.trim().toLowerCase();
    final jumpProfile = switch (normalizedJumpProfile) {
      'edge_bounce' ||
      'edgebounce' ||
      'bounce' => _ScrollJumpProfile.edgeBounce,
      _ => _ScrollJumpProfile.relative,
    };
    final defaultPreMeasureSteps =
        _autoPreMeasureEdgeBounce &&
            inputMode == _ScrollInputMode.jump &&
            jumpProfile == _ScrollJumpProfile.edgeBounce
        ? _edgeBounceAutoPreMeasureSteps
        : 0;
    return _ScrollProfile(
      pattern: pattern,
      inputMode: inputMode,
      jumpProfile: jumpProfile,
      patternSegmentSteps: _parsePositiveInt(
        _scrollPatternSegmentStepsRaw,
        fallback: 12,
      ),
      scrollSteps: _parsePositiveInt(_scrollStepsRaw, fallback: 90),
      scrollStepPx: _parseNonZeroDouble(_scrollStepPxRaw, fallback: -320),
      preMeasureScrollSteps: _parseNonNegativeInt(
        _preMeasureScrollStepsRaw,
        fallback: defaultPreMeasureSteps,
      ),
      settleFrames: _parseNonNegativeInt(_scrollSettleFramesRaw, fallback: 120),
      pumpFrameMs: _parsePositiveInt(_scrollPumpFrameMsRaw, fallback: 16),
    );
  }

  String get patternLabel => switch (pattern) {
    _ScrollPattern.forward => 'forward',
    _ScrollPattern.pingPong => 'ping_pong',
  };

  String get inputModeLabel => switch (inputMode) {
    _ScrollInputMode.drag => 'drag',
    _ScrollInputMode.jump => 'jump',
  };

  String get jumpProfileLabel => switch (jumpProfile) {
    _ScrollJumpProfile.relative => 'relative',
    _ScrollJumpProfile.edgeBounce => 'edge_bounce',
  };
}

class _FrameSample {
  const _FrameSample({
    required this.index,
    required this.phase,
    required this.measuredSegmentIndex,
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
  });

  final int index;
  final _FrameTimingPhase phase;
  final int measuredSegmentIndex;
  final double buildMs;
  final double rasterMs;
  final double totalMs;
}

class _FramePhaseDiagnostics {
  const _FramePhaseDiagnostics({
    required this.sampleCount,
    required this.jankOverBudget,
    required this.jankOver2x,
    required this.jankOver3x,
    required this.p95TotalMs,
    required this.p99TotalMs,
    required this.maxTotalMs,
  });

  final int sampleCount;
  final int jankOverBudget;
  final int jankOver2x;
  final int jankOver3x;
  final double p95TotalMs;
  final double p99TotalMs;
  final double maxTotalMs;

  Map<String, Object> toJson() => <String, Object>{
    'sample_count': sampleCount,
    'jank_frames_over_budget': jankOverBudget,
    'jank_frames_over_2x_budget': jankOver2x,
    'jank_frames_over_3x_budget': jankOver3x,
    'p95_total_ms': p95TotalMs,
    'p99_total_ms': p99TotalMs,
    'max_total_ms': maxTotalMs,
  };
}

class _MeasuredSegmentDiagnostics {
  const _MeasuredSegmentDiagnostics({
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
    'p95_total_ms': p95TotalMs,
    'max_total_ms': maxTotalMs,
  };
}

class _FrameSpike {
  const _FrameSpike({
    required this.sampleIndex,
    required this.phase,
    required this.totalMs,
    required this.buildMs,
    required this.rasterMs,
  });

  final int sampleIndex;
  final _FrameTimingPhase phase;
  final double totalMs;
  final double buildMs;
  final double rasterMs;

  Map<String, Object> toJson() => <String, Object>{
    'sample_index': sampleIndex,
    'phase': _framePhaseLabel(phase),
    'total_ms': totalMs,
    'build_ms': buildMs,
    'raster_ms': rasterMs,
  };
}

class _FrameDiagnostics {
  const _FrameDiagnostics({
    required this.sampleCount,
    required this.frameBudgetMs,
    required this.jankOverBudget,
    required this.jankOver2x,
    required this.jankOver3x,
    required this.p95TotalMs,
    required this.p99TotalMs,
    required this.maxTotalMs,
    required this.maxBuildMs,
    required this.maxRasterMs,
    required this.topSpikes,
    required this.phases,
    required this.measuredSegments,
  });

  final int sampleCount;
  final double frameBudgetMs;
  final int jankOverBudget;
  final int jankOver2x;
  final int jankOver3x;
  final double p95TotalMs;
  final double p99TotalMs;
  final double maxTotalMs;
  final double maxBuildMs;
  final double maxRasterMs;
  final List<_FrameSpike> topSpikes;
  final Map<String, _FramePhaseDiagnostics> phases;
  final List<_MeasuredSegmentDiagnostics> measuredSegments;

  Map<String, Object> toJson() => <String, Object>{
    'sample_count': sampleCount,
    'frame_budget_ms': frameBudgetMs,
    'jank_frames_over_budget': jankOverBudget,
    'jank_frames_over_2x_budget': jankOver2x,
    'jank_frames_over_3x_budget': jankOver3x,
    'p95_total_ms': p95TotalMs,
    'p99_total_ms': p99TotalMs,
    'max_total_ms': maxTotalMs,
    'max_build_ms': maxBuildMs,
    'max_raster_ms': maxRasterMs,
    'top_spikes': topSpikes.map((entry) => entry.toJson()).toList(),
    'phases': {
      for (final entry in phases.entries) entry.key: entry.value.toJson(),
    },
    'measured_segments': measuredSegments
        .map((entry) => entry.toJson())
        .toList(),
  };
}

String _framePhaseLabel(_FrameTimingPhase phase) => switch (phase) {
  _FrameTimingPhase.warmup => 'warmup',
  _FrameTimingPhase.measuredScroll => 'measured_scroll',
  _FrameTimingPhase.settle => 'settle',
};

_FramePhaseDiagnostics _buildFramePhaseDiagnostics({
  required List<_FrameSample> samples,
  required double frameBudgetMs,
}) {
  if (samples.isEmpty) {
    return const _FramePhaseDiagnostics(
      sampleCount: 0,
      jankOverBudget: 0,
      jankOver2x: 0,
      jankOver3x: 0,
      p95TotalMs: 0,
      p99TotalMs: 0,
      maxTotalMs: 0,
    );
  }

  final totals = samples.map((entry) => entry.totalMs).toList();
  final jankOverBudget = totals.where((value) => value > frameBudgetMs).length;
  final jankOver2x = totals
      .where((value) => value > (frameBudgetMs * 2))
      .length;
  final jankOver3x = totals
      .where((value) => value > (frameBudgetMs * 3))
      .length;

  return _FramePhaseDiagnostics(
    sampleCount: samples.length,
    jankOverBudget: jankOverBudget,
    jankOver2x: jankOver2x,
    jankOver3x: jankOver3x,
    p95TotalMs: _percentile(totals, 0.95),
    p99TotalMs: _percentile(totals, 0.99),
    maxTotalMs: totals.reduce((a, b) => a > b ? a : b),
  );
}

_FrameDiagnostics _buildFrameDiagnostics({
  required List<_FrameSample> samples,
  required double frameBudgetMs,
  required int measuredScrollSteps,
  required int measuredSegmentCount,
}) {
  final totals = samples.map((entry) => entry.totalMs).toList();
  final builds = samples.map((entry) => entry.buildMs).toList();
  final rasters = samples.map((entry) => entry.rasterMs).toList();

  final byPhase = <_FrameTimingPhase, List<_FrameSample>>{
    for (final phase in _FrameTimingPhase.values) phase: <_FrameSample>[],
  };
  for (final sample in samples) {
    byPhase[sample.phase]!.add(sample);
  }

  final topSpikes = [...samples]
    ..sort((a, b) => b.totalMs.compareTo(a.totalMs));

  final normalizedSegmentCount = measuredSegmentCount <= 0
      ? 0
      : (measuredSegmentCount > measuredScrollSteps
            ? measuredScrollSteps
            : measuredSegmentCount);
  final measuredSamples = byPhase[_FrameTimingPhase.measuredScroll]!;
  final measuredSegments = <_MeasuredSegmentDiagnostics>[];
  for (
    var segmentIndex = 0;
    segmentIndex < normalizedSegmentCount;
    segmentIndex++
  ) {
    final stepStart =
        (segmentIndex * measuredScrollSteps) ~/ normalizedSegmentCount;
    final stepEndExclusive =
        ((segmentIndex + 1) * measuredScrollSteps) ~/ normalizedSegmentCount;
    final segmentSamples = measuredSamples
        .where((sample) => sample.measuredSegmentIndex == segmentIndex)
        .toList(growable: false);
    final segmentTotals = segmentSamples
        .map((entry) => entry.totalMs)
        .toList(growable: false);
    measuredSegments.add(
      _MeasuredSegmentDiagnostics(
        segmentIndex: segmentIndex,
        stepStart: stepStart,
        stepEndExclusive: stepEndExclusive,
        sampleCount: segmentSamples.length,
        jankOverBudget: segmentTotals
            .where((value) => value > frameBudgetMs)
            .length,
        jankOver2x: segmentTotals
            .where((value) => value > (frameBudgetMs * 2))
            .length,
        p95TotalMs: segmentTotals.isEmpty
            ? 0
            : _percentile(segmentTotals, 0.95),
        maxTotalMs: segmentTotals.isEmpty
            ? 0
            : segmentTotals.reduce((a, b) => a > b ? a : b),
      ),
    );
  }

  return _FrameDiagnostics(
    sampleCount: samples.length,
    frameBudgetMs: frameBudgetMs,
    jankOverBudget: totals.where((value) => value > frameBudgetMs).length,
    jankOver2x: totals.where((value) => value > (frameBudgetMs * 2)).length,
    jankOver3x: totals.where((value) => value > (frameBudgetMs * 3)).length,
    p95TotalMs: _percentile(totals, 0.95),
    p99TotalMs: _percentile(totals, 0.99),
    maxTotalMs: totals.isEmpty ? 0 : totals.reduce((a, b) => a > b ? a : b),
    maxBuildMs: builds.isEmpty ? 0 : builds.reduce((a, b) => a > b ? a : b),
    maxRasterMs: rasters.isEmpty ? 0 : rasters.reduce((a, b) => a > b ? a : b),
    topSpikes: topSpikes
        .take(5)
        .map(
          (sample) => _FrameSpike(
            sampleIndex: sample.index,
            phase: sample.phase,
            totalMs: sample.totalMs,
            buildMs: sample.buildMs,
            rasterMs: sample.rasterMs,
          ),
        )
        .toList(growable: false),
    phases: <String, _FramePhaseDiagnostics>{
      'measured_scroll': _buildFramePhaseDiagnostics(
        samples: byPhase[_FrameTimingPhase.measuredScroll]!,
        frameBudgetMs: frameBudgetMs,
      ),
      'settle': _buildFramePhaseDiagnostics(
        samples: byPhase[_FrameTimingPhase.settle]!,
        frameBudgetMs: frameBudgetMs,
      ),
    },
    measuredSegments: measuredSegments,
  );
}

Future<Map<String, Object>> _runScenario({
  required WidgetTester tester,
  required _BenchmarkScenario scenario,
  required double frameBudgetMs,
}) async {
  _resetBuildCounters();

  final binding = WidgetsBinding.instance;
  final buildSamplesMs = <double>[];
  final rasterSamplesMs = <double>[];
  final totalSamplesMs = <double>[];
  final frameSamples = <_FrameSample>[];
  var frameSampleIndex = 0;
  var timingPhase = _FrameTimingPhase.warmup;
  var measuredSegmentIndex = -1;

  void onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final buildMs = _toMs(timing.buildDuration);
      final rasterMs = _toMs(timing.rasterDuration);
      final totalMs = _toMs(timing.totalSpan);
      buildSamplesMs.add(buildMs);
      rasterSamplesMs.add(rasterMs);
      totalSamplesMs.add(totalMs);
      frameSamples.add(
        _FrameSample(
          index: frameSampleIndex++,
          phase: timingPhase,
          measuredSegmentIndex: measuredSegmentIndex,
          buildMs: buildMs,
          rasterMs: rasterMs,
          totalMs: totalMs,
        ),
      );
    }
  }

  binding.addTimingsCallback(onTimings);

  var peakMemoryBytes = ProcessInfo.currentRss;
  final memorySampler = Timer.periodic(const Duration(milliseconds: 40), (_) {
    final currentRss = ProcessInfo.currentRss;
    if (currentRss > peakMemoryBytes) {
      peakMemoryBytes = currentRss;
    }
  });

  final ttiStopwatch = Stopwatch()..start();
  await tester.pumpWidget(scenario.builder());

  // Warm up until scrollable exists and first frame timings are collected.
  var reachedInteraction = false;
  var ttiMs = 0.0;
  for (var i = 0; i < 240; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final hasScrollable = find.byType(Scrollable).evaluate().isNotEmpty;
    if (hasScrollable && totalSamplesMs.isNotEmpty) {
      ttiMs = ttiStopwatch.elapsedMicroseconds / 1000;
      reachedInteraction = true;
      break;
    }
  }

  if (!reachedInteraction) {
    memorySampler.cancel();
    binding.removeTimingsCallback(onTimings);
    throw TestFailure(
      'Scenario ${scenario.name} did not become interactive in warmup.',
    );
  }

  buildSamplesMs.clear();
  rasterSamplesMs.clear();
  totalSamplesMs.clear();
  frameSamples.clear();
  frameSampleIndex = 0;

  final scrollable = find.byType(Scrollable).first;
  final scrollProfile = _ScrollProfile.fromEnvironment();
  final measuredSegmentCount = _parsePositiveInt(
    _measuredScrollSegmentsRaw,
    fallback: 3,
  ).clamp(1, scrollProfile.scrollSteps).toInt();

  await _resetScrollToTop(
    tester: tester,
    scrollable: scrollable,
    frameDuration: Duration(milliseconds: scrollProfile.pumpFrameMs),
  );

  var preMeasureDiagnostics = _ScrollRunDiagnostics.empty();
  if (scrollProfile.preMeasureScrollSteps > 0) {
    timingPhase = _FrameTimingPhase.warmup;
    preMeasureDiagnostics = await _runScriptedScrollPattern(
      tester: tester,
      scrollable: scrollable,
      profile: scrollProfile,
      steps: scrollProfile.preMeasureScrollSteps,
    );
    await _pumpFrames(
      tester: tester,
      frameDuration: Duration(milliseconds: scrollProfile.pumpFrameMs),
      frameCount: 12,
    );

    // Keep warm-up dynamics out of measured frame samples.
    buildSamplesMs.clear();
    rasterSamplesMs.clear();
    totalSamplesMs.clear();
    frameSamples.clear();
    frameSampleIndex = 0;
  }

  timingPhase = _FrameTimingPhase.measuredScroll;
  final measuredScrollDiagnostics = await _runScriptedScrollPattern(
    tester: tester,
    scrollable: scrollable,
    profile: scrollProfile,
    steps: scrollProfile.scrollSteps,
    onBeforeStep: (stepIndex) {
      measuredSegmentIndex = _resolveMeasuredSegmentIndex(
        stepIndex: stepIndex,
        totalSteps: scrollProfile.scrollSteps,
        segmentCount: measuredSegmentCount,
      );
    },
  );

  // Extra frames to flush deferred work.
  measuredSegmentIndex = -1;
  timingPhase = _FrameTimingPhase.settle;
  await _pumpFrames(
    tester: tester,
    frameDuration: Duration(milliseconds: scrollProfile.pumpFrameMs),
    frameCount: scrollProfile.settleFrames,
  );

  final exception = tester.takeException();
  if (exception != null) {
    memorySampler.cancel();
    binding.removeTimingsCallback(onTimings);
    throw TestFailure('Scenario ${scenario.name} threw: $exception');
  }

  memorySampler.cancel();
  binding.removeTimingsCallback(onTimings);
  timingPhase = _FrameTimingPhase.warmup;

  final jankFrames = totalSamplesMs.where((ms) => ms > frameBudgetMs).length;
  final jankPercent = totalSamplesMs.isEmpty
      ? 0.0
      : (jankFrames / totalSamplesMs.length) * 100;
  final frameDiagnostics = _buildFrameDiagnostics(
    samples: frameSamples,
    frameBudgetMs: frameBudgetMs,
    measuredScrollSteps: scrollProfile.scrollSteps,
    measuredSegmentCount: measuredSegmentCount,
  );
  final uniqueBuiltIndexCount = _builtIndices.length;
  final uniqueVisibleBuiltIndexCount = _visibleBuiltIndices.length;
  final uniqueOffstageBuiltIndexCount = _offstageBuiltIndices.length;

  return <String, Object>{
    'scenario': scenario.name,
    'frame_count': totalSamplesMs.length,
    'frame_budget_ms': frameBudgetMs,
    'p95_build_ms': _percentile(buildSamplesMs, 0.95),
    'p95_raster_ms': _percentile(rasterSamplesMs, 0.95),
    'jank_percent': jankPercent,
    'peak_memory_mb': peakMemoryBytes / (1024 * 1024),
    'time_to_first_interaction_ms': ttiMs,
    'item_build_calls': _itemBuildCalls,
    'visible_item_build_calls': _visibleItemBuildCalls,
    'offstage_item_build_calls': _offstageItemBuildCalls,
    'unique_built_indices': uniqueBuiltIndexCount,
    'unique_visible_built_indices': uniqueVisibleBuiltIndexCount,
    'unique_offstage_built_indices': uniqueOffstageBuiltIndexCount,
    'builds_per_unique_index': _safeRatio(
      _itemBuildCalls,
      uniqueBuiltIndexCount,
    ),
    'visible_builds_per_unique_index': _safeRatio(
      _visibleItemBuildCalls,
      uniqueVisibleBuiltIndexCount,
    ),
    'offstage_builds_per_unique_index': _safeRatio(
      _offstageItemBuildCalls,
      uniqueOffstageBuiltIndexCount,
    ),
    'max_built_index': _maxBuiltIndex,
    'max_visible_built_index': _maxVisibleBuiltIndex,
    'max_offstage_built_index': _maxOffstageBuiltIndex,
    'scroll_profile': <String, Object>{
      'pattern': scrollProfile.patternLabel,
      'input_mode': scrollProfile.inputModeLabel,
      'jump_profile': scrollProfile.jumpProfileLabel,
      'pattern_segment_steps': scrollProfile.patternSegmentSteps,
      'measured_scroll_segments': measuredSegmentCount,
      'scroll_steps': scrollProfile.scrollSteps,
      'scroll_step_px': scrollProfile.scrollStepPx,
      'pre_measure_scroll_steps': scrollProfile.preMeasureScrollSteps,
      'settle_frames': scrollProfile.settleFrames,
      'pump_frame_ms': scrollProfile.pumpFrameMs,
    },
    'scroll_diagnostics': <String, Object>{
      'pre_measure': preMeasureDiagnostics.toJson(),
      'measured': measuredScrollDiagnostics.toJson(),
    },
    'frame_diagnostics': frameDiagnostics.toJson(),
  };
}

Widget _buildDynamicChipScenario() {
  return _buildDynamicChipScenarioWithCount(itemCount: 10000);
}

Widget _buildChipCompareLazyWrap2kScenario() {
  return _buildDynamicChipScenarioWithCount(itemCount: 2000);
}

Widget _buildDynamicChipScenarioWithCount({required int itemCount}) {
  final batchSize = _parsePositiveInt(_chipBatchSizeRaw, fallback: 64);
  final measureBatchSize = _parsePositiveInt(
    _chipMeasureBatchSizeRaw,
    fallback: 24,
  );
  final loadThreshold = _parseNonNegativeDouble(
    _chipLoadThresholdRaw,
    fallback: 300,
  );
  final cacheExtent = _parseNonNegativeDouble(
    _chipCacheExtentRaw,
    fallback: 300,
  );

  return MaterialApp(
    home: Scaffold(
      body: LazyWrap.dynamic(
        itemCount: itemCount,
        padding: const EdgeInsets.all(12),
        batchSize: batchSize,
        measureBatchSize: measureBatchSize,
        loadThreshold: loadThreshold,
        cacheExtent: cacheExtent,
        fadeInItems: false,
        loadingBuilder: (_) => const SizedBox.shrink(),
        itemBuilder: (context, index) =>
            _trackItemBuild(index: index, child: _buildChipItem(index)),
      ),
    ),
  );
}

Widget _buildChipCompareListView2kScenario() {
  return MaterialApp(
    home: Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 2000,
        itemBuilder: (context, index) => Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _trackItemBuild(index: index, child: _buildChipItem(index)),
          ),
        ),
      ),
    ),
  );
}

Widget _buildChipCompareWrap2kScenario() {
  final children = List<Widget>.generate(
    2000,
    (index) => _trackItemBuild(index: index, child: _buildChipItem(index)),
  );

  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children,
        ),
      ),
    ),
  );
}

Widget _buildDynamicCardScenario() {
  final batchSize = _parsePositiveInt(_cardBatchSizeRaw, fallback: 80);
  final measureBatchSize = _parsePositiveInt(
    _cardMeasureBatchSizeRaw,
    fallback: 20,
  );
  final loadThreshold = _parseNonNegativeDouble(
    _cardLoadThresholdRaw,
    fallback: 300,
  );
  final cacheExtent = _parseNonNegativeDouble(
    _cardCacheExtentRaw,
    fallback: 300,
  );

  return MaterialApp(
    home: Scaffold(
      body: LazyWrap.dynamic(
        itemCount: 50000,
        spacing: 10,
        runSpacing: 10,
        padding: const EdgeInsets.all(12),
        batchSize: batchSize,
        measureBatchSize: measureBatchSize,
        loadThreshold: loadThreshold,
        cacheExtent: cacheExtent,
        fadeInItems: false,
        loadingBuilder: (_) => const SizedBox.shrink(),
        itemBuilder: (context, index) {
          final width = 140.0 + ((index % 6) * 18);
          final height = 80.0 + ((index % 5) * 22);
          return _trackItemBuild(
            index: index,
            child: SizedBox(
              width: width,
              height: height,
              child: Card(
                elevation: 1,
                clipBehavior: Clip.antiAlias,
                child: Center(child: Text('Card $index')),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Widget _buildFixedGridScenario() {
  return MaterialApp(
    home: Scaffold(
      body: LazyWrap.fixed(
        itemCount: 10000,
        estimatedItemWidth: 140,
        estimatedItemHeight: 90,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) => _trackItemBuild(
          index: index,
          child: Card(elevation: 1, child: Center(child: Text('Fixed $index'))),
        ),
      ),
    ),
  );
}

Widget _buildDynamicCardScenarioSliverV2() {
  return MaterialApp(
    home: Scaffold(
      body: LazyWrap.dynamic(
        itemCount: 50000,
        engine: LazyWrapEngine.sliverV2,
        spacing: 10,
        runSpacing: 10,
        padding: const EdgeInsets.all(12),
        cacheExtent: 300,
        itemWidthBuilder: (index) => 140.0 + ((index % 6) * 18),
        itemHeightBuilder: (index) => 80.0 + ((index % 5) * 22),
        itemBuilder: (context, index) => _trackItemBuild(
          index: index,
          child: Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: Center(child: Text('Card $index')),
          ),
        ),
      ),
    ),
  );
}

Widget _buildDynamicChipScenarioSliverV2() {
  return MaterialApp(
    home: Scaffold(
      body: LazyWrap.dynamic(
        itemCount: 10000,
        engine: LazyWrapEngine.sliverV2,
        padding: const EdgeInsets.all(12),
        batchSize: 64,
        cacheExtent: 300,
        loadingBuilder: (_) => const SizedBox.shrink(),
        itemWidthBuilder: _chipWidthForIndex,
        itemHeightBuilder: _chipHeightForIndex,
        itemBuilder: (context, index) =>
            _trackItemBuild(index: index, child: _buildChipItem(index)),
      ),
    ),
  );
}

Widget _buildDynamicCardScenarioSliverV3() {
  final batchSize = _parsePositiveInt(_cardBatchSizeRaw, fallback: 80);
  final loadThreshold = _parseNonNegativeDouble(
    _cardLoadThresholdRaw,
    fallback: 300,
  );
  final cacheExtent = _parseNonNegativeDouble(
    _cardCacheExtentRaw,
    fallback: 300,
  );

  return MaterialApp(
    home: Scaffold(
      body: DynamicLazyWrapSliverV3(
        itemCount: 50000,
        spacing: 10,
        runSpacing: 10,
        padding: const EdgeInsets.all(12),
        cacheExtent: cacheExtent,
        batchSize: batchSize,
        loadThreshold: loadThreshold,
        itemWidthBuilder: (index) => 140.0 + ((index % 6) * 18),
        itemHeightBuilder: (index) => 80.0 + ((index % 5) * 22),
        itemBuilder: (context, index) => _trackItemBuild(
          index: index,
          child: Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: Center(child: Text('Card $index')),
          ),
        ),
      ),
    ),
  );
}

Widget _buildDynamicChipScenarioSliverV3() {
  return MaterialApp(
    home: Scaffold(
      body: DynamicLazyWrapSliverV3(
        itemCount: 10000,
        padding: const EdgeInsets.all(12),
        cacheExtent: 300,
        itemWidthBuilder: _chipWidthForIndex,
        itemHeightBuilder: _chipHeightForIndex,
        itemBuilder: (context, index) =>
            _trackItemBuild(index: index, child: _buildChipItem(index)),
      ),
    ),
  );
}

Widget _buildChipItem(int index) {
  final suffix = '.' * (index % 8);
  return Chip(
    label: Text('Chip $index$suffix'),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

double _chipWidthForIndex(int index) {
  final digits = index.toString().length;
  final suffixLength = index % 8;
  return 86 + (digits * 8) + (suffixLength * 7);
}

double _chipHeightForIndex(int index) => 36;

Future<void> _resetScrollToTop({
  required WidgetTester tester,
  required Finder scrollable,
  required Duration frameDuration,
}) async {
  try {
    final scrollableState = tester.state<ScrollableState>(scrollable);
    scrollableState.position.jumpTo(scrollableState.position.minScrollExtent);
    await tester.pump(frameDuration);
  } catch (_) {
    // Keep benchmark resilient if the scroll position is not ready yet.
  }
}

class _ScrollRunDiagnostics {
  _ScrollRunDiagnostics({
    required this.stepsRequested,
    required this.startPixels,
  }) : endPixels = startPixels,
       minVisitedPixels = startPixels,
       maxVisitedPixels = startPixels;

  final int stepsRequested;
  final double startPixels;
  int stepCount = 0;
  int effectiveSteps = 0;
  int noOpSteps = 0;
  int edgeHitsMin = 0;
  int edgeHitsMax = 0;
  double totalAbsoluteDeltaPx = 0;
  double endPixels;
  double minVisitedPixels;
  double maxVisitedPixels;

  factory _ScrollRunDiagnostics.empty() =>
      _ScrollRunDiagnostics(stepsRequested: 0, startPixels: 0);

  void recordStep({
    required double beforePixels,
    required double afterPixels,
    required double minScrollExtent,
    required double maxScrollExtent,
  }) {
    stepCount++;
    final delta = afterPixels - beforePixels;
    final absDelta = delta.abs();
    totalAbsoluteDeltaPx += absDelta;
    if (absDelta > _scrollEpsilonPx) {
      effectiveSteps++;
    } else {
      noOpSteps++;
    }
    if (_isNear(afterPixels, minScrollExtent)) {
      edgeHitsMin++;
    }
    if (_isNear(afterPixels, maxScrollExtent)) {
      edgeHitsMax++;
    }
    endPixels = afterPixels;
    if (afterPixels < minVisitedPixels) {
      minVisitedPixels = afterPixels;
    }
    if (afterPixels > maxVisitedPixels) {
      maxVisitedPixels = afterPixels;
    }
  }

  Map<String, Object> toJson() => <String, Object>{
    'steps_requested': stepsRequested,
    'steps_recorded': stepCount,
    'effective_steps': effectiveSteps,
    'no_op_steps': noOpSteps,
    'edge_hits_min': edgeHitsMin,
    'edge_hits_max': edgeHitsMax,
    'total_abs_delta_px': totalAbsoluteDeltaPx,
    'average_abs_delta_px': stepCount <= 0
        ? 0.0
        : totalAbsoluteDeltaPx / stepCount,
    'start_pixels': startPixels,
    'end_pixels': endPixels,
    'min_visited_pixels': minVisitedPixels,
    'max_visited_pixels': maxVisitedPixels,
  };
}

const _scrollEpsilonPx = 0.001;

bool _isNear(double a, double b) => (a - b).abs() <= _scrollEpsilonPx;

Future<_ScrollRunDiagnostics> _runScriptedScrollPattern({
  required WidgetTester tester,
  required Finder scrollable,
  required _ScrollProfile profile,
  required int steps,
  void Function(int stepIndex)? onBeforeStep,
}) async {
  final scrollableState = tester.state<ScrollableState>(scrollable);
  final position = scrollableState.position;
  final diagnostics = _ScrollRunDiagnostics(
    stepsRequested: steps,
    startPixels: position.pixels,
  );
  final frameDuration = Duration(milliseconds: profile.pumpFrameMs);

  if (steps <= 0) {
    return diagnostics;
  }

  if (profile.inputMode == _ScrollInputMode.jump) {
    var edgeBounceDirection = profile.scrollStepPx.isNegative ? 1.0 : -1.0;
    for (var i = 0; i < steps; i++) {
      onBeforeStep?.call(i);
      final beforePixels = position.pixels;
      final desiredDelta = profile.jumpProfile == _ScrollJumpProfile.edgeBounce
          ? (profile.scrollStepPx.abs() * edgeBounceDirection)
          : (-_scrollDyForStep(profile, i));

      var target = (position.pixels + desiredDelta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      if (profile.jumpProfile == _ScrollJumpProfile.edgeBounce) {
        final hitMin = _isNear(target, position.minScrollExtent);
        final hitMax = _isNear(target, position.maxScrollExtent);
        if (hitMin || hitMax) {
          edgeBounceDirection *= -1;
        }

        if (_isNear(target, position.pixels)) {
          final retryTarget =
              (position.pixels +
                      (profile.scrollStepPx.abs() * edgeBounceDirection))
                  .clamp(position.minScrollExtent, position.maxScrollExtent)
                  .toDouble();
          if (!_isNear(retryTarget, position.pixels)) {
            target = retryTarget;
          }
        }
      }

      position.jumpTo(target);
      await tester.pump(frameDuration);
      diagnostics.recordStep(
        beforePixels: beforePixels,
        afterPixels: position.pixels,
        minScrollExtent: position.minScrollExtent,
        maxScrollExtent: position.maxScrollExtent,
      );
    }
    return diagnostics;
  }

  for (var i = 0; i < steps; i++) {
    onBeforeStep?.call(i);
    final beforePixels = position.pixels;
    final dy = _scrollDyForStep(profile, i);
    await tester.drag(scrollable, Offset(0, dy));
    await tester.pump(frameDuration);
    diagnostics.recordStep(
      beforePixels: beforePixels,
      afterPixels: position.pixels,
      minScrollExtent: position.minScrollExtent,
      maxScrollExtent: position.maxScrollExtent,
    );
  }
  return diagnostics;
}

int _resolveMeasuredSegmentIndex({
  required int stepIndex,
  required int totalSteps,
  required int segmentCount,
}) {
  if (totalSteps <= 0 || segmentCount <= 1) {
    return 0;
  }
  final resolved = (stepIndex * segmentCount) ~/ totalSteps;
  if (resolved < 0) return 0;
  if (resolved >= segmentCount) return segmentCount - 1;
  return resolved;
}

double _scrollDyForStep(_ScrollProfile profile, int stepIndex) {
  if (profile.pattern == _ScrollPattern.forward) {
    return profile.scrollStepPx;
  }

  final direction = ((stepIndex ~/ profile.patternSegmentSteps) % 2 == 0)
      ? -1.0
      : 1.0;
  return profile.scrollStepPx.abs() * direction;
}

Future<void> _pumpFrames({
  required WidgetTester tester,
  required Duration frameDuration,
  required int frameCount,
}) async {
  for (var i = 0; i < frameCount; i++) {
    await tester.pump(frameDuration);
  }
}

double _toMs(Duration duration) => duration.inMicroseconds / 1000;

double _safeRatio(int numerator, int denominator) {
  if (denominator <= 0) return 0;
  return numerator / denominator;
}

int _parsePositiveInt(String rawValue, {required int fallback}) {
  final parsed = int.tryParse(rawValue);
  if (parsed == null || parsed <= 0) return fallback;
  return parsed;
}

int _parseNonNegativeInt(String rawValue, {required int fallback}) {
  final parsed = int.tryParse(rawValue);
  if (parsed == null || parsed < 0) return fallback;
  return parsed;
}

double _parseNonZeroDouble(String rawValue, {required double fallback}) {
  final parsed = double.tryParse(rawValue);
  if (parsed == null || parsed == 0) return fallback;
  return parsed;
}

double _parseNonNegativeDouble(String rawValue, {required double fallback}) {
  final parsed = double.tryParse(rawValue);
  if (parsed == null || parsed < 0) return fallback;
  return parsed;
}

double _percentile(List<double> values, double p) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final rawIndex = (sorted.length * p).ceil() - 1;
  final index = rawIndex.clamp(0, sorted.length - 1);
  return sorted[index];
}
