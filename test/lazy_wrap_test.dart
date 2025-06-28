import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:lazy_wrap/lazy_wrap.dart';

void main() {
  testWidgets('LazyWrap builds correctly with items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LazyWrap(
          itemCount: 3,
          itemBuilder: (context, index) => Text('Item $index'),
          itemWidth: 100,
        ),
      ),
    );

    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
  });
}
