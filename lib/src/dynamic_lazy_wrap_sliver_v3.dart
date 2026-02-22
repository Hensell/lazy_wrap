import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/sliver_v3_layout_core.dart';
import 'package:lazy_wrap/src/sliver_v3_render_list.dart';

/// Internal sliverV3 spike based on explicit visible-row windowing.
///
/// This is intentionally not exposed in public API yet.
class DynamicLazyWrapSliverV3 extends StatefulWidget {
  const DynamicLazyWrapSliverV3({
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidthBuilder,
    required this.itemHeightBuilder,
    super.key,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.rowAlignment = MainAxisAlignment.start,
    this.cacheExtent = 300,
    this.batchSize,
    this.loadThreshold = 300,
    this.controller,
  }) : assert(itemCount >= 0, 'itemCount must be >= 0'),
       assert(spacing >= 0, 'spacing must be >= 0'),
       assert(runSpacing >= 0, 'runSpacing must be >= 0'),
       assert(cacheExtent >= 0, 'cacheExtent must be >= 0'),
       assert(batchSize == null || batchSize > 0, 'batchSize must be > 0'),
       assert(loadThreshold >= 0, 'loadThreshold must be >= 0');

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double Function(int) itemWidthBuilder;
  final double Function(int) itemHeightBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final MainAxisAlignment rowAlignment;
  final double cacheExtent;
  final int? batchSize;
  final double loadThreshold;
  final ScrollController? controller;

  @override
  State<DynamicLazyWrapSliverV3> createState() =>
      _DynamicLazyWrapSliverV3State();
}

class _DynamicLazyWrapSliverV3State extends State<DynamicLazyWrapSliverV3> {
  // Keep startup cache conservative to reduce first-frame work.
  static const double _startupCacheExtentCapDefault = 300;
  static const String _startupCacheExtentCapFromDefineRaw =
      String.fromEnvironment('SLIVERV3_STARTUP_CACHE_EXTENT_CAP');

  late ScrollController _scrollController;
  ScrollController? _internalController;

  ScrollController get _resolvedController =>
      widget.controller ?? (_internalController ??= ScrollController());

  Float32List _itemWidths = Float32List(0);
  Float32List _itemHeights = Float32List(0);

  SliverV3RowLayout? _rowsCache;
  double? _lastAvailableMain;
  int _rowsCacheItemCount = -1;
  int _loadedCount = 0;
  bool _fillViewportCheckScheduled = false;
  bool _needsFillViewportCheck = false;
  bool _loadStepScheduled = false;
  bool _startupCachePromoted = false;
  bool _isLoadingMore = false;
  int? _pendingLoadedCount;

  bool get _hasMoreItems => _loadedCount < widget.itemCount;

  double get _startupCacheExtentCap {
    final configured =
        double.tryParse(_startupCacheExtentCapFromDefineRaw) ??
        _startupCacheExtentCapDefault;
    if (configured.isNaN || configured.isInfinite || configured < 0) {
      return 0;
    }
    return configured;
  }

  bool get _hasStartupCacheCap => widget.cacheExtent > _startupCacheExtentCap;

  double get _effectiveCacheExtent {
    if (_startupCachePromoted || !_hasStartupCacheCap) {
      return widget.cacheExtent;
    }
    return _startupCacheExtentCap;
  }

  @override
  void initState() {
    super.initState();
    _loadedCount = _resolveInitialLoadedCount();
    _ensureItemSizesLength(_loadedCount);
    _scrollController = _resolvedController;
    _scrollController.addListener(_onScroll);
    _setFillViewportCheckNeeded(widget.batchSize != null && _hasMoreItems);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _internalController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DynamicLazyWrapSliverV3 oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      final nextController = _resolvedController;
      if (!identical(_scrollController, nextController)) {
        _scrollController.removeListener(_onScroll);
        _scrollController = nextController;
        _scrollController.addListener(_onScroll);
      }
    }

    final sizeBuilderChanged =
        widget.itemWidthBuilder != oldWidget.itemWidthBuilder ||
        widget.itemHeightBuilder != oldWidget.itemHeightBuilder;

    if (sizeBuilderChanged) {
      _itemWidths = Float32List(0);
      _itemHeights = Float32List(0);
    }

    if (widget.itemCount != oldWidget.itemCount ||
        widget.batchSize != oldWidget.batchSize) {
      _loadedCount = _resolveUpdatedLoadedCount(
        oldItemCount: oldWidget.itemCount,
        oldBatchSize: oldWidget.batchSize,
      );
      _truncateItemSizes(widget.itemCount);
      if (widget.batchSize == null) {
        _isLoadingMore = false;
        _pendingLoadedCount = null;
      }
    }

    _ensureItemSizesLength(_loadedCount);

    if (widget.itemCount != oldWidget.itemCount ||
        widget.spacing != oldWidget.spacing ||
        widget.runSpacing != oldWidget.runSpacing ||
        widget.rowAlignment != oldWidget.rowAlignment ||
        widget.itemBuilder != oldWidget.itemBuilder ||
        sizeBuilderChanged ||
        widget.batchSize != oldWidget.batchSize ||
        widget.loadThreshold != oldWidget.loadThreshold) {
      _invalidateRowsCache();
      _setFillViewportCheckNeeded(widget.batchSize != null && _hasMoreItems);
    }
  }

  int _resolveInitialLoadedCount() {
    final batchSize = widget.batchSize;
    if (batchSize == null) return widget.itemCount;
    return batchSize.clamp(0, widget.itemCount);
  }

  int _resolveUpdatedLoadedCount({
    required int oldItemCount,
    required int? oldBatchSize,
  }) {
    final batchSize = widget.batchSize;
    if (batchSize == null) {
      return widget.itemCount;
    }

    if (oldBatchSize == null && batchSize > 0 && _loadedCount == oldItemCount) {
      return batchSize.clamp(0, widget.itemCount);
    }

    final clamped = _loadedCount.clamp(0, widget.itemCount);
    if (clamped == 0 && widget.itemCount > 0) {
      return batchSize.clamp(0, widget.itemCount);
    }
    return clamped;
  }

  void _ensureItemSizesLength(int length) {
    if (_itemWidths.length >= length) return;
    final oldLength = _itemWidths.length;
    final nextWidths = Float32List(length);
    final nextHeights = Float32List(length);
    nextWidths.setRange(0, oldLength, _itemWidths);
    nextHeights.setRange(0, oldLength, _itemHeights);

    for (var i = oldLength; i < length; i++) {
      nextWidths[i] = max(0, widget.itemWidthBuilder(i));
      nextHeights[i] = max(0, widget.itemHeightBuilder(i));
    }

    _itemWidths = nextWidths;
    _itemHeights = nextHeights;
  }

  void _truncateItemSizes(int maxLength) {
    if (_itemWidths.length <= maxLength) return;
    final nextWidths = Float32List(maxLength);
    final nextHeights = Float32List(maxLength);
    nextWidths.setRange(0, maxLength, _itemWidths);
    nextHeights.setRange(0, maxLength, _itemHeights);
    _itemWidths = nextWidths;
    _itemHeights = nextHeights;
  }

  void _invalidateRowsCache() {
    _rowsCache = null;
    _lastAvailableMain = null;
    _rowsCacheItemCount = -1;
  }

  void _setFillViewportCheckNeeded(bool needed) {
    _needsFillViewportCheck = needed;
    if (_needsFillViewportCheck) {
      _scheduleFillViewportCheck();
    }
  }

  void _scheduleFillViewportCheck() {
    if (!_needsFillViewportCheck || _fillViewportCheckScheduled) return;
    _fillViewportCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fillViewportCheckScheduled = false;
      _checkFillViewport();
    });
  }

  void _checkFillViewport() {
    if (!mounted) return;
    if (!_needsFillViewportCheck) return;
    if (!_scrollController.hasClients || _isLoadingMore) {
      _scheduleFillViewportCheck();
      return;
    }
    if (!_hasMoreItems || widget.batchSize == null) {
      _setFillViewportCheckNeeded(false);
      return;
    }

    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0 ||
        pos.maxScrollExtent < pos.viewportDimension) {
      _loadMore(deferToNextFrame: false);
      return;
    }
    _setFillViewportCheckNeeded(false);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final pos = _scrollController.position;
    if (_hasStartupCacheCap &&
        !_startupCachePromoted &&
        pos.pixels.abs() > 0.001) {
      _startupCachePromoted = true;
      if (mounted) {
        setState(() {});
      }
    }

    if (_isLoadingMore || !_hasMoreItems) {
      return;
    }

    final threshold = pos.maxScrollExtent - widget.loadThreshold;
    if (pos.pixels >= threshold) {
      _loadMore(deferToNextFrame: true);
    }
  }

  void _loadMore({required bool deferToNextFrame}) {
    if (_isLoadingMore || !_hasMoreItems) return;
    final batchSize = widget.batchSize;
    if (batchSize == null) return;
    final nextLoadedCount = (_loadedCount + batchSize).clamp(
      0,
      widget.itemCount,
    );
    if (nextLoadedCount == _loadedCount) {
      _setFillViewportCheckNeeded(false);
      return;
    }

    _isLoadingMore = true;
    if (!deferToNextFrame) {
      setState(() {
        _loadedCount = nextLoadedCount;
        _ensureItemSizesLength(_loadedCount);
        _invalidateRowsCache();
      });
      _isLoadingMore = false;
      _setFillViewportCheckNeeded(widget.batchSize != null && _hasMoreItems);
      return;
    }

    _pendingLoadedCount = nextLoadedCount;
    _scheduleLoadStep();
  }

  void _scheduleLoadStep() {
    if (_loadStepScheduled) return;
    _loadStepScheduled = true;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStepScheduled = false;
      if (!mounted) return;
      _runLoadStep();
    });
  }

  void _runLoadStep() {
    if (!mounted) return;

    final pendingLoadedCount = _pendingLoadedCount;
    _pendingLoadedCount = null;
    if (!_isLoadingMore || pendingLoadedCount == null) {
      return;
    }

    final clampedLoadedCount = pendingLoadedCount.clamp(0, widget.itemCount);
    if (clampedLoadedCount <= _loadedCount) {
      _isLoadingMore = false;
      _setFillViewportCheckNeeded(widget.batchSize != null && _hasMoreItems);
      return;
    }

    // Defer batch growth to the next frame to keep the scroll listener light.
    setState(() {
      _loadedCount = clampedLoadedCount;
      _ensureItemSizesLength(_loadedCount);
      _invalidateRowsCache();
    });
    _isLoadingMore = false;
    _setFillViewportCheckNeeded(widget.batchSize != null && _hasMoreItems);
  }

  SliverV3RowLayout _computeRows(double availableMain) {
    if (availableMain <= 0 || _loadedCount == 0) {
      return SliverV3RowLayout.empty();
    }

    if (_rowsCache != null &&
        _lastAvailableMain == availableMain &&
        _rowsCacheItemCount == _loadedCount) {
      return _rowsCache!;
    }

    final rows = SliverV3RowLayout.compute(
      itemCount: _loadedCount,
      availableMainAxisExtent: availableMain,
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      itemWidth: (index) => _itemWidths[index],
      itemHeight: (index) => _itemHeights[index],
    );

    _rowsCache = rows;
    _lastAvailableMain = availableMain;
    _rowsCacheItemCount = _loadedCount;
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = widget.padding.resolve(textDirection);
        final rawAvailableMain =
            constraints.maxWidth - resolvedPadding.horizontal;
        final availableMain = rawAvailableMain < 0 ? 0.0 : rawAvailableMain;
        final rows = _computeRows(availableMain);
        if (_needsFillViewportCheck) {
          _scheduleFillViewportCheck();
        }

        return CustomScrollView(
          controller: _scrollController,
          cacheExtent: _effectiveCacheExtent,
          slivers: [
            SliverPadding(
              padding: widget.padding,
              sliver: SliverV3RenderList(
                rows: rows,
                delegate: SliverChildBuilderDelegate(
                  (context, rowIndex) {
                    if (rowIndex >= rows.rowCount) return null;
                    return _buildRow(context, rows, rowIndex);
                  },
                  childCount: rows.rowCount,
                  addAutomaticKeepAlives: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    SliverV3RowLayout rows,
    int rowIndex,
  ) {
    final rowStart = rows.rowStarts[rowIndex];
    final rowLength = rows.rowLengths[rowIndex];
    final children = <Widget>[];

    for (var idx = 0; idx < rowLength; idx++) {
      final itemIndex = rowStart + idx;

      final child = SizedBox(
        width: _itemWidths[itemIndex],
        height: _itemHeights[itemIndex],
        child: widget.itemBuilder(context, itemIndex),
      );

      children.add(child);
    }

    return SizedBox(
      height: rows.rowCrossExtents[rowIndex],
      child: Row(
        mainAxisAlignment: widget.rowAlignment,
        spacing: widget.spacing,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
