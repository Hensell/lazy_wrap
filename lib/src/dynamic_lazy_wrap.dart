import 'package:flutter/material.dart';

typedef OnWidgetSizeChange = void Function(Size size);

/// Utility widget that notifies on child size change (used for measuring dynamic widgets).
class MeasureSize extends StatefulWidget {
  final Widget child;
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    super.key,
    required this.child,
    required this.onChange,
  });

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contextBox = context.findRenderObject();
      if (contextBox is RenderBox) {
        widget.onChange(contextBox.size);
      }
    });
    return widget.child;
  }
}

/// A lazy-loading, wrap-style layout for items of dynamic/unknown size.
/// Supports both vertical and horizontal scroll directions.
/// Only renders widgets that are currently visible or close to the viewport.
class DynamicLazyWrap extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final MainAxisAlignment rowAlignment;
  final int batchSize;

  /// Main scroll direction. If vertical, builds rows; if horizontal, builds columns.
  final Axis scrollDirection;

  const DynamicLazyWrap({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.rowAlignment = MainAxisAlignment.start,
    required this.batchSize,
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<DynamicLazyWrap> createState() => _DynamicLazyWrapState();
}

class _DynamicLazyWrapState extends State<DynamicLazyWrap> {
  final Map<int, Size> _itemSizes = {};
  int _currentMax = 0;
  late ScrollController _controller;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _currentMax = widget.batchSize;
    _controller = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Trigger loading more when near the end of the scroll in main axis.
    if (_controller.position.pixels >=
            _controller.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _maybeLoadMore();
    }
  }

  void _maybeLoadMore() {
    if (_currentMax < widget.itemCount) {
      setState(() {
        _isLoadingMore = true;
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() {
          _currentMax =
              (_currentMax + widget.batchSize).clamp(0, widget.itemCount);
          _isLoadingMore = false;
        });
      });
    }
  }

  void _maybeLoadMoreIfViewportNotFull(BoxConstraints constraints) {
    if (_currentMax < widget.itemCount && !_isLoadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          final maxScroll = _controller.position.maxScrollExtent;
          final viewport = _controller.position.viewportDimension;
          if (maxScroll <= 0 || maxScroll < viewport / 3) {
            _maybeLoadMore();
          }
        }
      });
    }
  }

  void _onItemMeasured(int index, Size size) {
    if (_itemSizes[index] == size) return;
    setState(() {
      _itemSizes[index] = size;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalToShow = _currentMax.clamp(0, widget.itemCount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = widget.scrollDirection == Axis.vertical;
        final availableMain = isVertical
            ? constraints.maxWidth - widget.padding.horizontal
            : constraints.maxHeight - widget.padding.vertical;

        _maybeLoadMoreIfViewportNotFull(constraints);

        return SingleChildScrollView(
          controller: _controller,
          padding: widget.padding,
          scrollDirection: widget.scrollDirection,
          child: _buildWrap(context, availableMain, totalToShow, isVertical),
        );
      },
    );
  }

  /// Groups widgets into rows (if vertical) or columns (if horizontal),
  /// measuring each item's true size, and only rendering what's in the viewport.
  Widget _buildWrap(BuildContext context, double availableMain, int itemLimit,
      bool isVertical) {
    // For vertical: group = row, for horizontal: group = column.
    List<List<Widget>> groups = [];
    double mainOffset = 0;
    List<Widget> currentGroup = [];

    for (int i = 0; i < itemLimit; i++) {
      final size = _itemSizes[i];
      Widget child = widget.itemBuilder(context, i);

      if (size == null) {
        child = MeasureSize(
          onChange: (s) => _onItemMeasured(i, s),
          child: child,
        );
      }

      final mainSize = isVertical ? size?.width ?? 0 : size?.height ?? 0;

      if (mainOffset + mainSize > availableMain && currentGroup.isNotEmpty) {
        groups.add(currentGroup);
        currentGroup = [];
        mainOffset = 0;
      }

      currentGroup.add(
        Padding(
          padding: isVertical
              ? EdgeInsets.only(right: widget.spacing)
              : EdgeInsets.only(bottom: widget.spacing),
          child: size != null
              ? SizedBox(
                  width: size.width,
                  height: size.height,
                  child: child,
                )
              : child,
        ),
      );
      mainOffset += mainSize + widget.spacing;
    }
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return Flex(
      direction: isVertical ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...groups.map((group) => Padding(
              padding: isVertical
                  ? EdgeInsets.only(bottom: widget.runSpacing)
                  : EdgeInsets.only(right: widget.runSpacing),
              child: SingleChildScrollView(
                scrollDirection: isVertical ? Axis.horizontal : Axis.vertical,
                clipBehavior: Clip.hardEdge,
                physics: const NeverScrollableScrollPhysics(),
                child: Flex(
                  direction: isVertical ? Axis.horizontal : Axis.vertical,
                  mainAxisAlignment: widget.rowAlignment,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: group,
                ),
              ),
            )),
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
