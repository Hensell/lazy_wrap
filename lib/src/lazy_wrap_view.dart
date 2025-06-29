import 'dart:math';
import 'package:flutter/material.dart';
import 'measure_size.dart';

class LazyWrap extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final double estimatedItemWidth;
  final double estimatedItemHeight;
  final bool useDynamicMeasurement;
  final MainAxisAlignment rowAlignment;

  const LazyWrap({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.estimatedItemWidth = 120,
    this.estimatedItemHeight = 100,
    this.useDynamicMeasurement = true,
    this.rowAlignment = MainAxisAlignment.start,
  });

  @override
  State<LazyWrap> createState() => _LazyWrapState();
}

class _LazyWrapState extends State<LazyWrap> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, Size> _itemSizes = {};
  final Map<int, ValueNotifier<List<_LazyItemMeta>>> _rows = {};

  double _scrollOffset = 0;
  double _viewportHeight = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final availableWidth = constraints.maxWidth - widget.padding.horizontal;
        _viewportHeight = constraints.maxHeight;

        final List<Widget> visibleRows = [];
        final Set<int> visibleRowIndices = {};
        double yOffset = 0;
        double rowHeight = 0;
        double xOffset = 0;

        int rowIndex = 0;
        int currentIndex = 0;
        const buffer = 500.0;
        const extraBreakPadding = 17.0;

        final estRowHeight = widget.estimatedItemHeight + widget.runSpacing;
        final estStartY = max(0, _scrollOffset - buffer);
        final estStartRow = (estStartY / estRowHeight).floor();

        while (rowIndex < estStartRow && currentIndex < widget.itemCount) {
          xOffset = 0;

          while (currentIndex < widget.itemCount) {
            final size = _getSize(currentIndex);

            if (xOffset + size.width > availableWidth - extraBreakPadding &&
                xOffset > 0) {
              break;
            }

            xOffset += size.width + widget.spacing;
            currentIndex++;
          }

          yOffset += estRowHeight;
          rowIndex++;
        }

        while (currentIndex < widget.itemCount) {
          final rowItems = <_LazyItemMeta>[];
          xOffset = 0;
          rowHeight = 0;

          while (currentIndex < widget.itemCount) {
            final size = _getSize(currentIndex);

            if (xOffset + size.width > availableWidth - extraBreakPadding &&
                xOffset > 0) {
              break;
            }

            rowItems.add(
              _LazyItemMeta(
                index: currentIndex,
                offset: xOffset,
                size: size,
              ),
            );

            xOffset += size.width + widget.spacing;
            rowHeight = max(rowHeight, size.height);
            currentIndex++;
          }

          final rowTop = yOffset;
          final rowBottom = yOffset + rowHeight;

          final shouldRender = rowBottom >= _scrollOffset - buffer &&
              rowTop <= _scrollOffset + _viewportHeight + buffer;

          if (shouldRender) {
            visibleRowIndices.add(rowIndex);

            final rowNotifier = _rows.putIfAbsent(
              rowIndex,
              () => ValueNotifier(rowItems),
            );
            rowNotifier.value = rowItems;

            visibleRows.add(Positioned(
              top: rowTop,
              left: widget.padding.resolve(TextDirection.ltr).left,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: rowNotifier,
                  builder: (_, __) {
                    return SizedBox(
                      width:
                          availableWidth, // ✅ ancho fijo para centrado sin overflow
                      child: Row(
                        mainAxisAlignment: widget.rowAlignment,
                        children: rowNotifier.value.map((meta) {
                          final child = widget.itemBuilder(context, meta.index);

                          if (!widget.useDynamicMeasurement) {
                            return Padding(
                              padding: EdgeInsets.only(right: widget.spacing),
                              child: SizedBox(
                                width: widget.estimatedItemWidth,
                                height: widget.estimatedItemHeight,
                                child: child,
                              ),
                            );
                          }

                          return Padding(
                            padding: EdgeInsets.only(right: widget.spacing),
                            child: MeasureSize(
                              onChange: (measured) {
                                if (_itemSizes[meta.index] != measured) {
                                  _itemSizes[meta.index] = measured;
                                  rowNotifier.value =
                                      List.from(rowNotifier.value);
                                }
                              },
                              child: child,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ));
          }

          yOffset += rowHeight + widget.runSpacing;
          rowIndex++;

          if (yOffset > _scrollOffset + _viewportHeight + buffer) break;
        }

        _rows.removeWhere((key, _) => !visibleRowIndices.contains(key));

        return SingleChildScrollView(
          controller: _scrollController,
          padding: widget.padding,
          child: SizedBox(
            height: yOffset,
            child: Stack(children: visibleRows),
          ),
        );
      },
    );
  }

  Size _getSize(int index) {
    return widget.useDynamicMeasurement
        ? _itemSizes[index] ??
            Size(widget.estimatedItemWidth, widget.estimatedItemHeight)
        : Size(widget.estimatedItemWidth, widget.estimatedItemHeight);
  }
}

class _LazyItemMeta {
  final int index;
  final double offset;
  final Size size;

  _LazyItemMeta({
    required this.index,
    required this.offset,
    required this.size,
  });
}
