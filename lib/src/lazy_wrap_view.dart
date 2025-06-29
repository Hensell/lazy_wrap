import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap.dart';
import 'package:lazy_wrap/src/fixed_lazy_wrap.dart';

/// Widget público, solo decide qué implementación usar.
class LazyWrap extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final double estimatedItemWidth;
  final double estimatedItemHeight;
  final bool useDynamicMeasurement;
  final MainAxisAlignment rowAlignment;
  final int batchSize;
  const LazyWrap({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.estimatedItemWidth = 320,
    this.estimatedItemHeight = 300,
    this.useDynamicMeasurement = false,
    this.rowAlignment = MainAxisAlignment.start,
    this.batchSize = 500,
  });

  @override
  Widget build(BuildContext context) {
    if (useDynamicMeasurement) {
      return DynamicLazyWrap(
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          spacing: spacing,
          runSpacing: runSpacing,
          padding: padding,
          rowAlignment: rowAlignment,
          batchSize: batchSize);
    } else {
      return FixedLazyWrap(
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        spacing: spacing,
        runSpacing: runSpacing,
        padding: padding,
        estimatedItemWidth: estimatedItemWidth,
        estimatedItemHeight: estimatedItemHeight,
        rowAlignment: rowAlignment,
      );
    }
  }
}
