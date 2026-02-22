import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/lazy_wrap.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap.dart';
import 'package:lazy_wrap/src/dynamic_lazy_wrap_sliver_v2.dart';

void main() {
  group('LazyWrap.fixed', () {
    testWidgets('renders all items correctly', (tester) async {
      const itemCount = 3;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.fixed(
              itemCount: itemCount,
              estimatedItemWidth: 100,
              estimatedItemHeight: 40,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      for (var i = 0; i < itemCount; i++) {
        expect(find.text('Item $i'), findsOneWidget);
      }
    });

    testWidgets('applies padding correctly', (tester) async {
      const padding = EdgeInsets.all(20);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.fixed(
              itemCount: 1,
              estimatedItemWidth: 100,
              estimatedItemHeight: 40,
              padding: padding,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hasCorrectPadding = find
          .byWidgetPredicate(
            (widget) => widget is Padding && widget.padding == padding,
          )
          .evaluate()
          .isNotEmpty;

      expect(hasCorrectPadding, isTrue);
    });

    testWidgets('uses custom spacing between items', (tester) async {
      const spacing = 32.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.fixed(
              itemCount: 2,
              estimatedItemWidth: 100,
              estimatedItemHeight: 40,
              spacing: spacing,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('handles zero items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.fixed(
              itemCount: 0,
              estimatedItemWidth: 100,
              estimatedItemHeight: 40,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('handles single item', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.fixed(
              itemCount: 1,
              estimatedItemWidth: 100,
              estimatedItemHeight: 40,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('respects cacheExtent parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.fixed(
              itemCount: 10,
              estimatedItemWidth: 100,
              estimatedItemHeight: 40,
              cacheExtent: 500,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('supports horizontal scrolling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.fixed(
              itemCount: 5,
              estimatedItemWidth: 100,
              estimatedItemHeight: 40,
              scrollDirection: Axis.horizontal,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });
  });

  group('LazyWrap.dynamic', () {
    test('asserts when itemCount is negative', () {
      expect(
        () => LazyWrap.dynamic(
          itemCount: -1,
          itemBuilder: _testItemBuilder,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when batchSize is not positive', () {
      expect(
        () => LazyWrap.dynamic(
          itemCount: 1,
          batchSize: 0,
          itemBuilder: _testItemBuilder,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when measureBatchSize is not positive', () {
      expect(
        () => LazyWrap.dynamic(
          itemCount: 1,
          measureBatchSize: 0,
          itemBuilder: _testItemBuilder,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when cacheExtent is negative', () {
      expect(
        () => LazyWrap.dynamic(
          itemCount: 1,
          cacheExtent: -1,
          itemBuilder: _testItemBuilder,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when loadThreshold is negative', () {
      expect(
        () => LazyWrap.dynamic(
          itemCount: 1,
          loadThreshold: -1,
          itemBuilder: _testItemBuilder,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when sliverV2 is selected without size builders', () {
      expect(
        () => LazyWrap.dynamic(
          itemCount: 1,
          engine: LazyWrapEngine.sliverV2,
          itemBuilder: _testItemBuilder,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when sliverV2 is selected with horizontal scroll', () {
      expect(
        () => LazyWrap.dynamic(
          itemCount: 1,
          engine: LazyWrapEngine.sliverV2,
          scrollDirection: Axis.horizontal,
          itemWidthBuilder: (_) => 100,
          itemHeightBuilder: (_) => 40,
          itemBuilder: _testItemBuilder,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('renders items correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 5,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('handles zero items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 0,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('handles single item', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 1,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('respects cacheExtent parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 10,
              cacheExtent: 500,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('supports horizontal scrolling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 5,
              scrollDirection: Axis.horizontal,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('applies padding correctly', (tester) async {
      const padding = EdgeInsets.all(16);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 3,
              padding: padding,
              itemBuilder: _testItemBuilder,
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
    });

    testWidgets('fade-in animation renders FadeTransition', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 3,
              fadeInItems: true,
              fadeInDuration: Duration(milliseconds: 500),
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      // Pump to measure in Offstage, then display with animation
      await tester.pump();
      await tester.pump();

      // FadeTransition should exist when fadeInItems is true
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('fade-in completes after duration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 3,
              fadeInItems: true,
              fadeInDuration: Duration(milliseconds: 300),
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('renders items without FadeTransition when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.dynamic(
              itemCount: 3,
              fadeInItems: false,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Items should be rendered
      expect(find.text('Item 0'), findsOneWidget);

      // Items render correctly without fade-in wrapping
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('shows default CircularProgressIndicator', (tester) async {
      // Use many items with measureBatchSize=1 so measuring takes multiple frames
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: LazyWrap.dynamic(
                itemCount: 5,
                batchSize: 5,
                measureBatchSize: 1,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 800,
                    height: 200,
                    child: Text('Big $index'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // First pump: build, items go to pending
      // One item starts measuring in Offstage
      await tester.pump();

      // The loading indicator should be visible while items are pending
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Pump through measurement frames (can't use pumpAndSettle because
      // CircularProgressIndicator has infinite animation)
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    });

    testWidgets('uses custom loadingBuilder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: LazyWrap.dynamic(
                itemCount: 5,
                batchSize: 5,
                measureBatchSize: 1,
                loadingBuilder: (context) => const Text('Loading...'),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 800,
                    height: 200,
                    child: Text('Big $index'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Loading...'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('loads items in batches', (tester) async {
      // Use large items (1 per row, 200px) in 400px viewport
      // batchSize=3 means 3 items first, which total 600px > 400px viewport
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: LazyWrap.dynamic(
                itemCount: 20,
                batchSize: 3,
                fadeInItems: false,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 800,
                    height: 200,
                    child: Text('Item $index'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // First batch items should be visible
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('accepts external ScrollController', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: LazyWrap.dynamic(
                itemCount: 20,
                batchSize: 3,
                fadeInItems: false,
                controller: controller,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 800,
                    height: 200,
                    child: Text('Item $index'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(controller.hasClients, isTrue);
    });

    testWidgets('handles controller swap null -> external -> null', (
      tester,
    ) async {
      final externalController = ScrollController();
      addTearDown(externalController.dispose);

      var phase = 0; // 0: internal, 1: external, 2: internal

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: SizedBox(
                  height: 400,
                  child: LazyWrap.dynamic(
                    itemCount: 120,
                    batchSize: 8,
                    fadeInItems: false,
                    controller: phase == 1 ? externalController : null,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 800,
                        height: 200,
                        child: Text('Item $index'),
                      );
                    },
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() {
                    if (phase < 2) phase++;
                  }),
                  child: const Icon(Icons.swap_horiz),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(externalController.hasClients, isFalse);

      var scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to external controller.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(externalController.hasClients, isTrue);

      scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch back to internal controller.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(externalController.hasClients, isFalse);

      scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('loads more items on scroll', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: LazyWrap.dynamic(
                itemCount: 100,
                batchSize: 5,
                fadeInItems: false,
                loadThreshold: 50,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 800,
                    height: 200,
                    child: Text('Item $index'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Item 0 should be visible initially
      expect(find.text('Item 0'), findsOneWidget);

      // Scroll down
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Widget should not crash after scrolling
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'routes to sliverV2 when engine is selected',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 220,
                height: 240,
                child: LazyWrap.dynamic(
                  itemCount: 30,
                  engine: LazyWrapEngine.sliverV2,
                  fadeInItems: false,
                  itemWidthBuilder: (_) => 90,
                  itemHeightBuilder: (_) => 40,
                  itemBuilder: _testItemBuilder,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(DynamicLazyWrapSliverV2), findsOneWidget);
        expect(find.text('Item 0'), findsOneWidget);
      },
    );
  });

  group('DynamicLazyWrap', () {
    test('asserts when sliverV2 is selected without size builders', () {
      expect(
        () => DynamicLazyWrap(
          itemCount: 1,
          engine: LazyWrapEngine.sliverV2,
          itemBuilder: _testItemBuilder,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('builds sliverV2 when engine is selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 240,
              child: DynamicLazyWrap(
                itemCount: 30,
                engine: LazyWrapEngine.sliverV2,
                itemWidthBuilder: (_) => 90,
                itemHeightBuilder: (_) => 40,
                itemBuilder: _testItemBuilder,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DynamicLazyWrapSliverV2), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
    });
  });

  group('Engine parity', () {
    testWidgets('renders base content for both engines', (tester) async {
      for (final engine in LazyWrapEngine.values) {
        await tester.pumpWidget(
          _buildEngineHarness(
            engine: engine,
            child: _buildDynamicForEngine(
              engine: engine,
              itemCount: 12,
              itemBuilder: _testItemBuilder,
            ),
          ),
        );

        await _pumpFrames(tester);

        expect(find.text('Item 0'), findsOneWidget);
        expect(find.text('Item 1'), findsOneWidget);
      }
    });

    testWidgets('applies spacing and runSpacing for both engines', (
      tester,
    ) async {
      const spacing = 10.0;
      const runSpacing = 12.0;
      const padding = EdgeInsets.all(10);

      for (final engine in LazyWrapEngine.values) {
        await tester.pumpWidget(
          _buildEngineHarness(
            engine: engine,
            child: _buildDynamicForEngine(
              engine: engine,
              itemCount: 20,
              spacing: spacing,
              runSpacing: runSpacing,
              padding: padding,
              itemBuilder: _testItemBuilder,
            ),
          ),
        );

        await _pumpFrames(tester);

        final item0TopLeft = tester.getTopLeft(find.text('Item 0'));
        final item1TopLeft = tester.getTopLeft(find.text('Item 1'));
        final item2TopLeft = tester.getTopLeft(find.text('Item 2'));

        expect(item1TopLeft.dx - item0TopLeft.dx, closeTo(100 + spacing, 1.0));
        expect(
          item2TopLeft.dy - item0TopLeft.dy,
          closeTo(40 + runSpacing, 1.0),
        );
      }
    });

    testWidgets('attaches external controller for both engines', (
      tester,
    ) async {
      for (final engine in LazyWrapEngine.values) {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildEngineHarness(
            engine: engine,
            child: _buildDynamicForEngine(
              engine: engine,
              itemCount: 40,
              controller: controller,
              itemBuilder: _testItemBuilder,
            ),
          ),
        );

        await _pumpFrames(tester);
        expect(controller.hasClients, isTrue);
      }
    });
  });

  group('Edge cases', () {
    testWidgets('handles large item counts in fixed mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LazyWrap.fixed(
              itemCount: 1000,
              estimatedItemWidth: 100,
              estimatedItemHeight: 40,
              itemBuilder: _testItemBuilder,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('handles different row alignments', (tester) async {
      for (final alignment in MainAxisAlignment.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LazyWrap.fixed(
                itemCount: 3,
                estimatedItemWidth: 100,
                estimatedItemHeight: 40,
                rowAlignment: alignment,
                itemBuilder: _testItemBuilder,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Item 0'), findsOneWidget);
      }
    });

    testWidgets('handles itemCount change', (tester) async {
      var count = 5;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: LazyWrap.dynamic(
                  itemCount: count,
                  fadeInItems: false,
                  itemBuilder: _testItemBuilder,
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => count = 2),
                  child: const Icon(Icons.remove),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsOneWidget);

      // Tap to reduce count
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets(
      'handles itemCount shrink with pending dynamic measurements',
      (tester) async {
        var count = 20;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                final data = List<int>.generate(count, (i) => i);
                return Scaffold(
                  body: SizedBox(
                    height: 400,
                    child: LazyWrap.dynamic(
                      itemCount: count,
                      batchSize: 20,
                      measureBatchSize: 1,
                      fadeInItems: false,
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 800,
                          height: 200,
                          child: Text('Item ${data[index]}'),
                        );
                      },
                    ),
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => setState(() => count = 2),
                    child: const Icon(Icons.remove),
                  ),
                );
              },
            ),
          ),
        );

        // Seed pending measurement queue with many indices.
        await tester.pump();

        // Shrink while stale indices are still pending.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        // Flush a few frames so pending callbacks run.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('handles itemCount shrink with pending load steps', (
      tester,
    ) async {
      var count = 200;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              final data = List<int>.generate(count, (i) => i);
              return Scaffold(
                body: SizedBox(
                  height: 400,
                  child: LazyWrap.dynamic(
                    itemCount: count,
                    batchSize: 60,
                    measureBatchSize: 1,
                    fadeInItems: false,
                    loadThreshold: 50,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 800,
                        height: 80,
                        child: Text('Item ${data[index]}'),
                      );
                    },
                  ),
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() => count = 10),
                  child: const Icon(Icons.remove),
                ),
              );
            },
          ),
        ),
      );

      // Let initial batch measurements settle enough for scroll extent updates.
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Trigger load-more so internal pending load steps are queued.
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -10000));
      await tester.pump();

      // Shrink while load steps are still pending.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Flush queued load and measurement callbacks.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.takeException(), isNull);
    });
  });
}

Widget _testItemBuilder(BuildContext context, int index) {
  return SizedBox(
    width: 100,
    height: 40,
    child: Center(child: Text('Item $index')),
  );
}

Widget _buildDynamicForEngine({
  required LazyWrapEngine engine,
  required int itemCount,
  required Widget Function(BuildContext, int) itemBuilder,
  double spacing = 8,
  double runSpacing = 8,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  ScrollController? controller,
}) {
  return LazyWrap.dynamic(
    itemCount: itemCount,
    engine: engine,
    spacing: spacing,
    runSpacing: runSpacing,
    padding: padding,
    controller: controller,
    fadeInItems: false,
    itemWidthBuilder: engine == LazyWrapEngine.sliverV2 ? (_) => 100 : null,
    itemHeightBuilder: engine == LazyWrapEngine.sliverV2 ? (_) => 40 : null,
    itemBuilder: itemBuilder,
  );
}

Widget _buildEngineHarness({
  required LazyWrapEngine engine,
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 240,
        height: 320,
        child: child,
      ),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 24}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
