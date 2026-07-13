import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap_sliver_v2.dart';
import 'package:lazy_wrap/src/lazy_wrap_engine.dart';
import 'package:lazy_wrap/src/offstage_visible_cache_policy.dart';
import 'package:lazy_wrap/src/sliver_v3_layout_core.dart';
import 'package:lazy_wrap/src/sliver_v3_render_list.dart';

const _offstageAddAutomaticKeepAlives = bool.fromEnvironment(
  'OFFSTAGE_ADD_AUTOMATIC_KEEP_ALIVES',
);

const _offstageAddRepaintBoundaries = bool.fromEnvironment(
  'OFFSTAGE_ADD_REPAINT_BOUNDARIES',
);

const _offstageAdaptiveRepaintBoundaries = bool.fromEnvironment(
  'OFFSTAGE_ADAPTIVE_REPAINT_BOUNDARIES',
);

const _offstageVisibleWidgetCacheCapacity = int.fromEnvironment(
  'OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY',
  defaultValue: 256,
);

const _offstageAdaptiveVisibleWidgetCache = bool.fromEnvironment(
  'OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE',
  defaultValue: true,
);

const _offstageVisibleWidgetCacheMinItemArea = int.fromEnvironment(
  'OFFSTAGE_VISIBLE_WIDGET_CACHE_MIN_ITEM_AREA',
  defaultValue: 12000,
);

const _offstageAdaptiveMeasureBatch = bool.fromEnvironment(
  'OFFSTAGE_ADAPTIVE_MEASURE_BATCH',
);

const _offstageLargeItemMeasureBatchCap = int.fromEnvironment(
  'OFFSTAGE_LARGE_ITEM_MEASURE_BATCH_CAP',
  defaultValue: 8,
);

const _offstageSingleMeasureBatch = bool.fromEnvironment(
  'OFFSTAGE_SINGLE_MEASURE_BATCH',
);

const _offstageIncrementalLoad = bool.fromEnvironment(
  'OFFSTAGE_INCREMENTAL_LOAD',
);

const _offstageIncrementalMeasureScanCursor = bool.fromEnvironment(
  'OFFSTAGE_INCREMENTAL_MEASURE_SCAN_CURSOR',
  defaultValue: false,
);

const _offstageMeasurementFlushChunkSize = int.fromEnvironment(
  'OFFSTAGE_MEASUREMENT_FLUSH_CHUNK_SIZE',
  defaultValue: 0,
);

/// Internal widget that measures its child's size after layout.
class _MeasureSize extends StatefulWidget {
  const _MeasureSize({
    required this.measurementId,
    required this.child,
    required this.onChange,
    super.key,
  });

  final int measurementId;
  final Widget child;
  final void Function(Size size) onChange;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _lastSize;
  bool _scheduled = false;

  @override
  void didUpdateWidget(covariant _MeasureSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measurementId != widget.measurementId) {
      _lastSize = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleCheck();
    return widget.child;
  }

  void _scheduleCheck() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.size != _lastSize) {
        _lastSize = box.size;
        widget.onChange(box.size);
      }
    });
  }
}

/// Default loading indicator widget.
Widget _defaultLoadingBuilder(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _RowsLayout {
  _RowsLayout({
    required this.itemIndices,
    required this.geometry,
  });

  final Int32List itemIndices;
  final SliverV3RowLayout geometry;

  Int32List get rowStarts => geometry.rowStarts;
  Int32List get rowLengths => geometry.rowLengths;
  Float64List get rowCrossExtents => geometry.rowCrossExtents;
  int get rowCount => geometry.rowCount;
}

/// A lazy wrap layout for items of dynamic/unknown size.
///
/// Items are measured invisibly (via [Offstage]) before being displayed,
/// which eliminates layout jumps when items have varying sizes.
///
/// Supports:
/// - Batched loading via [batchSize]
/// - Optional fade-in animation via [fadeInItems]
/// - Custom loading indicator via [loadingBuilder]
/// - External scroll controller via [controller]
/// - Both vertical and horizontal scrolling via [scrollDirection]
///
/// {@tool snippet}
/// ```dart
/// DynamicLazyWrap(
///   itemCount: 1000,
///   itemBuilder: (context, index) => Chip(label: Text('Tag $index')),
///   batchSize: 50,
///   fadeInItems: true,
/// )
/// ```
/// {@end-tool}
class DynamicLazyWrap extends StatelessWidget {
  /// Creates a [DynamicLazyWrap] widget.
  ///
  /// The [itemCount] and [itemBuilder] arguments are required.
  const DynamicLazyWrap({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.rowAlignment = MainAxisAlignment.start,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 300,
    this.batchSize = 50,
    this.loadingBuilder,
    this.fadeInItems = true,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeInCurve = Curves.easeOut,
    this.controller,
    this.loadThreshold = 300,
    this.measureBatchSize = 15,
    this.engine = LazyWrapEngine.offstageV1,
    this.itemWidthBuilder,
    this.itemHeightBuilder,
  }) : assert(itemCount >= 0, 'itemCount must be >= 0'),
       assert(spacing >= 0, 'spacing must be >= 0'),
       assert(runSpacing >= 0, 'runSpacing must be >= 0'),
       assert(batchSize > 0, 'batchSize must be > 0'),
       assert(measureBatchSize > 0, 'measureBatchSize must be > 0'),
       assert(cacheExtent >= 0, 'cacheExtent must be >= 0'),
       assert(loadThreshold >= 0, 'loadThreshold must be >= 0'),
       assert(
         engine != LazyWrapEngine.sliverV2 || scrollDirection == Axis.vertical,
         'scrollDirection must be Axis.vertical for engine sliverV2',
       ),
       assert(
         engine != LazyWrapEngine.sliverV2 ||
             (itemWidthBuilder != null && itemHeightBuilder != null),
         'itemWidthBuilder and itemHeightBuilder are required for engine '
         'sliverV2',
       );

  /// Total number of items in the list.
  final int itemCount;

  /// Builder function called to create each item widget.
  final Widget Function(BuildContext, int) itemBuilder;

  /// Horizontal spacing between items within a row. Default: 8.
  final double spacing;

  /// Vertical spacing between rows. Default: 8.
  final double runSpacing;

  /// Padding around the entire wrap content. Default: [EdgeInsets.zero].
  final EdgeInsetsGeometry padding;

  /// Alignment of items within each row. Default: [MainAxisAlignment.start].
  final MainAxisAlignment rowAlignment;

  /// The scroll direction. Default: [Axis.vertical].
  final Axis scrollDirection;

  /// The number of pixels to pre-render beyond the viewport.
  /// Higher values provide smoother scrolling at the cost of more memory.
  /// Default: 300.
  final double cacheExtent;

  /// Number of items to load per batch. Default: 50.
  final int batchSize;

  /// Custom loading indicator shown while more items are loading.
  /// If null, a default [CircularProgressIndicator] is shown.
  final Widget Function(BuildContext)? loadingBuilder;

  /// Whether to animate items with a fade-in when they first appear.
  /// Default: true.
  final bool fadeInItems;

  /// Duration of the fade-in animation. Default: 200ms.
  final Duration fadeInDuration;

  /// Curve for the fade-in animation. Default: [Curves.easeOut].
  final Curve fadeInCurve;

  /// Optional external scroll controller.
  /// If not provided, an internal controller is used.
  final ScrollController? controller;

  /// Distance from the bottom (in pixels) at which a new batch loads.
  /// Default: 300. This is independent from [cacheExtent].
  final double loadThreshold;

  /// Maximum number of items to measure in Offstage per frame.
  /// Lower values reduce CPU spikes for complex items. Default: 15.
  final int measureBatchSize;

  /// Dynamic rendering engine. Default: [LazyWrapEngine.offstageV1].
  final LazyWrapEngine engine;

  /// Deterministic width builder used by [LazyWrapEngine.sliverV2].
  final double Function(int)? itemWidthBuilder;

  /// Deterministic height builder used by [LazyWrapEngine.sliverV2].
  final double Function(int)? itemHeightBuilder;

  @override
  Widget build(BuildContext context) {
    if (engine == LazyWrapEngine.sliverV2) {
      return DynamicLazyWrapSliverV2(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        itemWidthBuilder: itemWidthBuilder!,
        itemHeightBuilder: itemHeightBuilder!,
        spacing: spacing,
        runSpacing: runSpacing,
        padding: padding,
        rowAlignment: rowAlignment,
        cacheExtent: cacheExtent,
        batchSize: batchSize,
        loadThreshold: loadThreshold,
        loadingBuilder: loadingBuilder,
        controller: controller,
      );
    }

    return _DynamicLazyWrapOffstageV1(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      spacing: spacing,
      runSpacing: runSpacing,
      padding: padding,
      rowAlignment: rowAlignment,
      scrollDirection: scrollDirection,
      cacheExtent: cacheExtent,
      batchSize: batchSize,
      loadingBuilder: loadingBuilder,
      fadeInItems: fadeInItems,
      fadeInDuration: fadeInDuration,
      fadeInCurve: fadeInCurve,
      controller: controller,
      loadThreshold: loadThreshold,
      measureBatchSize: measureBatchSize,
    );
  }
}

class _DynamicLazyWrapOffstageV1 extends StatefulWidget {
  const _DynamicLazyWrapOffstageV1({
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.rowAlignment = MainAxisAlignment.start,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 300,
    this.batchSize = 50,
    this.loadingBuilder,
    this.fadeInItems = true,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeInCurve = Curves.easeOut,
    this.controller,
    this.loadThreshold = 300,
    this.measureBatchSize = 15,
  });

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final MainAxisAlignment rowAlignment;
  final Axis scrollDirection;
  final double cacheExtent;
  final int batchSize;
  final Widget Function(BuildContext)? loadingBuilder;
  final bool fadeInItems;
  final Duration fadeInDuration;
  final Curve fadeInCurve;
  final ScrollController? controller;
  final double loadThreshold;
  final int measureBatchSize;

  @override
  State<_DynamicLazyWrapOffstageV1> createState() =>
      _DynamicLazyWrapOffstageV1State();
}

class _DynamicLazyWrapOffstageV1State
    extends State<_DynamicLazyWrapOffstageV1> {
  late ScrollController _scrollController;
  ScrollController? _internalScrollController;

  ScrollController get _resolvedScrollController =>
      widget.controller ?? (_internalScrollController ??= ScrollController());

  /// Cache of measured item widths and heights.
  Float32List _itemWidths = Float32List(0);
  Float32List _itemHeights = Float32List(0);

  /// Items currently being measured in Offstage.
  final Set<int> _measuringItems = {};

  /// Newly measured sizes buffered until the next flush frame.
  final Map<int, Size> _pendingMeasuredSizes = {};

  /// Items whose one-time fade has already been consumed.
  Uint8List _animatedItems = Uint8List(0);

  /// Items whose first fade is currently mounted.
  ///
  /// This is separate from [_animatedItems] so rebuilding the sliver while a
  /// fade is running does not remove and restart the transition. If the row is
  /// recycled before completion, [_FadeInWidget] consumes the fade on dispose.
  final Set<int> _fadingItems = {};

  /// Pending items that need measuring but haven't been sent to Offstage yet.
  final Queue<int> _pendingMeasure = Queue<int>();
  int _pendingMeasureScanIndex = 0;

  /// LRU cache for visible item widgets (opt-in via dart-define).
  final LinkedHashMap<int, Widget> _visibleItemWidgetCache =
      LinkedHashMap<int, Widget>();
  int _effectiveVisibleWidgetCacheCapacity =
      _offstageVisibleWidgetCacheCapacity;
  bool _effectiveAddRepaintBoundaries = _offstageAddRepaintBoundaries;
  int _effectiveMeasureBatchSize = 1;

  /// Current number of items loaded (available for measurement + display).
  int _loadedCount = 0;

  /// Whether currently loading more items.
  bool _isLoading = false;
  int _pendingLoadCount = 0;
  bool _loadStepScheduled = false;

  /// Computed rows cache.
  _RowsLayout? _rowsCache;
  double? _lastAvailableMain;
  bool _measurementFlushScheduled = false;
  bool _fillViewportCheckScheduled = false;
  bool _skipFadeForCurrentFrame = false;
  bool _fadePriorityResetScheduled = false;
  double _lastObservedScrollOffset = 0;

  bool get _isVertical => widget.scrollDirection == Axis.vertical;
  bool get _hasMoreItems => _loadedCount < widget.itemCount;
  bool get _hasMeasurementWork =>
      _measuringItems.isNotEmpty ||
      _pendingMeasure.isNotEmpty ||
      _pendingMeasuredSizes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadedCount = widget.batchSize.clamp(0, widget.itemCount);
    _ensureItemSizesLength(_loadedCount);
    _ensureAnimatedLength(_loadedCount);
    _effectiveMeasureBatchSize = max(1, widget.measureBatchSize);
    _scrollController = _resolvedScrollController;
    _scrollController.addListener(_onScroll);
    _scheduleFillViewportCheck();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _internalScrollController?.dispose();
    _visibleItemWidgetCache.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(_DynamicLazyWrapOffstageV1 oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Parent updates may change captured values used by itemBuilder even when
    // the function identity is stable (e.g., tear-offs). Keep cache coherent.
    _visibleItemWidgetCache.clear();

    if (widget.itemBuilder != oldWidget.itemBuilder) {
      _visibleItemWidgetCache.clear();
    }

    // Handle external controller swap without accumulating listeners.
    if (widget.controller != oldWidget.controller) {
      final nextController = _resolvedScrollController;
      if (!identical(_scrollController, nextController)) {
        _scrollController.removeListener(_onScroll);
        _scrollController = nextController;
        _lastObservedScrollOffset = 0;
        _scrollController.addListener(_onScroll);
      }
    }

    if (widget.itemCount != oldWidget.itemCount) {
      _loadedCount = _loadedCount.clamp(0, widget.itemCount);
      if (_offstageIncrementalLoad) {
        final maxPending = max(0, widget.itemCount - _loadedCount);
        _pendingLoadCount = _pendingLoadCount.clamp(0, maxPending);
        if (_pendingLoadCount == 0) {
          _isLoading = false;
        } else {
          _isLoading = true;
          _scheduleLoadStep();
        }
      } else {
        _pendingLoadCount = 0;
      }
      _rowsCache = null;
      _removeOutOfRangeItems();
      if (!_offstageIncrementalLoad && !_hasMeasurementWork) {
        _isLoading = false;
      }
      _scheduleFillViewportCheck();
    }

    if (widget.spacing != oldWidget.spacing ||
        widget.runSpacing != oldWidget.runSpacing ||
        widget.scrollDirection != oldWidget.scrollDirection) {
      _rowsCache = null;
      _lastAvailableMain = null;
    }

    if (oldWidget.fadeInItems && !widget.fadeInItems) {
      for (final index in _fadingItems) {
        _markAnimated(index);
      }
      _fadingItems.clear();
    }

    if (widget.measureBatchSize != oldWidget.measureBatchSize) {
      _effectiveMeasureBatchSize = max(1, widget.measureBatchSize);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visibleItemWidgetCache.clear();
  }

  void _removeOutOfRangeItems() {
    final itemCount = widget.itemCount;

    _pendingMeasure.removeWhere((i) => i >= itemCount);
    _measuringItems.removeWhere((i) => i >= itemCount);
    _pendingMeasuredSizes.removeWhere((i, _) => i >= itemCount);
    _fadingItems.removeWhere((i) => i >= itemCount);
    _visibleItemWidgetCache.removeWhere((index, _) => index >= itemCount);
    _trimVisibleItemWidgetCache();

    if (_itemWidths.length > itemCount) {
      final nextWidths = Float32List(itemCount);
      final nextHeights = Float32List(itemCount);
      nextWidths.setRange(0, itemCount, _itemWidths);
      nextHeights.setRange(0, itemCount, _itemHeights);
      _itemWidths = nextWidths;
      _itemHeights = nextHeights;
    }
    if (_animatedItems.length > itemCount) {
      final nextAnimated = Uint8List(itemCount)
        ..setRange(0, itemCount, _animatedItems);
      _animatedItems = nextAnimated;
    }
    if (_pendingMeasureScanIndex > _loadedCount) {
      _pendingMeasureScanIndex = _loadedCount;
    }
  }

  void _enqueueUnmeasuredItems() {
    if (_pendingMeasure.isNotEmpty) {
      return;
    }

    if (!_offstageIncrementalMeasureScanCursor) {
      for (var i = 0; i < _loadedCount; i++) {
        if (!_hasMeasuredSize(i) &&
            !_hasPendingMeasuredSize(i) &&
            !_measuringItems.contains(i)) {
          _pendingMeasure.addLast(i);
        }
      }
      return;
    }

    if (_pendingMeasureScanIndex > _loadedCount) {
      _pendingMeasureScanIndex = _loadedCount;
    }

    for (var i = _pendingMeasureScanIndex; i < _loadedCount; i++) {
      if (!_hasMeasuredSize(i) &&
          !_hasPendingMeasuredSize(i) &&
          !_measuringItems.contains(i)) {
        _pendingMeasure.addLast(i);
      }
    }

    _pendingMeasureScanIndex = _loadedCount;
  }

  void _ensureItemSizesLength(int length) {
    if (_itemWidths.length >= length) return;
    final oldLength = _itemWidths.length;
    final nextWidths = Float32List(length);
    final nextHeights = Float32List(length);
    nextWidths.setRange(0, oldLength, _itemWidths);
    nextHeights.setRange(0, oldLength, _itemHeights);
    for (var i = oldLength; i < length; i++) {
      nextWidths[i] = double.nan;
      nextHeights[i] = double.nan;
    }
    _itemWidths = nextWidths;
    _itemHeights = nextHeights;
  }

  void _ensureAnimatedLength(int length) {
    if (_animatedItems.length >= length) return;
    final oldLength = _animatedItems.length;
    final nextAnimated = Uint8List(length)
      ..setRange(0, oldLength, _animatedItems);
    _animatedItems = nextAnimated;
  }

  bool _isAnimated(int index) =>
      index >= 0 && index < _animatedItems.length && _animatedItems[index] == 1;

  void _markAnimated(int index) {
    if (index < 0 || index >= widget.itemCount) return;
    _ensureAnimatedLength(index + 1);
    _animatedItems[index] = 1;
  }

  double? _itemWidthAt(int index) {
    if (index < 0 || index >= _itemWidths.length) return null;
    final width = _itemWidths[index];
    return width.isNaN ? null : width;
  }

  double? _itemHeightAt(int index) {
    if (index < 0 || index >= _itemHeights.length) return null;
    final height = _itemHeights[index];
    return height.isNaN ? null : height;
  }

  bool _hasMeasuredSize(int index) =>
      _itemWidthAt(index) != null && _itemHeightAt(index) != null;

  bool _hasPendingMeasuredSize(int index) =>
      _pendingMeasuredSizes.containsKey(index);

  void _scheduleFillViewportCheck() {
    if (_fillViewportCheckScheduled) return;
    _fillViewportCheckScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _fillViewportCheckScheduled = false;
      _checkFillViewport();
    });
    binding.ensureVisualUpdate();
  }

  void _checkFillViewport() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_isLoading || !_hasMoreItems) return;

    // Don't load more while items are still being measured.
    // Unmeasured items don't contribute to scrollExtent yet, so
    // loading more before they're measured creates an infinite loop.
    if (_hasMeasurementWork) {
      return;
    }

    final pos = _scrollController.position;
    if (_shouldLoadFor(pos)) {
      _loadMore();
    }
  }

  bool _shouldLoadFor(ScrollMetrics position) {
    return position.maxScrollExtent <= 0 ||
        position.maxScrollExtent < position.viewportDimension ||
        position.extentAfter <= widget.loadThreshold;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    final scrollDelta = (pos.pixels - _lastObservedScrollOffset).abs();
    _lastObservedScrollOffset = pos.pixels;
    if (pos.viewportDimension > 0 && scrollDelta > pos.viewportDimension) {
      _skipFadeForCurrentFrame = true;
      _scheduleFadePriorityReset();
    }

    if (_isLoading || !_hasMoreItems || _hasMeasurementWork) return;

    if (_shouldLoadFor(pos)) {
      _loadMore();
    }
  }

  void _scheduleFadePriorityReset() {
    if (_fadePriorityResetScheduled) return;
    _fadePriorityResetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadePriorityResetScheduled = false;
      _skipFadeForCurrentFrame = false;
    });
  }

  void _loadMore() {
    if (_isLoading || !_hasMoreItems || _hasMeasurementWork) return;
    if (!_offstageIncrementalLoad) {
      setState(() {
        _isLoading = true;
        _loadedCount = (_loadedCount + widget.batchSize).clamp(
          0,
          widget.itemCount,
        );
        _ensureItemSizesLength(_loadedCount);
        _ensureAnimatedLength(_loadedCount);
        _rowsCache = null;
      });
      return;
    }

    final maxAdditional = widget.itemCount - _loadedCount - _pendingLoadCount;
    if (maxAdditional <= 0) return;

    setState(() {
      _isLoading = true;
      _pendingLoadCount += min(widget.batchSize, maxAdditional);
    });
    _scheduleLoadStep();
  }

  int get _loadStepSize =>
      max(1, min(widget.batchSize, _effectiveMeasureBatchSize * 2));

  void _scheduleLoadStep() {
    if (_loadStepScheduled) return;
    _loadStepScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _loadStepScheduled = false;
      _runLoadStep();
    });
  }

  void _runLoadStep() {
    if (!mounted) return;
    if (_pendingLoadCount <= 0) {
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
      _scheduleFillViewportCheck();
      return;
    }

    // Avoid stacking load steps while current items are still being measured.
    // This keeps the queue bounded and prevents runaway frame churn.
    if (_hasMeasurementWork) {
      return;
    }

    final maxAdditional = widget.itemCount - _loadedCount;
    if (maxAdditional <= 0) {
      setState(() {
        _pendingLoadCount = 0;
        _isLoading = false;
      });
      return;
    }

    final step = min(_loadStepSize, min(_pendingLoadCount, maxAdditional));
    setState(() {
      _loadedCount += step;
      _pendingLoadCount -= step;
      _ensureItemSizesLength(_loadedCount);
      _ensureAnimatedLength(_loadedCount);
      _rowsCache = null;
    });
  }

  void _onItemMeasured(int index, Size size) {
    if (!mounted || index >= widget.itemCount) return;
    final pendingSize = _pendingMeasuredSizes[index];
    final previousWidth = pendingSize?.width ?? _itemWidthAt(index);
    final previousHeight = pendingSize?.height ?? _itemHeightAt(index);
    if (previousWidth != size.width || previousHeight != size.height) {
      _pendingMeasuredSizes[index] = size;
    }
    _measuringItems.remove(index);
    _scheduleMeasurementFlush();
  }

  void _scheduleMeasurementFlush() {
    if (_measurementFlushScheduled) return;
    _measurementFlushScheduled = true;

    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _measurementFlushScheduled = false;
      if (!mounted) return;

      if (_pendingMeasuredSizes.isNotEmpty) {
        setState(() {
          final flushChunkSize = _offstageMeasurementFlushChunkSize <= 0
              ? _pendingMeasuredSizes.length
              : max(1, _offstageMeasurementFlushChunkSize);
          final keysToApply = _pendingMeasuredSizes.keys
              .take(flushChunkSize)
              .toList(
                growable: false,
              );
          for (final index in keysToApply) {
            final measuredSize = _pendingMeasuredSizes.remove(index);
            if (measuredSize == null) continue;
            if (index >= widget.itemCount) continue;
            _ensureItemSizesLength(index + 1);
            _itemWidths[index] = measuredSize.width;
            _itemHeights[index] = measuredSize.height;
          }
          _rowsCache = null;
        });
      }

      if (_pendingMeasuredSizes.isNotEmpty) {
        _scheduleMeasurementFlush();
      }

      _handleMeasurementQueueProgress();
    });
  }

  void _handleMeasurementQueueProgress() {
    if (!mounted) return;
    if (_pendingMeasure.isNotEmpty && _measuringItems.isEmpty) {
      setState(() {});
      return;
    }
    if (!_hasMeasurementWork) {
      if (_offstageIncrementalLoad && _pendingLoadCount > 0) {
        _scheduleLoadStep();
        return;
      }
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
      _scheduleFillViewportCheck();
    }
  }

  /// Returns items to measure in this frame (sub-batched).
  List<int> _getItemsToMeasure() {
    _removeOutOfRangeItems();

    // Optional experimental mode: keep at most one active measurement batch.
    if (_offstageSingleMeasureBatch && _measuringItems.isNotEmpty) {
      return const <int>[];
    }

    // Collect unmeasured items incrementally to avoid full rescans per build.
    _enqueueUnmeasuredItems();

    // Return only a sub-batch to avoid CPU spikes
    final batch = <int>[];
    final batchEnd = min(_effectiveMeasureBatchSize, _pendingMeasure.length);
    for (var i = 0; i < batchEnd; i++) {
      batch.add(_pendingMeasure.removeFirst());
    }

    _measuringItems.addAll(batch);
    return batch;
  }

  /// Compute rows from only measured items.
  _RowsLayout _computeRows(double availableMain) {
    if (_rowsCache != null && _lastAvailableMain == availableMain) {
      return _rowsCache!;
    }

    final flatIndices = <int>[];
    for (var i = 0; i < _loadedCount; i++) {
      if (!_hasMeasuredSize(i)) continue;
      flatIndices.add(i);
    }

    final itemIndices = Int32List.fromList(flatIndices);
    final geometry = SliverV3RowLayout.compute(
      itemCount: itemIndices.length,
      availableMainAxisExtent: availableMain,
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      itemWidth: (flatIndex) {
        final itemIndex = itemIndices[flatIndex];
        return _isVertical ? _itemWidths[itemIndex] : _itemHeights[itemIndex];
      },
      itemHeight: (flatIndex) {
        final itemIndex = itemIndices[flatIndex];
        return _isVertical ? _itemHeights[itemIndex] : _itemWidths[itemIndex];
      },
    );
    final rows = _RowsLayout(
      itemIndices: itemIndices,
      geometry: geometry,
    );
    _rowsCache = rows;
    _lastAvailableMain = availableMain;
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    _updateMeasureBatchSize();
    final itemsToMeasure = _getItemsToMeasure();
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = widget.padding.resolve(textDirection);
        final availableMain = _isVertical
            ? constraints.maxWidth - resolvedPadding.horizontal
            : constraints.maxHeight - resolvedPadding.vertical;
        final availableCross = _isVertical
            ? constraints.maxHeight - resolvedPadding.vertical
            : constraints.maxWidth - resolvedPadding.horizontal;
        _updateVisibleWidgetCacheCapacity(
          availableMain: availableMain,
          availableCross: availableCross,
        );
        _updateRepaintBoundariesSetting(
          availableMain: availableMain,
          availableCross: availableCross,
        );

        final hadSameAvailableMain = _lastAvailableMain == availableMain;
        final rows = _computeRows(availableMain);
        if (!hadSameAvailableMain) {
          _scheduleFillViewportCheck();
        }

        return Stack(
          children: [
            // Offstage measurement area (sub-batched)
            if (itemsToMeasure.isNotEmpty)
              Offstage(
                child: Column(
                  children: itemsToMeasure.map((index) {
                    return _MeasureSize(
                      key: ValueKey<int>(index),
                      measurementId: index,
                      onChange: (size) => _onItemMeasured(index, size),
                      child: widget.itemBuilder(context, index),
                    );
                  }).toList(),
                ),
              ),

            // Visible scroll view
            CustomScrollView(
              controller: _scrollController,
              scrollDirection: widget.scrollDirection,
              cacheExtent: widget.cacheExtent,
              slivers: [
                SliverPadding(
                  padding: widget.padding,
                  sliver: SliverV3RenderList(
                    rows: rows.geometry,
                    delegate: SliverChildBuilderDelegate(
                      (context, rowIndex) {
                        if (rowIndex >= rows.rowCount) return null;
                        return _buildRow(context, rows, rowIndex);
                      },
                      childCount: rows.rowCount,
                      addAutomaticKeepAlives: _offstageAddAutomaticKeepAlives,
                      addRepaintBoundaries: _effectiveAddRepaintBoundaries,
                    ),
                  ),
                ),
                if (_isLoading ||
                    _measuringItems.isNotEmpty ||
                    _pendingMeasure.isNotEmpty ||
                    (_hasMoreItems && rows.rowCount > 0))
                  SliverToBoxAdapter(
                    child:
                        (_isLoading ||
                            _measuringItems.isNotEmpty ||
                            _pendingMeasure.isNotEmpty)
                        ? (widget.loadingBuilder?.call(context) ??
                              _defaultLoadingBuilder(context))
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    _RowsLayout rows,
    int rowIndex,
  ) {
    final rowStart = rows.rowStarts[rowIndex];
    final rowLength = rows.rowLengths[rowIndex];
    final maxCross = rows.rowCrossExtents[rowIndex];

    final children = <Widget>[];

    for (var idx = 0; idx < rowLength; idx++) {
      final itemIndex = rows.itemIndices[rowStart + idx];
      final width = _itemWidths[itemIndex];
      final height = _itemHeights[itemIndex];
      final isLast = idx == rowLength - 1;

      Widget child = SizedBox(
        width: width,
        height: height,
        child: _buildVisibleItem(context, itemIndex),
      );

      // A fast fling can create a full viewport of new children in one frame.
      // Starting all of them at opacity zero looks like a gray/blank screen,
      // so consume their one-time fade and render them immediately while the
      // framework recommends deferring expensive visual work.
      if (widget.fadeInItems && !_isAnimated(itemIndex)) {
        final deferFade =
            _skipFadeForCurrentFrame ||
            Scrollable.recommendDeferredLoadingForContext(
              context,
              axis: widget.scrollDirection,
            );
        if (deferFade) {
          _markAnimated(itemIndex);
          _fadingItems.remove(itemIndex);
        } else {
          _fadingItems.add(itemIndex);
        }
      }

      if (widget.fadeInItems && _fadingItems.contains(itemIndex)) {
        child = _FadeInWidget(
          key: ValueKey<int>(itemIndex),
          duration: widget.fadeInDuration,
          curve: widget.fadeInCurve,
          onFinished: () {
            _fadingItems.remove(itemIndex);
            _markAnimated(itemIndex);
          },
          child: child,
        );
      }

      if (!isLast) {
        child = Padding(
          padding: _isVertical
              ? EdgeInsets.only(right: widget.spacing)
              : EdgeInsets.only(bottom: widget.spacing),
          child: child,
        );
      }

      children.add(child);
    }

    Widget row = Flex(
      direction: _isVertical ? Axis.horizontal : Axis.vertical,
      mainAxisAlignment: widget.rowAlignment,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    if (maxCross > 0) {
      row = SizedBox(
        height: _isVertical ? maxCross : null,
        width: _isVertical ? null : maxCross,
        child: row,
      );
    }

    return row;
  }

  Widget _buildVisibleItem(BuildContext context, int index) {
    if (_effectiveVisibleWidgetCacheCapacity <= 0) {
      return widget.itemBuilder(context, index);
    }

    final cached = _visibleItemWidgetCache.remove(index);
    if (cached != null) {
      _visibleItemWidgetCache[index] = cached;
      return cached;
    }

    final built = widget.itemBuilder(context, index);
    _visibleItemWidgetCache[index] = built;
    _trimVisibleItemWidgetCache();
    return built;
  }

  void _trimVisibleItemWidgetCache() {
    final cap = _effectiveVisibleWidgetCacheCapacity;
    if (cap <= 0) {
      _visibleItemWidgetCache.clear();
      return;
    }
    while (_visibleItemWidgetCache.length > cap) {
      _visibleItemWidgetCache.remove(_visibleItemWidgetCache.keys.first);
    }
  }

  void _updateVisibleWidgetCacheCapacity({
    required double availableMain,
    required double availableCross,
  }) {
    final next = _resolveVisibleWidgetCacheCapacity(
      availableMain: availableMain,
      availableCross: availableCross,
    );
    if (next == _effectiveVisibleWidgetCacheCapacity) {
      return;
    }
    _effectiveVisibleWidgetCacheCapacity = next;
    _trimVisibleItemWidgetCache();
  }

  void _updateMeasureBatchSize() {
    _effectiveMeasureBatchSize = _resolveMeasureBatchSize();
  }

  int _resolveMeasureBatchSize() {
    final base = max(1, widget.measureBatchSize);
    if (!_offstageAdaptiveMeasureBatch) {
      return base;
    }

    final averageExtents = _estimateAverageMeasuredExtents();
    if (averageExtents == null) {
      return base;
    }

    final averageItemArea =
        averageExtents.mainExtent * averageExtents.crossExtent;
    return computeAdaptiveMeasureBatchSize(
      OffstageMeasureBatchPolicyInput(
        baseMeasureBatchSize: base,
        largeItemBatchCap: _offstageLargeItemMeasureBatchCap,
        averageItemArea: averageItemArea,
        minLargeItemArea: _offstageVisibleWidgetCacheMinItemArea.toDouble(),
        sampleCount: averageExtents.sampleCount,
      ),
    );
  }

  int _resolveVisibleWidgetCacheCapacity({
    required double availableMain,
    required double availableCross,
  }) {
    const baseCapacity = _offstageVisibleWidgetCacheCapacity;
    if (baseCapacity <= 0) {
      return 0;
    }
    if (!_offstageAdaptiveVisibleWidgetCache) {
      return baseCapacity;
    }

    final averageExtents = _estimateAverageMeasuredExtents();
    if (averageExtents == null || averageExtents.sampleCount < 8) {
      return 0;
    }

    final averageItemArea =
        averageExtents.mainExtent * averageExtents.crossExtent;
    if (!averageItemArea.isFinite ||
        averageItemArea < _offstageVisibleWidgetCacheMinItemArea) {
      return 0;
    }

    return baseCapacity;
  }

  _AverageMeasuredExtents? _estimateAverageMeasuredExtents() {
    var mainSum = 0.0;
    var crossSum = 0.0;
    var sampleCount = 0;
    final maxSamples = min(_loadedCount, 128);

    for (var i = 0; i < _loadedCount && sampleCount < maxSamples; i++) {
      if (!_hasMeasuredSize(i)) continue;
      mainSum += _isVertical ? _itemWidths[i] : _itemHeights[i];
      crossSum += _isVertical ? _itemHeights[i] : _itemWidths[i];
      sampleCount++;
    }

    if (sampleCount == 0) return null;
    return _AverageMeasuredExtents(
      mainExtent: mainSum / sampleCount,
      crossExtent: crossSum / sampleCount,
      sampleCount: sampleCount,
    );
  }

  void _updateRepaintBoundariesSetting({
    required double availableMain,
    required double availableCross,
  }) {
    final next = _resolveAddRepaintBoundaries(
      availableMain: availableMain,
      availableCross: availableCross,
    );
    _effectiveAddRepaintBoundaries = next;
  }

  bool _resolveAddRepaintBoundaries({
    required double availableMain,
    required double availableCross,
  }) {
    if (_offstageAddRepaintBoundaries) {
      return true;
    }
    if (!_offstageAdaptiveRepaintBoundaries) {
      return false;
    }

    final averageExtents = _estimateAverageMeasuredExtents();
    if (averageExtents == null || averageExtents.sampleCount < 8) {
      return false;
    }

    final visibleDensity = estimateVisibleItemDensity(
      averageItemMainExtent: averageExtents.mainExtent,
      averageItemCrossExtent: averageExtents.crossExtent,
      viewportMainExtent: availableMain,
      viewportCrossExtent: availableCross,
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
    );

    // Hysteresis avoids toggling around the threshold frame-to-frame.
    if (_effectiveAddRepaintBoundaries) {
      return visibleDensity.itemsPerViewport >= 18;
    }
    return visibleDensity.itemsPerViewport >= 24;
  }
}

class _AverageMeasuredExtents {
  const _AverageMeasuredExtents({
    required this.mainExtent,
    required this.crossExtent,
    required this.sampleCount,
  });

  final double mainExtent;
  final double crossExtent;
  final int sampleCount;
}

/// Internal widget that animates a fade-in when first built.
class _FadeInWidget extends StatefulWidget {
  const _FadeInWidget({
    required this.child,
    required this.duration,
    required this.curve,
    this.onFinished,
    super.key,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onFinished;

  @override
  State<_FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<_FadeInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  bool _didFinish = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
    unawaited(_controller.forward().then((_) => _finish()));
  }

  void _finish() {
    if (_didFinish) return;
    _didFinish = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _finish();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}
