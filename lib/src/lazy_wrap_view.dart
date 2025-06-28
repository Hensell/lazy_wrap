import 'package:flutter/material.dart';

class LazyWrap extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double spacing;
  final double runSpacing;
  final double itemWidth;
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
    this.itemWidth = 160,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.controller,
    this.shrinkWrap = false,
    this.rowAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final crossAxisCount = ((totalWidth + spacing) / (itemWidth + spacing))
            .floor()
            .clamp(1, itemCount);
        return ListView.builder(
          padding: padding,
          physics: physics,
          controller: controller,
          shrinkWrap: shrinkWrap,
          itemCount: (itemCount / crossAxisCount).ceil(),
          itemBuilder: (context, rowIndex) {
            final children = <Widget>[];
            final startIndex = rowIndex * crossAxisCount;
            final endIndex = (startIndex + crossAxisCount).clamp(0, itemCount);

            for (int i = startIndex; i < endIndex; i++) {
              children.add(
                Padding(
                  padding: EdgeInsets.only(
                    right: i < endIndex - 1 ? spacing : 0,
                  ),
                  child: SizedBox(
                    width: itemWidth,
                    child: itemBuilder(context, i),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: runSpacing),
              child: Row(
                mainAxisAlignment: rowAlignment, // ← importante
                children: children,
              ),
            );
          },
        );
      },
    );
  }
}
