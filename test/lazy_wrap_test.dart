import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/lazy_wrap.dart';

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
              (widget) => widget is Padding && widget.padding == padding)
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

      // Check that both items are rendered
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

      // Widget should render without errors
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

      // Dynamic mode uses SliverPadding inside CustomScrollView
      final hasSliverPadding = find
          .byWidgetPredicate(
              (widget) => widget is SliverPadding && widget.padding == padding)
          .evaluate()
          .isNotEmpty;

      expect(hasSliverPadding, isTrue);
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

      // First items should be visible
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
  });
}

Widget _testItemBuilder(BuildContext context, int index) {
  return SizedBox(
    width: 100,
    height: 40,
    child: Center(child: Text('Item $index')),
  );
}
