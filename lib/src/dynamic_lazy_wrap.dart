import 'dart:math';
import 'package:flutter/material.dart';

/// Signature for callbacks invoked when a widget's size changes.
typedef OnWidgetSizeChange = void Function(Size size);

/// Utility widget that measures its child's size after layout.
class MeasureSize extends StatefulWidget {
  const MeasureSize({
    required this.child,
    required this.onChange,
    super.key,
  });

  final Widget child;
  final OnWidgetSizeChange onChange;

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _lastSize;
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    _scheduleCheck();
    return widget.child;
  }

  void _scheduleCheck() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.size != _lastSize) {
        _lastSize = box.size;
        widget.onChange(box.size);
      }
    });
  }
}

/// Default loading indicator widget.
Widget _defaultLoadingBuilder(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

/// A lazy wrap layout for items of dynamic/unknown size.
///
/// Items are measured invisibly before being displayed to avoid layout jumps.
/// Supports optional fade-in animation for a professional look.
class DynamicLazyWrap extends StatefulWidget {
  const DynamicLazyWrap({
    required this.itemCount,
    required this.itemBuilder,
    super.key,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.rowAlignment = MainAxisAlignment.start,
    this.scrollDirection = Axis.vertical,
    this.cacheExtent = 300,
    this.batchSize = 50,
    this.loadingBuilder,
    this.fadeInItems = true,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.fadeInCurve = Curves.easeOut,
  });

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final MainAxisAlignment rowAlignment;
  final Axis scrollDirection;
  final double cacheExtent;

  /// Number of items to load per batch. Default: 50.
  final int batchSize;

  /// Custom loading indicator builder.
  final Widget Function(BuildContext)? loadingBuilder;

  /// Whether to fade in items when they appear. Default: true.
  final bool fadeInItems;

  /// Duration of fade-in animation. Default: 200ms.
  final Duration fadeInDuration;

  /// Curve for fade-in animation. Default: Curves.easeOut.
  final Curve fadeInCurve;

  @override
  State<DynamicLazyWrap> createState() => _DynamicLazyWrapState();
}

class _DynamicLazyWrapState extends State<DynamicLazyWrap> {
  final ScrollController _scrollController = ScrollController();

  /// Cache of measured item sizes
  final Map<int, Size> _itemSizes = {};

  /// Items that are currently being measured (in Offstage)
  final Set<int> _measuringItems = {};

  /// Items that have completed fade-in animation
  final Set<int> _animatedItems = {};

  /// Current number of items to process (load + measure)
  int _loadedCount = 0;

  /// Whether currently loading more items
  bool _isLoading = false;

  /// Computed rows cache
  List<List<int>>? _rowsCache;
  double? _lastAvailableMain;

  bool get _isVertical => widget.scrollDirection == Axis.vertical;
  bool get _hasMoreItems => _loadedCount < widget.itemCount;

  @override
  void initState() {
    super.initState();
    _loadedCount = widget.batchSize.clamp(0, widget.itemCount);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkFillViewport() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_isLoading || !_hasMoreItems) return;

    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0 ||
        pos.maxScrollExtent < pos.viewportDimension) {
      _loadMore();
    }
  }

  @override
  void didUpdateWidget(DynamicLazyWrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount != oldWidget.itemCount) {
      _loadedCount = _loadedCount.clamp(0, widget.itemCount);
      _rowsCache = null;
    }
  }

  void _onScroll() {
    if (_isLoading || !_hasMoreItems) return;

    final pos = _scrollController.position;
    final threshold = pos.maxScrollExtent - widget.cacheExtent;

    if (pos.pixels >= threshold) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoading || !_hasMoreItems) return;

    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 16), () {
      if (!mounted) return;

      setState(() {
        _loadedCount = (_loadedCount + widget.batchSize).clamp(
          0,
          widget.itemCount,
        );
        _isLoading = false;
        _rowsCache = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final pos = _scrollController.position;
        if (pos.maxScrollExtent <= pos.viewportDimension && _hasMoreItems) {
          _loadMore();
        }
      });
    });
  }

  void _onItemMeasured(int index, Size size) {
    if (!mounted) return;
    setState(() {
      _itemSizes[index] = size;
      _measuringItems.remove(index);
      _rowsCache = null;
    });
  }

  /// Get items that need to be measured (loaded but not yet measured)
  List<int> _getItemsToMeasure() {
    final toMeasure = <int>[];
    for (var i = 0; i < _loadedCount; i++) {
      if (!_itemSizes.containsKey(i) && !_measuringItems.contains(i)) {
        toMeasure.add(i);
        _measuringItems.add(i);
      }
    }
    return toMeasure;
  }

  double _getItemMainSize(int index) {
    final size = _itemSizes[index];
    if (size == null) return 0; // Unmeasured items have 0 size
    return _isVertical ? size.width : size.height;
  }

  double _getItemCrossSize(int index) {
    final size = _itemSizes[index];
    if (size == null) return 0;
    return _isVertical ? size.height : size.width;
  }

  /// Compute rows from ONLY measured items
  List<List<int>> _computeRows(double availableMain) {
    if (_rowsCache != null && _lastAvailableMain == availableMain) {
      return _rowsCache!;
    }

    final rows = <List<int>>[];
    var currentRow = <int>[];
    var currentRowMain = 0.0;

    // Only include items that have been measured
    for (var i = 0; i < _loadedCount; i++) {
      if (!_itemSizes.containsKey(i)) continue; // Skip unmeasured

      final itemMain = _getItemMainSize(i);
      final neededSpace = currentRow.isEmpty
          ? itemMain
          : widget.spacing + itemMain;

      if (currentRowMain + neededSpace > availableMain &&
          currentRow.isNotEmpty) {
        rows.add(currentRow);
        currentRow = [i];
        currentRowMain = itemMain;
      } else {
        currentRow.add(i);
        currentRowMain += neededSpace;
      }
    }

    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }

    _rowsCache = rows;
    _lastAvailableMain = availableMain;
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    // Get items that need measuring
    final itemsToMeasure = _getItemsToMeasure();

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = widget.padding.resolve(TextDirection.ltr);
        final availableMain = _isVertical
            ? constraints.maxWidth - padding.horizontal
            : constraints.maxHeight - padding.vertical;

        final rows = _computeRows(availableMain);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkFillViewport();
        });

        return Stack(
          children: [
            // Offstage measurement area
            if (itemsToMeasure.isNotEmpty)
              Offstage(
                child: Column(
                  children: itemsToMeasure.map((index) {
                    return MeasureSize(
                      onChange: (size) => _onItemMeasured(index, size),
                      child: widget.itemBuilder(context, index),
                    );
                  }).toList(),
                ),
              ),

            // Visible scroll view
            CustomScrollView(
              controller: _scrollController,
              scrollDirection: widget.scrollDirection,
              cacheExtent: widget.cacheExtent,
              slivers: [
                SliverPadding(
                  padding: widget.padding,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, rowIndex) {
                        if (rowIndex >= rows.length) return null;
                        return _buildRow(
                          context,
                          rows[rowIndex],
                          rowIndex,
                          rows.length,
                        );
                      },
                      childCount: rows.length,
                    ),
                  ),
                ),
                if (_isLoading ||
                    _measuringItems.isNotEmpty ||
                    (_hasMoreItems && rows.isNotEmpty))
                  SliverToBoxAdapter(
                    child: (_isLoading || _measuringItems.isNotEmpty)
                        ? (widget.loadingBuilder?.call(context) ??
                              _defaultLoadingBuilder(context))
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<int> itemIndices,
    int rowIndex,
    int totalRows,
  ) {
    var maxCross = 0.0;
    for (final i in itemIndices) {
      maxCross = max(maxCross, _getItemCrossSize(i));
    }

    final children = <Widget>[];

    for (var idx = 0; idx < itemIndices.length; idx++) {
      final itemIndex = itemIndices[idx];
      final size = _itemSizes[itemIndex]!;
      final isLast = idx == itemIndices.length - 1;

      Widget child = SizedBox(
        width: size.width,
        height: size.height,
        child: widget.itemBuilder(context, itemIndex),
      );

      // Apply fade-in animation
      if (widget.fadeInItems && !_animatedItems.contains(itemIndex)) {
        child = _FadeInWidget(
          duration: widget.fadeInDuration,
          curve: widget.fadeInCurve,
          onComplete: () {
            _animatedItems.add(itemIndex);
          },
          child: child,
        );
      }

      if (!isLast) {
        child = Padding(
          padding: _isVertical
              ? EdgeInsets.only(right: widget.spacing)
              : EdgeInsets.only(bottom: widget.spacing),
          child: child,
        );
      }

      children.add(child);
    }

    Widget row = Flex(
      direction: _isVertical ? Axis.horizontal : Axis.vertical,
      mainAxisAlignment: widget.rowAlignment,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    if (maxCross > 0) {
      row = SizedBox(
        height: _isVertical ? maxCross : null,
        width: _isVertical ? null : maxCross,
        child: row,
      );
    }

    final isLastRow = rowIndex == totalRows - 1;
    if (!isLastRow) {
      row = Padding(
        padding: _isVertical
            ? EdgeInsets.only(bottom: widget.runSpacing)
            : EdgeInsets.only(right: widget.runSpacing),
        child: row,
      );
    }

    return row;
  }
}

/// Widget that fades in when first built
class _FadeInWidget extends StatefulWidget {
  const _FadeInWidget({
    required this.child,
    required this.duration,
    required this.curve,
    this.onComplete,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onComplete;

  @override
  State<_FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<_FadeInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );
    _controller.forward().then((_) {
      widget.onComplete?.call();
    }); // Intentional fire-and-forget for animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}
