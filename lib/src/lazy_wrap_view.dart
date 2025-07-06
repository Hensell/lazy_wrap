import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap.dart';
import 'package:lazy_wrap/src/fixed_lazy_wrap.dart';

/// [LazyWrap] is a performant scrollable wrap widget for Flutter,
/// combining the layout of [Wrap] with the lazy rendering of [ListView].
///
/// Use [LazyWrap.fixed] for items with fixed sizes. Use [LazyWrap.dynamic]
/// for items with variable sizes.
/// Supports both vertical and horizontal scrolling.
///
/// Example:
/// ```dart
/// LazyWrap.fixed(
///   itemCount: 30,
///   itemBuilder: (ctx, i) => Card(child: Text('$i')),
///   estimatedItemWidth: 120,
///   estimatedItemHeight: 100,
///   scrollDirection: Axis.horizontal,
/// )
/// ```
///
/// ```dart
/// LazyWrap.dynamic(
///   itemCount: 300,
///   itemBuilder: (ctx, i) => SomeVariableWidget(i),
///   scrollDirection: Axis.vertical,
/// )
/// ```
class LazyWrap extends StatelessWidget {
  /// Dynamic mode: For lists with variable sized widgets.
  /// Automatically measures sizes. Slightly heavier, but flexible.
  const LazyWrap.dynamic({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.batchSize = 500,
    this.rowAlignment = MainAxisAlignment.start,
    this.scrollDirection = Axis.vertical,
  })  : isDynamic = true,
        estimatedItemWidth = null,
        estimatedItemHeight = null,
        assert(batchSize != null && batchSize > 0,
            'batchSize must be provided and > 0 for dynamic mode');

  /// Fixed mode: For grids or lists where all items are about the same size.
  /// Most efficient and smooth.
  const LazyWrap.fixed({
    required this.itemCount,
    required this.itemBuilder,
    required this.estimatedItemWidth,
    required this.estimatedItemHeight,
    super.key,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.rowAlignment = MainAxisAlignment.start,
    this.scrollDirection = Axis.vertical,
  })  : isDynamic = false,
        batchSize = null,
        assert(estimatedItemWidth != null && estimatedItemWidth > 0,
            'estimatedItemWidth must be provided and > 0 for fixed mode'),
        assert(estimatedItemHeight != null && estimatedItemHeight > 0,
            'estimatedItemHeight must be provided and > 0 for fixed mode');

  /// Number of items to build in the list.
  final int itemCount;

  /// Function to build each item, given context and index.
  final Widget Function(BuildContext, int) itemBuilder;

  /// Horizontal spacing between items. Default: 8.
  final double spacing;

  /// Vertical spacing between rows. Default: 8.
  final double runSpacing;

  /// Outer padding for the wrap. Default: EdgeInsets.zero.
  final EdgeInsetsGeometry padding;

  /// Only used in fixed mode. Estimated width of each item (required).
  final double? estimatedItemWidth;

  /// Only used in fixed mode. Estimated height of each item (required).
  final double? estimatedItemHeight;

  /// Whether to use dynamic measurement mode (auto-detected).
  final bool isDynamic;

  /// How to align items in a row. Default: MainAxisAlignment.start.
  final MainAxisAlignment rowAlignment;

  /// Only used in dynamic mode. How many items to lazily render per batch.
  final int? batchSize;

  /// Scroll direction (vertical or horizontal). Default: Axis.vertical.
  final Axis scrollDirection;

  @override
  Widget build(BuildContext context) {
    if (isDynamic) {
      // Dynamic mode: Uses auto-measurement and batch rendering.
      return DynamicLazyWrap(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        spacing: spacing,
        runSpacing: runSpacing,
        padding: padding,
        rowAlignment: rowAlignment,
        batchSize: batchSize!,
        scrollDirection: scrollDirection,
      );
    } else {
      // Fixed mode: Fastest for grids or cards of predictable size.
      return FixedLazyWrap(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        spacing: spacing,
        runSpacing: runSpacing,
        padding: padding,
        estimatedItemWidth: estimatedItemWidth!,
        estimatedItemHeight: estimatedItemHeight!,
        rowAlignment: rowAlignment,
        scrollDirection: scrollDirection,
      );
    }
  }
}
