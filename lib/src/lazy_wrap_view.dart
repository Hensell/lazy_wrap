import 'package:flutter/material.dart';
import 'package:lazy_wrap/src/utils/row_builder.dart';
import 'measure_size.dart';

class LazyWrap extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool shrinkWrap;
  final MainAxisAlignment rowAlignment;

  const LazyWrap({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 8,
    this.runSpacing = 8,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.controller,
    this.shrinkWrap = false,
    this.rowAlignment = MainAxisAlignment.start,
  });

  @override
  State<LazyWrap> createState() => _LazyWrapState();
}

class _LazyWrapState extends State<LazyWrap> {
  final _itemWidths = <int, double>{};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = constraints.maxWidth - widget.padding.horizontal;
        final rowGroups = <List<int>>[];
        int current = 0;

        while (current < widget.itemCount) {
          final row = <int>[];

          final rowGroups = buildRowGroups(
            itemCount: widget.itemCount,
            maxWidth: effectiveWidth,
            spacing: widget.spacing,
            itemWidths: _itemWidths,
          );

          if (row.isEmpty) {
            row.add(current);
            current++;
          }

          rowGroups.add(row);
        }

        return ListView.builder(
          padding: widget.padding,
          physics: widget.physics,
          controller: widget.controller,
          shrinkWrap: widget.shrinkWrap,
          itemCount: rowGroups.length,
          itemBuilder: (context, rowIndex) {
            final row = rowGroups[rowIndex];
            final children = <Widget>[];

            for (int i = 0; i < row.length; i++) {
              final index = row[i];
              final isLast = i == row.length - 1;

              children.add(
                Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : widget.spacing),
                  child: MeasureSize(
                    onChange: (size) {
                      if (size != null && size.width != _itemWidths[index]) {
                        setState(() => _itemWidths[index] = size.width);
                      }
                    },
                    child: widget.itemBuilder(context, index),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: widget.runSpacing),
              child: SizedBox(
                width: effectiveWidth,
                child: Row(
                  mainAxisAlignment: widget.rowAlignment,
                  children: children,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
