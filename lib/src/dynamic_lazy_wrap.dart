import 'package:flutter/material.dart';

typedef OnWidgetSizeChange = void Function(Size size);

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

class DynamicLazyWrap extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final MainAxisAlignment rowAlignment;
  final int batchSize;

  const DynamicLazyWrap({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.rowAlignment = MainAxisAlignment.start,
    required this.batchSize,
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
        final availableWidth = constraints.maxWidth - widget.padding.horizontal;

        _maybeLoadMoreIfViewportNotFull(constraints);

        return SingleChildScrollView(
          controller: _controller,
          padding: widget.padding,
          child: _buildRealWrap(context, availableWidth, totalToShow),
        );
      },
    );
  }

  Widget _buildRealWrap(
      BuildContext context, double availableWidth, int itemLimit) {
    List<List<Widget>> rows = [];
    double xOffset = 0;
    List<Widget> currentRow = [];

    for (int i = 0; i < itemLimit; i++) {
      final size = _itemSizes[i];
      Widget child = widget.itemBuilder(context, i);

      if (size == null) {
        child = MeasureSize(
          onChange: (s) => _onItemMeasured(i, s),
          child: child,
        );
      }

      final width = size?.width ?? 0;
      if (xOffset + width > availableWidth && currentRow.isNotEmpty) {
        rows.add(currentRow);
        currentRow = [];
        xOffset = 0;
      }

      currentRow.add(
        Padding(
          padding: EdgeInsets.only(right: widget.spacing),
          child: size != null
              ? SizedBox(width: size.width, height: size.height, child: child)
              : child,
        ),
      );
      xOffset += width + widget.spacing;
    }
    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows.map((row) => Padding(
              padding: EdgeInsets.only(bottom: widget.runSpacing),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisAlignment: widget.rowAlignment,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: row,
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
