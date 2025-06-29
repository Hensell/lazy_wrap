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

      final items = find.byType(SizedBox);
      expect(items, findsNWidgets(2));
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
