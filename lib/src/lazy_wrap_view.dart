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

  const LazyWrap({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.estimatedItemWidth = 120,
    this.estimatedItemHeight = 100,
  });

  @override
  State<LazyWrap> createState() => _LazyWrapState();
}

class _LazyWrapState extends State<LazyWrap> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, Size> _itemSizes = {};
  final Map<int, double> _rowHeights = {};
  double _viewportHeight = 0;
  double _scrollOffset = 0;
  bool _scheduledUpdate = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  void _scheduleRebuild() {
    if (_scheduledUpdate) return;
    _scheduledUpdate = true;
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _scheduledUpdate = false;
        });
      }
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
        _viewportHeight = constraints.maxHeight;
        final width = constraints.maxWidth - widget.padding.horizontal;

        final itemsPerRow =
            (width / (widget.estimatedItemWidth + widget.spacing))
                .floor()
                .clamp(1, widget.itemCount);
        final rowCount = (widget.itemCount / itemsPerRow).ceil();

        final defaultRowHeight = widget.estimatedItemHeight + widget.runSpacing;

        double totalHeight = 0;
        final List<double> rowOffsets = List.filled(rowCount, 0);

        for (int i = 0; i < rowCount; i++) {
          final rowHeight = _rowHeights[i] ?? defaultRowHeight;
          rowOffsets[i] = totalHeight;
          totalHeight += rowHeight + widget.runSpacing;
        }

        int firstVisibleRow = 0;
        for (int i = 0; i < rowCount; i++) {
          if (rowOffsets[i] + (_rowHeights[i] ?? defaultRowHeight) >=
              _scrollOffset) {
            firstVisibleRow = i;
            break;
          }
        }

        const rowBuffer = 2;
        final visibleRowCount =
            (_viewportHeight / defaultRowHeight).ceil() + rowBuffer;
        final startRow = (firstVisibleRow - rowBuffer).clamp(0, rowCount);
        final endRow = (firstVisibleRow + visibleRowCount).clamp(0, rowCount);

        final rows = <Widget>[];

        for (int rowIndex = startRow; rowIndex < endRow; rowIndex++) {
          final startIndex = rowIndex * itemsPerRow;
          final endIndex =
              (startIndex + itemsPerRow).clamp(0, widget.itemCount);

          double rowHeight = 0;
          final children = <Widget>[];

          for (int i = startIndex; i < endIndex; i++) {
            final size = _itemSizes[i];
            if (size != null) {
              rowHeight = max(rowHeight, size.height);
            }

            children.add(
              Padding(
                padding: EdgeInsets.only(
                    right: i == endIndex - 1 ? 0 : widget.spacing),
                child: MeasureSize(
                  onChange: (size) {
                    if (_itemSizes[i] != size) {
                      _itemSizes[i] = size;
                      _scheduleRebuild();
                    }
                  },
                  child: widget.itemBuilder(context, i),
                ),
              ),
            );
          }

          if (rowHeight == 0) {
            rowHeight = widget.estimatedItemHeight;
          }

          if (_rowHeights[rowIndex] != rowHeight) {
            _rowHeights[rowIndex] = rowHeight;
          }

          final topOffset = rowOffsets[rowIndex];

          rows.add(
            Positioned(
              top: topOffset,
              left: widget.padding.resolve(TextDirection.ltr).left,
              child: RepaintBoundary(
                child: Row(children: children),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          controller: _scrollController,
          padding: widget.padding,
          child: SizedBox(
            height: totalHeight,
            child: Stack(children: rows),
          ),
        );
      },
    );
  }
}
