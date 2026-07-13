import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The publishable example is intentionally outside the package's public lib/.
// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';

void main() {
  testWidgets('example exposes fixed and dynamic stress controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const LazyWrapTestApp());
    await tester.pump(const Duration(milliseconds: 32));

    expect(find.text('LazyWrap Test Lab'), findsOneWidget);
    expect(find.text('Fixed'), findsOneWidget);
    expect(find.text('Dynamic'), findsOneWidget);
    expect(find.byKey(const ValueKey('fixed-0')), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Dynamic'));
    await tester.pumpAndSettle(const Duration(milliseconds: 16));

    expect(find.text('Rapid bounce'), findsOneWidget);
    expect(find.text('Load to last'), findsOneWidget);
    expect(find.text('Stress batches'), findsOneWidget);
    expect(find.byKey(const ValueKey('dynamic-0')).hitTestable(), findsOneWidget);

    await tester.tap(find.text('Rapid bounce'));
    for (var frame = 0; frame < 35; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      find.text('Rapid bounce complete — no blank frame expected'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
