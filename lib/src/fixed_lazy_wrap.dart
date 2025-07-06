import 'dart:math';
import 'package:flutter/material.dart';

/// A performant, lazy-loading wrap for grids with fixed item sizes.
/// Optimized: columns/rows are cached per constraints, and rebuilds are minimized.
/// Only visible items are rendered, ideal for massive lists/grids.
class FixedLazyWrap extends StatefulWidget {
  /// {@macro fixed_lazy_wrap}
  const FixedLazyWrap({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.estimatedItemWidth = 320,
    this.estimatedItemHeight = 300,
    this.rowAlignment = MainAxisAlignment.start,
    this.scrollDirection = Axis.vertical,
  })  : assert(itemCount >= 0, 'itemCount must be >= 0'),
        assert(estimatedItemWidth > 0, 'estimatedItemWidth must be > 0'),
        assert(estimatedItemHeight > 0, 'estimatedItemHeight must be > 0');

  /// The total number of items to display.
  final int itemCount;

  /// Called to build each child widget by index.
  final Widget Function(BuildContext, int) itemBuilder;

  /// Horizontal space between items.
  final double spacing;

  /// Vertical space between wrap runs.
  final double runSpacing;

  /// Padding around the wrap content.
  final EdgeInsetsGeometry padding;

  /// Estimated width for each item (required for virtualization).
  final double estimatedItemWidth;

  /// Estimated height for each item (required for virtualization).
  final double estimatedItemHeight;

  /// How items are aligned within a row.
  final MainAxisAlignment rowAlignment;

  /// Scroll direction (vertical or horizontal).
  final Axis scrollDirection;
  @override
  State<FixedLazyWrap> createState() => _FixedLazyWrapState();
}

class _FixedLazyWrapState extends State<FixedLazyWrap> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier(0);

  double _viewportSize = 0;
  int _itemsPerGroup = 1; // Columns if vertical, rows if horizontal
  double _lastAvailableMain = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffsetNotifier.value = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  /// Calculates how many items fit per group (row/col) based on constraints and direction.
  void _updateItemsPerGroup(double availableMain, bool isVertical) {
    if (_lastAvailableMain == availableMain) return;
    _lastAvailableMain = availableMain;
    final itemMain =
        isVertical ? widget.estimatedItemWidth : widget.estimatedItemHeight;
    final spacing = widget.spacing;
    _itemsPerGroup = max(
      1,
      ((availableMain + spacing) / (itemMain + spacing)).floor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final isVertical = widget.scrollDirection == Axis.vertical;
        final availableMain = isVertical
            ? constraints.maxWidth - widget.padding.horizontal
            : constraints.maxHeight - widget.padding.vertical;
        final availableCross =
            isVertical ? constraints.maxHeight : constraints.maxWidth;

        _viewportSize = availableCross;
        _updateItemsPerGroup(availableMain, isVertical);

        // The scroll view and stack do NOT rebuild; only groups do.
        return Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: widget.scrollDirection,
              padding: widget.padding,
              child: ValueListenableBuilder<double>(
                valueListenable: _scrollOffsetNotifier,
                builder: (context, scrollOffset, _) {
                  final visibleGroups = <Widget>[];
                  double mainOffset = 0;
                  double groupSize = 0;

                  var currentIndex = 0;
                  const buffer = 500.0;

                  // Fast skip to the first visible group.
                  final estGroupSize = isVertical
                      ? widget.estimatedItemHeight + widget.runSpacing
                      : widget.estimatedItemWidth + widget.runSpacing;
                  final estStartMain = max(0, scrollOffset - buffer);
                  final estStartGroup = (estStartMain / estGroupSize).floor();

                  currentIndex = estStartGroup * _itemsPerGroup;
                  mainOffset = estStartGroup * estGroupSize;

                  while (currentIndex < widget.itemCount) {
                    final groupItems = <Widget>[];
                    var added = 0;
                    for (;
                        added < _itemsPerGroup &&
                            currentIndex < widget.itemCount;
                        ++added, ++currentIndex) {
                      final isLastInGroup = (added == _itemsPerGroup - 1) ||
                          (currentIndex == widget.itemCount - 1);
                      groupItems.add(
                        Padding(
                          padding: isLastInGroup
                              ? EdgeInsets.zero
                              : (isVertical
                                  ? EdgeInsets.only(right: widget.spacing)
                                  : EdgeInsets.only(bottom: widget.spacing)),
                          child: SizedBox(
                            width: widget.estimatedItemWidth,
                            height: widget.estimatedItemHeight,
                            child: widget.itemBuilder(context, currentIndex),
                          ),
                        ),
                      );
                    }

                    groupSize = isVertical
                        ? widget.estimatedItemHeight
                        : widget.estimatedItemWidth;
                    final groupMainStart = mainOffset;
                    final groupMainEnd = mainOffset + groupSize;
                    final groupCrossStart = isVertical
                        ? widget.padding.resolve(TextDirection.ltr).left
                        : widget.padding.resolve(TextDirection.ltr).top;

                    final shouldRender = groupMainEnd >=
                            scrollOffset - buffer &&
                        groupMainStart <= scrollOffset + _viewportSize + buffer;

                    if (shouldRender) {
                      visibleGroups.add(Positioned(
                        top: isVertical ? groupMainStart : groupCrossStart,
                        left: isVertical ? groupCrossStart : groupMainStart,
                        child: RepaintBoundary(
                          child: SizedBox(
                            width: isVertical ? availableMain : groupSize,
                            height: isVertical ? groupSize : availableMain,
                            child: Flex(
                              direction:
                                  isVertical ? Axis.horizontal : Axis.vertical,
                              mainAxisAlignment: widget.rowAlignment,
                              children: groupItems,
                            ),
                          ),
                        ),
                      ));
                    }

                    mainOffset += estGroupSize;

                    if (mainOffset > scrollOffset + _viewportSize + buffer) {
                      break;
                    }
                  }

                  return SizedBox(
                    width: isVertical ? null : mainOffset,
                    height: isVertical ? mainOffset : null,
                    child: Stack(children: visibleGroups),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
