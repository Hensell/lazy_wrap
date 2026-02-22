import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:lazy_wrap/src/sliver_v3_layout_core.dart';

/// Internal sliver list backed by precomputed row geometry.
class SliverV3RenderList extends SliverMultiBoxAdaptorWidget {
  /// Creates a sliver list that lays out children by row geometry index.
  const SliverV3RenderList({
    required this.rows,
    required super.delegate,
    super.key,
  });

  /// Immutable row geometry for index->offset/extent mapping.
  final SliverV3RowLayout rows;

  @override
  RenderSliverV3RenderList createRenderObject(BuildContext context) {
    return RenderSliverV3RenderList(
      childManager: context as SliverMultiBoxAdaptorElement,
      rows: rows,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverV3RenderList renderObject,
  ) {
    renderObject.rows = rows;
  }
}

/// Render sliver that uses fixed row offsets/extents from [SliverV3RowLayout].
class RenderSliverV3RenderList extends RenderSliverMultiBoxAdaptor {
  /// Creates a render sliver list with external row geometry.
  RenderSliverV3RenderList({
    required super.childManager,
    required SliverV3RowLayout rows,
  }) : _rows = rows;

  SliverV3RowLayout _rows;

  /// Current row geometry cache.
  SliverV3RowLayout get rows => _rows;
  set rows(SliverV3RowLayout value) {
    if (identical(_rows, value)) return;
    _rows = value;
    markNeedsLayout();
  }

  BoxConstraints _getChildConstraints(int index) {
    final extent = _rows.rowCrossExtents[index];
    return constraints.asBoxConstraints(minExtent: extent, maxExtent: extent);
  }

  double _rowStart(int index) => _rows.rowScrollOffsets[index];
  double _rowEnd(int index) => _rowStart(index) + _rows.rowCrossExtents[index];

  @override
  void performLayout() {
    final constraints = this.constraints;
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
    final remainingExtent = constraints.remainingCacheExtent;
    final targetEndScrollOffset = scrollOffset + remainingExtent;
    final rowCount = _rows.rowCount;

    if (rowCount == 0) {
      if (firstChild != null) {
        final firstIndex = indexOf(firstChild!);
        final lastIndex = indexOf(lastChild!);
        collectGarbage(lastIndex - firstIndex + 1, 0);
      }
      geometry = SliverGeometry.zero;
      childManager.didFinishLayout();
      return;
    }

    final window = _rows.windowForBounds(
      startScrollOffset: scrollOffset,
      endScrollOffset: targetEndScrollOffset,
    );

    if (window.isEmpty) {
      if (firstChild != null) {
        final firstIndex = indexOf(firstChild!);
        final lastIndex = indexOf(lastChild!);
        collectGarbage(lastIndex - firstIndex + 1, 0);
      }
      final totalExtent = _rows.totalScrollExtent;
      geometry = SliverGeometry(
        scrollExtent: totalExtent,
        maxPaintExtent: totalExtent,
        hasVisualOverflow: constraints.scrollOffset > 0,
      );
      childManager.didFinishLayout();
      return;
    }

    final firstIndex = window.startRow;
    final targetLastIndex = window.endRowExclusive - 1;

    if (firstChild != null) {
      final leadingGarbage = calculateLeadingGarbage(firstIndex: firstIndex);
      final trailingGarbage = calculateTrailingGarbage(
        lastIndex: targetLastIndex,
      );
      collectGarbage(leadingGarbage, trailingGarbage);
    } else {
      collectGarbage(0, 0);
    }

    if (firstChild == null) {
      if (!addInitialChild(
        index: firstIndex,
        layoutOffset: _rowStart(firstIndex),
      )) {
        final totalExtent = _rows.totalScrollExtent;
        geometry = SliverGeometry(
          scrollExtent: totalExtent,
          maxPaintExtent: totalExtent,
        );
        childManager.didFinishLayout();
        return;
      }
    }

    RenderBox? trailingChildWithLayout;

    for (var index = indexOf(firstChild!) - 1; index >= firstIndex; --index) {
      final child = insertAndLayoutLeadingChild(
        _getChildConstraints(index),
        parentUsesSize: true,
      );
      if (child == null) {
        geometry = SliverGeometry(scrollOffsetCorrection: _rowStart(index));
        return;
      }
      final childParentData =
          child.parentData! as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = _rowStart(index);
      trailingChildWithLayout ??= child;
    }

    if (trailingChildWithLayout == null) {
      firstChild!.layout(
        _getChildConstraints(indexOf(firstChild!)),
        parentUsesSize: true,
      );
      final firstChildParentData =
          firstChild!.parentData! as SliverMultiBoxAdaptorParentData;
      firstChildParentData.layoutOffset = _rowStart(firstIndex);
      trailingChildWithLayout = firstChild;
    }

    for (
      var index = indexOf(trailingChildWithLayout!) + 1;
      index <= targetLastIndex;
      ++index
    ) {
      RenderBox? child = childAfter(trailingChildWithLayout!);
      if (child == null || indexOf(child) != index) {
        child = insertAndLayoutChild(
          _getChildConstraints(index),
          after: trailingChildWithLayout,
          parentUsesSize: true,
        );
        if (child == null) break;
      } else {
        child.layout(_getChildConstraints(index), parentUsesSize: true);
      }

      trailingChildWithLayout = child;
      final childParentData =
          child.parentData! as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = _rowStart(index);
    }

    final lastIndex = indexOf(lastChild!);
    final leadingScrollOffset = _rowStart(firstIndex);
    final trailingScrollOffset = _rowEnd(lastIndex);
    final estimatedMaxScrollOffset = _rows.totalScrollExtent;

    final paintExtent = calculatePaintOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );
    final cacheExtent = calculateCacheOffset(
      constraints,
      from: leadingScrollOffset,
      to: trailingScrollOffset,
    );

    geometry = SliverGeometry(
      scrollExtent: estimatedMaxScrollOffset,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: estimatedMaxScrollOffset,
      hasVisualOverflow:
          lastIndex < rowCount - 1 || constraints.scrollOffset > 0,
    );

    childManager.setDidUnderflow(lastIndex >= rowCount - 1);
    childManager.didFinishLayout();
  }
}
