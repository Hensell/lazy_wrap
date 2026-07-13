import 'dart:math';
import 'dart:typed_data';

/// Immutable row layout cache for a wrap-like vertical sliver.
///
/// This model is framework-agnostic and is intended to back a future
/// `RenderSliver` implementation where visibility decisions must be cheap.
class SliverV3RowLayout {
  SliverV3RowLayout._({
    required this.rowStarts,
    required this.rowLengths,
    required this.rowCrossExtents,
    required this.rowScrollOffsets,
    required this.totalScrollExtent,
  });

  /// Creates an empty row layout.
  factory SliverV3RowLayout.empty() {
    return SliverV3RowLayout._(
      rowStarts: Int32List(0),
      rowLengths: Int32List(0),
      rowCrossExtents: Float64List(0),
      rowScrollOffsets: Float64List(0),
      totalScrollExtent: 0,
    );
  }

  /// Computes row packing for [itemCount] items using deterministic sizes.
  ///
  /// Item width/height values are clamped to `>= 0`.
  factory SliverV3RowLayout.compute({
    required int itemCount,
    required double availableMainAxisExtent,
    required double spacing,
    required double runSpacing,
    required double Function(int index) itemWidth,
    required double Function(int index) itemHeight,
  }) {
    assert(spacing >= 0, 'spacing must be >= 0');
    assert(runSpacing >= 0, 'runSpacing must be >= 0');

    if (itemCount <= 0 || availableMainAxisExtent <= 0) {
      return SliverV3RowLayout.empty();
    }

    final starts = <int>[];
    final lengths = <int>[];
    final crossExtents = <double>[];
    final scrollOffsets = <double>[];

    var rowStart = 0;
    var rowLength = 0;
    var rowMain = 0.0;
    var rowCross = 0.0;
    var currentRowOffset = 0.0;

    for (var i = 0; i < itemCount; i++) {
      final rawWidth = itemWidth(i);
      final rawHeight = itemHeight(i);
      final width = rawWidth < 0 ? 0.0 : rawWidth;
      final height = rawHeight < 0 ? 0.0 : rawHeight;
      final neededMain = rowLength == 0 ? width : spacing + width;

      if (rowLength > 0 && rowMain + neededMain > availableMainAxisExtent) {
        starts.add(rowStart);
        lengths.add(rowLength);
        crossExtents.add(rowCross);
        scrollOffsets.add(currentRowOffset);

        currentRowOffset += rowCross + runSpacing;
        rowStart = i;
        rowLength = 0;
        rowMain = 0;
        rowCross = 0;
      }

      rowLength++;
      rowMain += rowLength == 1 ? width : spacing + width;
      rowCross = max<double>(rowCross, height);
    }

    if (rowLength > 0) {
      starts.add(rowStart);
      lengths.add(rowLength);
      crossExtents.add(rowCross);
      scrollOffsets.add(currentRowOffset);
    }

    final rowCount = starts.length;
    final totalScrollExtent = rowCount == 0
        ? 0.0
        : scrollOffsets[rowCount - 1] + crossExtents[rowCount - 1];

    return SliverV3RowLayout._(
      rowStarts: Int32List.fromList(starts),
      rowLengths: Int32List.fromList(lengths),
      rowCrossExtents: Float64List.fromList(crossExtents),
      rowScrollOffsets: Float64List.fromList(scrollOffsets),
      totalScrollExtent: totalScrollExtent,
    );
  }

  /// Index of first item in each row.
  final Int32List rowStarts;

  /// Number of items in each row.
  final Int32List rowLengths;

  /// Cross-axis extent (row height for vertical scrolling) of each row.
  final Float64List rowCrossExtents;

  /// Scroll offset (main axis) where each row starts.
  final Float64List rowScrollOffsets;

  /// Full scroll extent of the packed content.
  final double totalScrollExtent;

  /// Total number of rows.
  int get rowCount => rowStarts.length;

  /// Returns a visible row window for the given viewport and cache.
  SliverV3RowWindow visibleWindow({
    required double scrollOffset,
    required double viewportMainAxisExtent,
    double cacheExtent = 0,
  }) {
    if (rowCount == 0 || viewportMainAxisExtent <= 0) {
      return const SliverV3RowWindow.empty();
    }

    final normalizedCache = cacheExtent < 0 ? 0.0 : cacheExtent;
    final rawStartOffset = scrollOffset - normalizedCache;
    final startOffset = rawStartOffset < 0 ? 0.0 : rawStartOffset;
    final rawEndOffset =
        scrollOffset + viewportMainAxisExtent + normalizedCache;
    final endOffset = rawEndOffset < startOffset ? startOffset : rawEndOffset;

    return windowForBounds(
      startScrollOffset: startOffset,
      endScrollOffset: endOffset,
    );
  }

  /// Returns rows overlapping the half-open range `[startScrollOffset, endScrollOffset)`.
  SliverV3RowWindow windowForBounds({
    required double startScrollOffset,
    required double endScrollOffset,
  }) {
    if (rowCount == 0) return const SliverV3RowWindow.empty();

    final rawStart = startScrollOffset < 0 ? 0.0 : startScrollOffset;
    final rawEnd = endScrollOffset < rawStart ? rawStart : endScrollOffset;

    final startRow = _firstRowEndingAfter(rawStart);
    if (startRow >= rowCount) {
      return const SliverV3RowWindow.empty();
    }

    final endRowExclusive = _firstRowStartingAtOrAfter(rawEnd);
    final clampedEnd = max(startRow + 1, min(rowCount, endRowExclusive));

    return SliverV3RowWindow(
      startRow: startRow,
      endRowExclusive: clampedEnd,
    );
  }

  int _firstRowEndingAfter(double target) {
    var low = 0;
    var high = rowCount;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      final rowEnd = rowScrollOffsets[mid] + rowCrossExtents[mid];
      if (rowEnd > target) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  int _firstRowStartingAtOrAfter(double target) {
    var low = 0;
    var high = rowCount;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (rowScrollOffsets[mid] >= target) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }
}

/// Half-open row range `[startRow, endRowExclusive)`.
class SliverV3RowWindow {
  /// Creates a row window.
  const SliverV3RowWindow({
    required this.startRow,
    required this.endRowExclusive,
  });

  /// Empty row window.
  const SliverV3RowWindow.empty() : startRow = 0, endRowExclusive = 0;

  /// First visible row index (inclusive).
  final int startRow;

  /// Last visible row index (exclusive).
  final int endRowExclusive;

  /// Number of rows included in this window.
  int get length => endRowExclusive - startRow;

  /// Whether this window has no rows.
  bool get isEmpty => length <= 0;
}
