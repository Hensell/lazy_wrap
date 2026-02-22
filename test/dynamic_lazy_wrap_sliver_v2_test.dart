import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap_sliver_v2.dart';

void main() {
  group('DynamicLazyWrapSliverV2 (prototype)', () {
    testWidgets('applies spacing, runSpacing and padding in vertical mode', (
      tester,
    ) async {
      const spacing = 10.0;
      const runSpacing = 12.0;
      const padding = EdgeInsets.all(10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 240,
                child: DynamicLazyWrapSliverV2(
                  itemCount: 12,
                  spacing: spacing,
                  runSpacing: runSpacing,
                  padding: padding,
                  itemWidthBuilder: (_) => 80,
                  itemHeightBuilder: (_) => 40,
                  itemBuilder: (context, index) {
                    return ColoredBox(
                      color: Colors.blue,
                      child: Center(child: Text('Item $index')),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hasSliverPadding = find
          .byWidgetPredicate(
            (widget) => widget is SliverPadding && widget.padding == padding,
          )
          .evaluate()
          .isNotEmpty;
      expect(hasSliverPadding, isTrue);

      final item0TopLeft = tester.getTopLeft(find.text('Item 0'));
      final item1TopLeft = tester.getTopLeft(find.text('Item 1'));
      final item2TopLeft = tester.getTopLeft(find.text('Item 2'));

      expect(item1TopLeft.dx - item0TopLeft.dx, closeTo(80 + spacing, 1.0));
      expect(item2TopLeft.dy - item0TopLeft.dy, closeTo(40 + runSpacing, 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('supports vertical scrolling', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 220,
              child: DynamicLazyWrapSliverV2(
                itemCount: 80,
                controller: controller,
                itemWidthBuilder: (_) => 80,
                itemHeightBuilder: (_) => 50,
                itemBuilder: (context, index) {
                  return DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.green),
                    child: Center(child: Text('Item $index')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(controller.hasClients, isTrue);
      expect(controller.offset, 0);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('can jump to last items without batch paging', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 280,
              child: DynamicLazyWrapSliverV2(
                itemCount: 500,
                batchSize: 8,
                controller: controller,
                itemWidthBuilder: (_) => 72,
                itemHeightBuilder: (_) => 36,
                itemBuilder: (context, index) {
                  return DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.orange),
                    child: Center(child: Text('Item $index')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(controller.hasClients, isTrue);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(find.text('Item 499'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
