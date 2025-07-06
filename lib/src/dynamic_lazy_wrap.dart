import 'package:flutter/material.dart';

/// Signature for callbacks invoked when a widget's size changes.
///
/// Receives the new [Size] of the widget.
typedef OnWidgetSizeChange = void Function(Size size);

/// Utility widget that notifies on child size change (used for measuring dynamic widgets).
class MeasureSize extends StatefulWidget {
  /// {@macro measure_size}
  const MeasureSize({
    required this.child,
    required this.onChange,
    super.key,
  });

  /// The widget whose size will be measured.
  final Widget child;

  /// Callback invoked with the new size whenever [child] changes dimensions.
  final OnWidgetSizeChange onChange;

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
  /// {@macro dynamic_lazy_wrap}
  const DynamicLazyWrap({
    required this.itemCount,
    required this.itemBuilder,
    required this.batchSize,
    super.key,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.rowAlignment = MainAxisAlignment.start,
    this.scrollDirection = Axis.vertical,
  });

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

  /// How items are aligned within a row.
  final MainAxisAlignment rowAlignment;

  /// Number of items to render ahead of the viewport (batch size).
  final int batchSize;

  /// Scroll direction (vertical or horizontal).
  final Axis scrollDirection;
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
    final groups = <List<Widget>>[];
    double mainOffset = 0;
    var currentGroup = <Widget>[];

    for (var i = 0; i < itemLimit; i++) {
      final size = _itemSizes[i];
      var child = widget.itemBuilder(context, i);

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
