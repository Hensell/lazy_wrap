import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/src/sliver_v3_layout_core.dart';
import 'package:lazy_wrap/src/sliver_v3_render_list.dart';

void main() {
  testWidgets('consumes viewport paint extent inside a run-spacing gap', (
    tester,
  ) async {
    final controller = ScrollController();
    final rows = SliverV3RowLayout.compute(
      itemCount: 2,
      availableMainAxisExtent: 100,
      spacing: 0,
      runSpacing: 500,
      itemWidth: (_) => 100,
      itemHeight: (_) => 10,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: CustomScrollView(
              controller: controller,
              cacheExtent: 0,
              slivers: [
                SliverV3RenderList(
                  rows: rows,
                  delegate: SliverChildBuilderDelegate(
                    (_, index) => ColoredBox(
                      color: Colors.blue,
                      child: Text('Row $index'),
                    ),
                    childCount: 2,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ColoredBox(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    controller.jumpTo(100);
    await tester.pump();

    final renderSliver = tester.renderObject<RenderSliverV3RenderList>(
      find.byType(SliverV3RenderList),
    );
    expect(renderSliver.geometry!.paintExtent, 100);
    expect(renderSliver.geometry!.cacheExtent, 100);
  });
}
