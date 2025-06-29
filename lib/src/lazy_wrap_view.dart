import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap.dart';
import 'package:lazy_wrap/src/fixed_lazy_wrap.dart';

class LazyWrap extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final double? estimatedItemWidth;
  final double? estimatedItemHeight;
  final bool isDynamic;
  final MainAxisAlignment rowAlignment;
  final int? batchSize;

  const LazyWrap.fixed({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    required this.estimatedItemWidth,
    required this.estimatedItemHeight,
    this.rowAlignment = MainAxisAlignment.start,
  })  : isDynamic = false,
        batchSize = null;

  const LazyWrap.dynamic({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.batchSize = 500,
    this.rowAlignment = MainAxisAlignment.start,
  })  : isDynamic = true,
        estimatedItemWidth = null,
        estimatedItemHeight = null;

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
        batchSize: batchSize!,
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
      );
    }
  }
}
