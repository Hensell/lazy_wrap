import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap.dart';
import 'package:lazy_wrap/src/fixed_lazy_wrap.dart';
import 'package:lazy_wrap/src/lazy_wrap_engine.dart';

/// A performant scrollable wrap widget for Flutter, combining the layout
/// behavior of [Wrap] with the lazy rendering of [ListView].
///
/// Use [LazyWrap.fixed] for items with known, uniform sizes (best performance).
/// Use [LazyWrap.dynamic] for items with variable or unknown sizes.
///
/// Both modes support vertical and horizontal scrolling via [scrollDirection].
class LazyWrap extends StatelessWidget {
  /// Creates a [LazyWrap] for items with variable sizes.
  ///
  /// Items are measured invisibly before display to eliminate layout jumps.
  /// Supports optional fade-in animation via [fadeInItems].
  ///
  /// {@tool snippet}
  /// ```dart
  /// LazyWrap.dynamic(
  ///   itemCount: 1000,
  ///   itemBuilder: (context, index) => Chip(label: Text('Tag $index')),
  ///   fadeInItems: true,
  ///   batchSize: 50,
  /// )
  /// ```
  /// {@end-tool}
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
    this.controller,
    this.loadThreshold = 300,
    this.measureBatchSize = 15,
    this.engine = LazyWrapEngine.offstageV1,
    this.itemWidthBuilder,
    this.itemHeightBuilder,
  }) : isDynamic = true,
       assert(itemCount >= 0, 'itemCount must be >= 0'),
       assert(spacing >= 0, 'spacing must be >= 0'),
       assert(runSpacing >= 0, 'runSpacing must be >= 0'),
       assert(batchSize == null || batchSize > 0, 'batchSize must be > 0'),
       assert(
         measureBatchSize == null || measureBatchSize > 0,
         'measureBatchSize must be > 0',
       ),
       assert(cacheExtent >= 0, 'cacheExtent must be >= 0'),
       assert(
         loadThreshold == null || loadThreshold >= 0,
         'loadThreshold must be >= 0',
       ),
       assert(
         engine != LazyWrapEngine.sliverV2 || scrollDirection == Axis.vertical,
         'scrollDirection must be Axis.vertical for engine sliverV2',
       ),
       assert(
         engine != LazyWrapEngine.sliverV2 ||
             (itemWidthBuilder != null && itemHeightBuilder != null),
         'itemWidthBuilder and itemHeightBuilder are required for engine '
         'sliverV2',
       ),
       estimatedItemWidth = null,
       estimatedItemHeight = null;

  /// Creates a [LazyWrap] for items with known, uniform sizes.
  ///
  /// This mode provides the best performance because it can calculate
  /// exact row layouts without measuring each item.
  ///
  /// {@tool snippet}
  /// ```dart
  /// LazyWrap.fixed(
  ///   itemCount: 10000,
  ///   estimatedItemWidth: 120,
  ///   estimatedItemHeight: 100,
  ///   itemBuilder: (context, index) => ProductCard(index),
  /// )
  /// ```
  /// {@end-tool}
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
       controller = null,
       loadThreshold = null,
       measureBatchSize = null,
       engine = null,
       itemWidthBuilder = null,
       itemHeightBuilder = null,
       assert(
         estimatedItemWidth != null && estimatedItemWidth > 0,
         'estimatedItemWidth must be provided and > 0 for fixed mode',
       ),
       assert(
         estimatedItemHeight != null && estimatedItemHeight > 0,
         'estimatedItemHeight must be provided and > 0 for fixed mode',
       );

  /// Total number of items to display.
  final int itemCount;

  /// Builder function called to create each item widget.
  final Widget Function(BuildContext, int) itemBuilder;

  /// Horizontal spacing between items within a row. Default: 8.
  final double spacing;

  /// Vertical spacing between rows. Default: 8.
  final double runSpacing;

  /// Padding around the entire wrap content. Default: [EdgeInsets.zero].
  final EdgeInsetsGeometry padding;

  /// Width of each item (required for fixed mode, ignored in dynamic mode).
  final double? estimatedItemWidth;

  /// Height of each item (required for fixed mode, ignored in dynamic mode).
  final double? estimatedItemHeight;

  /// Whether using dynamic measurement mode.
  final bool isDynamic;

  /// Alignment of items within each row. Default: [MainAxisAlignment.start].
  final MainAxisAlignment rowAlignment;

  /// Scroll direction. Default: [Axis.vertical].
  final Axis scrollDirection;

  /// Pixels to pre-render beyond the viewport for smoother scrolling.
  /// Default: 300.
  final double cacheExtent;

  /// Items to load per batch (dynamic mode only). Default: 50.
  final int? batchSize;

  /// Custom loading indicator (dynamic mode only).
  final Widget Function(BuildContext)? loadingBuilder;

  /// Whether items fade in when first appearing (dynamic mode only).
  /// Default: true.
  final bool fadeInItems;

  /// Duration of fade-in animation (dynamic mode only). Default: 200ms.
  final Duration? fadeInDuration;

  /// Curve of fade-in animation (dynamic mode only). Default: [Curves.easeOut].
  final Curve? fadeInCurve;

  /// Optional external scroll controller (dynamic mode only).
  final ScrollController? controller;

  /// Distance from the end at which to trigger loading (dynamic mode only).
  /// Default: 300.
  final double? loadThreshold;

  /// Max items measured per frame in Offstage (dynamic mode only).
  /// Default: 15.
  final int? measureBatchSize;

  /// Dynamic engine selection (dynamic mode only).
  final LazyWrapEngine? engine;

  /// Deterministic width builder used by `sliverV2` (dynamic mode only).
  final double Function(int)? itemWidthBuilder;

  /// Deterministic height builder used by `sliverV2` (dynamic mode only).
  final double Function(int)? itemHeightBuilder;

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
        controller: controller,
        loadThreshold: loadThreshold ?? 300,
        measureBatchSize: measureBatchSize ?? 15,
        engine: engine ?? LazyWrapEngine.offstageV1,
        itemWidthBuilder: itemWidthBuilder,
        itemHeightBuilder: itemHeightBuilder,
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
