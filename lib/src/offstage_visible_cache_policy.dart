import 'dart:math';

/// Input values for adaptive visible widget cache sizing.
class OffstageVisibleCachePolicyInput {
  /// Creates a cache policy input snapshot.
  const OffstageVisibleCachePolicyInput({
    required this.baseCapacity,
    required this.minCapacity,
    required this.averageItemMainExtent,
    required this.averageItemCrossExtent,
    required this.viewportMainExtent,
    required this.viewportCrossExtent,
    required this.spacing,
    required this.runSpacing,
    this.areaPivot = 30000,
    this.maxViewportMultiplier = 8,
  });

  /// Upper bound for the cache capacity.
  final int baseCapacity;

  /// Lower bound for the cache capacity.
  final int minCapacity;

  /// Average item size on main axis.
  final double averageItemMainExtent;

  /// Average item size on cross axis.
  final double averageItemCrossExtent;

  /// Available viewport size on main axis.
  final double viewportMainExtent;

  /// Available viewport size on cross axis.
  final double viewportCrossExtent;

  /// Spacing between items in a row/column.
  final double spacing;

  /// Spacing between rows/columns.
  final double runSpacing;

  /// Area pivot used to modulate the cache multiplier by item size.
  final double areaPivot;

  /// Upper bound for the multiplier applied over visible items estimate.
  final int maxViewportMultiplier;
}

/// Input values for adaptive offstage measurement batch sizing.
class OffstageMeasureBatchPolicyInput {
  /// Creates a measurement batch policy input snapshot.
  const OffstageMeasureBatchPolicyInput({
    required this.baseMeasureBatchSize,
    required this.largeItemBatchCap,
    required this.averageItemArea,
    required this.minLargeItemArea,
    required this.sampleCount,
    this.minSamples = 8,
  });

  /// Requested measurement batch size from widget config.
  final int baseMeasureBatchSize;

  /// Cap applied when large-item mode is enabled.
  final int largeItemBatchCap;

  /// Average measured item area (`main * cross`).
  final double averageItemArea;

  /// Area threshold that enables large-item mode.
  final double minLargeItemArea;

  /// Number of measured samples used to estimate [averageItemArea].
  final int sampleCount;

  /// Minimum measured samples required before adapting.
  final int minSamples;
}

/// Summary of estimated visible item density for the current viewport.
class VisibleItemDensity {
  /// Creates a visible density estimate.
  const VisibleItemDensity({
    required this.itemsPerRun,
    required this.runsPerViewport,
    required this.itemsPerViewport,
  });

  /// Estimated number of items fitting in each run.
  final int itemsPerRun;

  /// Estimated number of runs visible in the viewport.
  final int runsPerViewport;

  /// Estimated number of visible items in the viewport.
  final int itemsPerViewport;
}

/// Estimates visible item density from average item extents and viewport size.
VisibleItemDensity estimateVisibleItemDensity({
  required double averageItemMainExtent,
  required double averageItemCrossExtent,
  required double viewportMainExtent,
  required double viewportCrossExtent,
  required double spacing,
  required double runSpacing,
}) {
  final avgMain = averageItemMainExtent;
  final avgCross = averageItemCrossExtent;
  final viewportMain = viewportMainExtent;
  final viewportCross = viewportCrossExtent;
  final mainSpacing = max(0, spacing);
  final crossSpacing = max(0, runSpacing);

  if (!avgMain.isFinite ||
      !avgCross.isFinite ||
      !viewportMain.isFinite ||
      !viewportCross.isFinite ||
      avgMain <= 0 ||
      avgCross <= 0 ||
      viewportMain <= 0 ||
      viewportCross <= 0) {
    return const VisibleItemDensity(
      itemsPerRun: 1,
      runsPerViewport: 1,
      itemsPerViewport: 1,
    );
  }

  final itemsPerRun = max(
    1,
    ((viewportMain + mainSpacing) / (avgMain + mainSpacing)).floor(),
  );
  final runsPerViewport = max(
    1,
    ((viewportCross + crossSpacing) / (avgCross + crossSpacing)).floor(),
  );
  final itemsPerViewport = max(1, itemsPerRun * runsPerViewport);

  return VisibleItemDensity(
    itemsPerRun: itemsPerRun,
    runsPerViewport: runsPerViewport,
    itemsPerViewport: itemsPerViewport,
  );
}

/// Computes an adaptive visible widget cache capacity.
///
/// The policy keeps capacity bounded in `[minCapacity, baseCapacity]` and
/// scales by estimated visible item density: smaller items get a larger cache,
/// larger items get a smaller cache.
int computeAdaptiveVisibleCacheCapacity(OffstageVisibleCachePolicyInput input) {
  final baseCapacity = input.baseCapacity;
  if (baseCapacity <= 0) return 0;

  final minCapacity = input.minCapacity.clamp(1, baseCapacity);
  final avgMain = input.averageItemMainExtent;
  final avgCross = input.averageItemCrossExtent;
  final viewportMain = input.viewportMainExtent;
  final viewportCross = input.viewportCrossExtent;
  final areaPivot = max(1, input.areaPivot);
  final maxViewportMultiplier = max(1, input.maxViewportMultiplier);

  if (!avgMain.isFinite ||
      !avgCross.isFinite ||
      !viewportMain.isFinite ||
      !viewportCross.isFinite ||
      avgMain <= 0 ||
      avgCross <= 0 ||
      viewportMain <= 0 ||
      viewportCross <= 0) {
    return baseCapacity;
  }

  final density = estimateVisibleItemDensity(
    averageItemMainExtent: input.averageItemMainExtent,
    averageItemCrossExtent: input.averageItemCrossExtent,
    viewportMainExtent: input.viewportMainExtent,
    viewportCrossExtent: input.viewportCrossExtent,
    spacing: input.spacing,
    runSpacing: input.runSpacing,
  );

  final averageArea = avgMain * avgCross;
  final viewportMultiplier = (areaPivot / averageArea).clamp(
    1.0,
    maxViewportMultiplier.toDouble(),
  );

  final target = (density.itemsPerViewport * viewportMultiplier).round();
  return target.clamp(minCapacity, baseCapacity);
}

/// Computes adaptive offstage measurement batch size.
///
/// For large items (card-like), a smaller batch reduces per-frame work spikes.
int computeAdaptiveMeasureBatchSize(OffstageMeasureBatchPolicyInput input) {
  final base = max(1, input.baseMeasureBatchSize);
  if (input.largeItemBatchCap <= 0) return base;
  if (input.sampleCount < max(1, input.minSamples)) return base;

  final averageItemArea = input.averageItemArea;
  if (!averageItemArea.isFinite ||
      averageItemArea < max(1.0, input.minLargeItemArea)) {
    return base;
  }

  final cap = max(1, input.largeItemBatchCap);
  return min(base, cap);
}
