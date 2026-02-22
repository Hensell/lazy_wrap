import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap_sliver_v3.dart';

void main() {
  group('DynamicLazyWrapSliverV3 (spike)', () {
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
                height: 260,
                child: DynamicLazyWrapSliverV3(
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
              child: DynamicLazyWrapSliverV3(
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

    testWidgets('promotes startup cache extent after first user scroll', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 220,
              child: DynamicLazyWrapSliverV3(
                itemCount: 200,
                cacheExtent: 420,
                controller: controller,
                itemWidthBuilder: (_) => 80,
                itemHeightBuilder: (_) => 50,
                itemBuilder: (context, index) {
                  return DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.cyan),
                    child: Center(child: Text('Item $index')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final scrollViewBefore = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView).first,
      );
      expect(scrollViewBefore.cacheExtent, 300);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();

      final scrollViewAfter = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView).first,
      );
      expect(scrollViewAfter.cacheExtent, 420);
      expect(tester.takeException(), isNull);
    });

    testWidgets('can jump to last items', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 280,
              child: DynamicLazyWrapSliverV3(
                itemCount: 500,
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

    testWidgets('loads more rows when batch mode is enabled', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: DynamicLazyWrapSliverV3(
                itemCount: 300,
                batchSize: 40,
                loadThreshold: 150,
                controller: controller,
                itemWidthBuilder: (_) => 80,
                itemHeightBuilder: (_) => 36,
                itemBuilder: (context, index) {
                  return DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.purple),
                    child: Center(child: Text('Item $index')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Item 120'), findsNothing);

      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -280));
        await tester.pumpAndSettle();
        if (find.text('Item 120').evaluate().isNotEmpty) break;
      }

      expect(find.text('Item 120'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'fills viewport automatically before user scroll in batch mode',
      (
        tester,
      ) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 240,
                child: DynamicLazyWrapSliverV3(
                  itemCount: 50,
                  batchSize: 2,
                  loadThreshold: 100,
                  controller: controller,
                  itemWidthBuilder: (_) => 300,
                  itemHeightBuilder: (_) => 40,
                  itemBuilder: (context, index) {
                    return DecoratedBox(
                      decoration: const BoxDecoration(color: Colors.teal),
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
        expect(controller.position.maxScrollExtent, greaterThan(0));
        expect(find.text('Item 3'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
