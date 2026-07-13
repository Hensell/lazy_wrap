import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/src/sliver_v3_layout_core.dart';

void main() {
  group('SliverV3RowLayout.compute', () {
    test('packs rows and offsets deterministically', () {
      final widths = <double>[50, 50, 50, 40];
      final heights = <double>[10, 20, 30, 12];

      final layout = SliverV3RowLayout.compute(
        itemCount: widths.length,
        availableMainAxisExtent: 120,
        spacing: 10,
        runSpacing: 5,
        itemWidth: (index) => widths[index],
        itemHeight: (index) => heights[index],
      );

      expect(layout.rowCount, 2);
      expect(layout.rowStarts, [0, 2]);
      expect(layout.rowLengths, [2, 2]);
      expect(layout.rowCrossExtents, [20, 30]);
      expect(layout.rowScrollOffsets, [0, 25]);
      expect(layout.totalScrollExtent, 55);
    });

    test('clamps negative item sizes to zero', () {
      final widths = <double>[-10, 20, -5];
      final heights = <double>[10, -4, 8];

      final layout = SliverV3RowLayout.compute(
        itemCount: widths.length,
        availableMainAxisExtent: 50,
        spacing: 5,
        runSpacing: 2,
        itemWidth: (index) => widths[index],
        itemHeight: (index) => heights[index],
      );

      expect(layout.rowCount, 1);
      expect(layout.rowStarts, [0]);
      expect(layout.rowLengths, [3]);
      expect(layout.rowCrossExtents, [10]);
      expect(layout.rowScrollOffsets, [0]);
      expect(layout.totalScrollExtent, 10);
    });

    test('returns empty layout for empty or invalid viewport width', () {
      final emptyByCount = SliverV3RowLayout.compute(
        itemCount: 0,
        availableMainAxisExtent: 100,
        spacing: 8,
        runSpacing: 8,
        itemWidth: (_) => 10,
        itemHeight: (_) => 10,
      );
      final emptyByMainAxis = SliverV3RowLayout.compute(
        itemCount: 10,
        availableMainAxisExtent: 0,
        spacing: 8,
        runSpacing: 8,
        itemWidth: (_) => 10,
        itemHeight: (_) => 10,
      );

      expect(emptyByCount.rowCount, 0);
      expect(emptyByCount.totalScrollExtent, 0);
      expect(emptyByMainAxis.rowCount, 0);
      expect(emptyByMainAxis.totalScrollExtent, 0);
    });

    test('preserves sub-pixel precision beyond the Float32 range', () {
      const itemCount = 20000;
      const itemExtent = 1000.25;
      final layout = SliverV3RowLayout.compute(
        itemCount: itemCount,
        availableMainAxisExtent: 1,
        spacing: 0,
        runSpacing: 0,
        itemWidth: (_) => 1,
        itemHeight: (_) => itemExtent,
      );

      expect(layout.rowCrossExtents, isA<Float64List>());
      expect(layout.rowScrollOffsets, isA<Float64List>());
      expect(
        layout.rowScrollOffsets.last,
        (itemCount - 1) * itemExtent,
      );
      expect(layout.totalScrollExtent, itemCount * itemExtent);
    });

    test('asserts when spacing is negative', () {
      expect(
        () => SliverV3RowLayout.compute(
          itemCount: 1,
          availableMainAxisExtent: 100,
          spacing: -1,
          runSpacing: 0,
          itemWidth: (_) => 10,
          itemHeight: (_) => 10,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('SliverV3RowLayout.visibleWindow', () {
    late SliverV3RowLayout layout;

    setUp(() {
      layout = SliverV3RowLayout.compute(
        itemCount: 6,
        availableMainAxisExtent: 60,
        spacing: 0,
        runSpacing: 2,
        itemWidth: (_) => 60,
        itemHeight: (_) => 10,
      );
    });

    test('returns expected rows for viewport without cache', () {
      final window = layout.visibleWindow(
        scrollOffset: 13,
        viewportMainAxisExtent: 15,
      );

      expect(window.startRow, 1);
      expect(window.endRowExclusive, 3);
      expect(window.length, 2);
      expect(window.isEmpty, isFalse);
    });

    test('expands visible rows when cache extent is provided', () {
      final window = layout.visibleWindow(
        scrollOffset: 13,
        viewportMainAxisExtent: 15,
        cacheExtent: 10,
      );

      expect(window.startRow, 0);
      expect(window.endRowExclusive, 4);
      expect(window.length, 4);
    });

    test('returns empty window outside content bounds', () {
      final window = layout.visibleWindow(
        scrollOffset: 1000,
        viewportMainAxisExtent: 20,
      );

      expect(window.isEmpty, isTrue);
      expect(window.startRow, 0);
      expect(window.endRowExclusive, 0);
    });

    test('returns expected rows for explicit bounds', () {
      final window = layout.windowForBounds(
        startScrollOffset: 13,
        endScrollOffset: 29,
      );

      expect(window.startRow, 1);
      expect(window.endRowExclusive, 3);
      expect(window.length, 2);
    });
  });
}
