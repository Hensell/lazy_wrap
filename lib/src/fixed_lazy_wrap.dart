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
    this.cacheExtent = 300,
  })  : assert(itemCount >= 0, 'itemCount must be >= 0'),
        assert(estimatedItemWidth > 0, 'estimatedItemWidth must be > 0'),
        assert(estimatedItemHeight > 0, 'estimatedItemHeight must be > 0'),
        assert(cacheExtent >= 0, 'cacheExtent must be >= 0');

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

  /// Cache extent for pre-rendering items before they become visible.
  /// Default is 300 pixels. Higher values = smoother scroll but more memory.
  final double cacheExtent;

  @override
  State<FixedLazyWrap> createState() => _FixedLazyWrapState();
}

class _FixedLazyWrapState extends State<FixedLazyWrap> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier(0);

  double _viewportSize = 0;
  int _itemsPerGroup = 1;
  double _lastAvailableMain = -1;
  double _lastMainAxisExtent = 0;
  bool _pendingScrollFix = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

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

  /// Adjusts scroll position if out of valid range.
  void _scheduleScrollFix(double maxScrollExtent) {
    if (_pendingScrollFix) return;
    _pendingScrollFix = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollFix = false;
      if (!mounted || !_scrollController.hasClients) return;

      if (_scrollController.offset > maxScrollExtent) {
        _scrollController.jumpTo(maxScrollExtent);
      }
      _scrollOffsetNotifier.value = _scrollController.offset;
    });
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

        // Calculate total groups and scroll extent
        final groupCount = (widget.itemCount / _itemsPerGroup).ceil();
        final estGroupSize = isVertical
            ? widget.estimatedItemHeight + widget.runSpacing
            : widget.estimatedItemWidth + widget.runSpacing;
        final mainAxisExtent =
            max(0, groupCount * estGroupSize - widget.runSpacing).toDouble();

        // Schedule scroll fix if extent changed
        if (_lastMainAxisExtent != mainAxisExtent) {
          _lastMainAxisExtent = mainAxisExtent;
          _scheduleScrollFix(max(0, mainAxisExtent - _viewportSize));
        }

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: widget.scrollDirection,
          padding: widget.padding,
          child: ValueListenableBuilder<double>(
            valueListenable: _scrollOffsetNotifier,
            builder: (context, scrollOffset, _) {
              return _buildVisibleGroups(
                context: context,
                scrollOffset: scrollOffset,
                isVertical: isVertical,
                availableMain: availableMain,
                estGroupSize: estGroupSize,
                mainAxisExtent: mainAxisExtent,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildVisibleGroups({
    required BuildContext context,
    required double scrollOffset,
    required bool isVertical,
    required double availableMain,
    required double estGroupSize,
    required double mainAxisExtent,
  }) {
    final visibleGroups = <Widget>[];
    final buffer = widget.cacheExtent;

    // Calculate starting group based on scroll position
    final estStartMain = max(0, scrollOffset - buffer).toDouble();
    final estStartGroup = (estStartMain / estGroupSize).floor();
    var currentIndex = estStartGroup * _itemsPerGroup;
    var mainOffset = estStartGroup * estGroupSize;

    final groupSize =
        isVertical ? widget.estimatedItemHeight : widget.estimatedItemWidth;
    final groupCrossStart = isVertical
        ? widget.padding.resolve(TextDirection.ltr).left
        : widget.padding.resolve(TextDirection.ltr).top;

    while (currentIndex < widget.itemCount) {
      final groupItems = <Widget>[];
      var added = 0;

      // Build items for this group
      while (added < _itemsPerGroup && currentIndex < widget.itemCount) {
        final itemIndex = currentIndex;
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
              child: widget.itemBuilder(context, itemIndex),
            ),
          ),
        );
        added++;
        currentIndex++;
      }

      final groupMainStart = mainOffset;
      final groupMainEnd = mainOffset + groupSize;

      // Only render if visible within buffer
      final shouldRender = groupMainEnd >= scrollOffset - buffer &&
          groupMainStart <= scrollOffset + _viewportSize + buffer;

      if (shouldRender) {
        visibleGroups.add(
          Positioned(
            top: isVertical ? groupMainStart : groupCrossStart,
            left: isVertical ? groupCrossStart : groupMainStart,
            child: RepaintBoundary(
              child: SizedBox(
                width: isVertical ? availableMain : groupSize,
                height: isVertical ? groupSize : availableMain,
                child: Flex(
                  direction: isVertical ? Axis.horizontal : Axis.vertical,
                  mainAxisAlignment: widget.rowAlignment,
                  children: groupItems,
                ),
              ),
            ),
          ),
        );
      }

      mainOffset += estGroupSize;

      // Stop if past visible range
      if (mainOffset > scrollOffset + _viewportSize + buffer) {
        break;
      }
    }

    return SizedBox(
      width: isVertical ? null : mainAxisExtent,
      height: isVertical ? mainAxisExtent : null,
      child: Stack(children: visibleGroups),
    );
  }
}
