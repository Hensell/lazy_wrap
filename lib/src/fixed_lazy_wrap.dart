import 'dart:math';
import 'package:flutter/material.dart';

class FixedLazyWrap extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final double estimatedItemWidth;
  final double estimatedItemHeight;
  final MainAxisAlignment rowAlignment;

  const FixedLazyWrap({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.estimatedItemWidth = 320,
    this.estimatedItemHeight = 300,
    this.rowAlignment = MainAxisAlignment.start,
  });

  @override
  State<FixedLazyWrap> createState() => _FixedLazyWrapState();
}

class _FixedLazyWrapState extends State<FixedLazyWrap> {
  final ScrollController _scrollController = ScrollController();

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

        // Salta filas fuera de vista
        while (rowIndex < estStartRow && currentIndex < widget.itemCount) {
          xOffset = 0;
          while (currentIndex < widget.itemCount) {
            if (xOffset + widget.estimatedItemWidth >
                    availableWidth - extraBreakPadding &&
                xOffset > 0) {
              break;
            }
            xOffset += widget.estimatedItemWidth + widget.spacing;
            currentIndex++;
          }
          yOffset += estRowHeight;
          rowIndex++;
        }

        // Renderiza las filas visibles
        while (currentIndex < widget.itemCount) {
          final rowItems = <Widget>[];
          xOffset = 0;
          rowHeight = 0;

          while (currentIndex < widget.itemCount) {
            if (xOffset + widget.estimatedItemWidth >
                    availableWidth - extraBreakPadding &&
                xOffset > 0) {
              break;
            }

            rowItems.add(
              Padding(
                padding: EdgeInsets.only(right: widget.spacing),
                child: SizedBox(
                  width: widget.estimatedItemWidth,
                  height: widget.estimatedItemHeight,
                  child: widget.itemBuilder(context, currentIndex),
                ),
              ),
            );

            xOffset += widget.estimatedItemWidth + widget.spacing;
            rowHeight = max(rowHeight, widget.estimatedItemHeight);
            currentIndex++;
          }

          final rowTop = yOffset;
          final rowBottom = yOffset + rowHeight;

          final shouldRender = rowBottom >= _scrollOffset - buffer &&
              rowTop <= _scrollOffset + _viewportHeight + buffer;

          if (shouldRender) {
            visibleRows.add(Positioned(
              top: rowTop,
              left: widget.padding.resolve(TextDirection.ltr).left,
              child: RepaintBoundary(
                child: SizedBox(
                  width: availableWidth,
                  child: Row(
                    mainAxisAlignment: widget.rowAlignment,
                    children: rowItems,
                  ),
                ),
              ),
            ));
          }

          yOffset += rowHeight + widget.runSpacing;
          rowIndex++;

          if (yOffset > _scrollOffset + _viewportHeight + buffer) break;
        }

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
}
