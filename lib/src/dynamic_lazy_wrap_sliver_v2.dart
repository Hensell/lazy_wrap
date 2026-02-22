import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/sliver_v3_layout_core.dart';

/// Experimental dynamic engine prototype based on sliver rows.
///
/// This is intentionally internal during Sprint 4. It only supports
/// vertical scrolling and requires deterministic item sizes via builders.
class DynamicLazyWrapSliverV2 extends StatefulWidget {
  const DynamicLazyWrapSliverV2({
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
    this.batchSize = 80,
    this.loadThreshold = 300,
    this.loadingBuilder,
    this.controller,
  }) : assert(itemCount >= 0, 'itemCount must be >= 0'),
       assert(spacing >= 0, 'spacing must be >= 0'),
       assert(runSpacing >= 0, 'runSpacing must be >= 0'),
       assert(cacheExtent >= 0, 'cacheExtent must be >= 0'),
       assert(batchSize > 0, 'batchSize must be > 0'),
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
  final int batchSize;
  final double loadThreshold;
  final Widget Function(BuildContext)? loadingBuilder;
  final ScrollController? controller;

  @override
  State<DynamicLazyWrapSliverV2> createState() =>
      _DynamicLazyWrapSliverV2State();
}

class _DynamicLazyWrapSliverV2State extends State<DynamicLazyWrapSliverV2> {
  late ScrollController _scrollController;
  ScrollController? _internalController;

  ScrollController get _resolvedController =>
      widget.controller ?? (_internalController ??= ScrollController());

  SliverV3RowLayout? _rowsCache;
  double? _lastAvailableMain;
  int _rowsCacheLoadedCount = 0;

  Float32List _itemWidths = Float32List(0);
  Float32List _itemHeights = Float32List(0);
  int _loadedCount = 0;

  @override
  void initState() {
    super.initState();
    // sliverV2 does not require offstage measurement, so preload all indices
    // to avoid repeated state churn while scrolling.
    _loadedCount = widget.itemCount;
    _ensureItemSizesLength(_loadedCount);
    _scrollController = _resolvedController;
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DynamicLazyWrapSliverV2 oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      final nextController = _resolvedController;
      if (!identical(_scrollController, nextController)) {
        _scrollController = nextController;
      }
    }

    final builderChanged =
        widget.itemWidthBuilder != oldWidget.itemWidthBuilder ||
        widget.itemHeightBuilder != oldWidget.itemHeightBuilder;

    if (builderChanged) {
      _itemWidths.clear();
      _itemHeights.clear();
    }

    if (widget.itemCount != oldWidget.itemCount) {
      _loadedCount = widget.itemCount;
      _truncateItemSizes(widget.itemCount);
    }

    _ensureItemSizesLength(_loadedCount);

    if (widget.itemCount != oldWidget.itemCount ||
        widget.spacing != oldWidget.spacing ||
        widget.runSpacing != oldWidget.runSpacing ||
        builderChanged) {
      _invalidateRowsCache();
    }
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
    if (_itemWidths.length > maxLength) {
      final nextWidths = Float32List(maxLength);
      final nextHeights = Float32List(maxLength);
      nextWidths.setRange(0, maxLength, _itemWidths);
      nextHeights.setRange(0, maxLength, _itemHeights);
      _itemWidths = nextWidths;
      _itemHeights = nextHeights;
    }
  }

  void _invalidateRowsCache() {
    _rowsCache = null;
    _rowsCacheLoadedCount = 0;
    _lastAvailableMain = null;
  }

  SliverV3RowLayout _computeRows(double availableMain) {
    if (availableMain <= 0 || _loadedCount == 0) {
      return SliverV3RowLayout.empty();
    }

    if (_rowsCache != null &&
        _lastAvailableMain == availableMain &&
        _rowsCacheLoadedCount == _loadedCount) {
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
    _rowsCacheLoadedCount = _loadedCount;
    _lastAvailableMain = availableMain;

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedPadding = widget.padding.resolve(textDirection);
        final availableMain = constraints.maxWidth - resolvedPadding.horizontal;
        final rows = _computeRows(availableMain);

        return CustomScrollView(
          controller: _scrollController,
          cacheExtent: widget.cacheExtent,
          slivers: [
            SliverPadding(
              padding: widget.padding,
              sliver: SliverList(
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
      final isLast = idx == rowLength - 1;

      Widget child = SizedBox(
        width: _itemWidths[itemIndex],
        height: _itemHeights[itemIndex],
        child: widget.itemBuilder(context, itemIndex),
      );

      if (!isLast) {
        child = Padding(
          padding: EdgeInsets.only(right: widget.spacing),
          child: child,
        );
      }

      children.add(child);
    }

    Widget row = SizedBox(
      height: rows.rowCrossExtents[rowIndex],
      child: Row(
        mainAxisAlignment: widget.rowAlignment,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );

    final isLastRow = rowIndex == rows.rowCount - 1;
    if (!isLastRow) {
      row = Padding(
        padding: EdgeInsets.only(bottom: widget.runSpacing),
        child: row,
      );
    }

    return row;
  }
}
