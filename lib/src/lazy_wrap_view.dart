import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap.dart';
import 'package:lazy_wrap/src/fixed_lazy_wrap.dart';

/// [LazyWrap] is a performant scrollable wrap widget for Flutter,
/// combining the layout of [Wrap] with the lazy rendering of [ListView].
///
/// Use [LazyWrap.fixed] for items with fixed sizes (best performance).
/// Use [LazyWrap.dynamic] for items with variable sizes (no layout jumps).
class LazyWrap extends StatelessWidget {
  /// Dynamic mode: For lists with variable sized widgets.
  ///
  /// Items are measured invisibly before display to eliminate layout jumps.
  /// Supports optional fade-in animation.
  const LazyWrap.dynamic({
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
  }) : isDynamic = true,
       estimatedItemWidth = null,
       estimatedItemHeight = null;

  /// Fixed mode: For grids or lists where all items are about the same size.
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
    this.cacheExtent = 300,
  }) : isDynamic = false,
       batchSize = null,
       loadingBuilder = null,
       fadeInItems = false,
       fadeInDuration = null,
       fadeInCurve = null,
       assert(
         estimatedItemWidth != null && estimatedItemWidth > 0,
         'estimatedItemWidth must be provided and > 0 for fixed mode',
       ),
       assert(
         estimatedItemHeight != null && estimatedItemHeight > 0,
         'estimatedItemHeight must be provided and > 0 for fixed mode',
       );

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final double? estimatedItemWidth;
  final double? estimatedItemHeight;
  final bool isDynamic;
  final MainAxisAlignment rowAlignment;
  final Axis scrollDirection;
  final double cacheExtent;

  /// Only for dynamic mode. Items per batch. Default: 50.
  final int? batchSize;

  /// Only for dynamic mode. Custom loading indicator.
  final Widget Function(BuildContext)? loadingBuilder;

  /// Only for dynamic mode. Whether items fade in. Default: true.
  final bool fadeInItems;

  /// Only for dynamic mode. Fade-in duration. Default: 200ms.
  final Duration? fadeInDuration;

  /// Only for dynamic mode. Fade-in curve. Default: Curves.easeOut.
  final Curve? fadeInCurve;

  @override
  Widget build(BuildContext context) {
    if (isDynamic) {
      return DynamicLazyWrap(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        spacing: spacing,
        runSpacing: runSpacing,
        padding: padding,
        rowAlignment: rowAlignment,
        scrollDirection: scrollDirection,
        cacheExtent: cacheExtent,
        batchSize: batchSize ?? 50,
        loadingBuilder: loadingBuilder,
        fadeInItems: fadeInItems,
        fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 200),
        fadeInCurve: fadeInCurve ?? Curves.easeOut,
      );
    } else {
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
        cacheExtent: cacheExtent,
      );
    }
  }
}
