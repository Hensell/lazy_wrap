import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/lazy_wrap.dart';

const _viewportKey = Key('dynamic-fast-scroll-viewport');
const _probeKeyPrefix = 'dynamic-fast-scroll-probe-';

void main() {
  group('LazyWrap.dynamic fast-scroll regressions', () {
    testWidgets(
      'identical items progress through more than one measurement sub-batch',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final builtIndices = <int>{};

        await tester.pumpWidget(
          _harness(
            controller: controller,
            itemCount: 10,
            batchSize: 10,
            measureBatchSize: 2,
            itemBuilder: (context, index) {
              builtIndices.add(index);
              return SizedBox(
                key: ValueKey<String>('$_probeKeyPrefix$index'),
                width: 240,
                height: 80,
                child: const ColoredBox(color: Colors.blue),
              );
            },
          ),
        );

        // The static loader has no ticker to accidentally keep the pipeline
        // alive. Measurement must explicitly schedule every required frame.
        await tester.pumpAndSettle(const Duration(milliseconds: 16));

        expect(tester.takeException(), isNull);
        expect(builtIndices, containsAll(List<int>.generate(10, (i) => i)));
        expect(controller.hasClients, isTrue);
        expect(controller.position.maxScrollExtent, greaterThan(100));

        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 16));

        expect(_visibleMainAxisCoverage(tester), greaterThan(0.20));
      },
    );

    testWidgets(
      'fast bounce before fade duration does not restart reentrant item fade',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _harness(
            controller: controller,
            itemCount: 40,
            batchSize: 40,
            measureBatchSize: 40,
            fadeInItems: true,
            fadeInDuration: const Duration(seconds: 2),
            itemBuilder: (context, index) {
              return SizedBox(
                key: ValueKey<String>('$_probeKeyPrefix$index'),
                width: 240,
                height: 72,
                child: const ColoredBox(color: Colors.orange),
              );
            },
          ),
        );

        await _pumpFrames(tester, 3);
        await tester.pump(const Duration(milliseconds: 200));

        final firstItem = find.byKey(
          const ValueKey<String>('${_probeKeyPrefix}0'),
        );
        expect(firstItem, findsOneWidget);

        final opacityBeforeBounce =
            _closestFadeOpacity(firstItem) ?? double.nan;
        expect(opacityBeforeBounce, allOf(greaterThan(0), lessThan(1)));

        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump(const Duration(milliseconds: 100));
        expect(firstItem, findsNothing);

        controller.jumpTo(controller.position.minScrollExtent);
        await tester.pump(const Duration(milliseconds: 16));
        expect(firstItem, findsOneWidget);
        expect(_visibleMainAxisCoverage(tester), greaterThan(0.20));

        final reentrantOpacity = _closestFadeOpacity(firstItem);
        if (reentrantOpacity != null) {
          expect(
            reentrantOpacity,
            greaterThanOrEqualTo(opacityBeforeBounce - 0.01),
            reason:
                'A reentrant item must resume its fade instead of '
                'restarting from transparent.',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'rapid edge bouncing keeps visible coverage and per-frame builds bounded',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        var builderCalls = 0;
        final builtAfterWarmup = <int>{};

        await tester.pumpWidget(
          _harness(
            controller: controller,
            itemCount: 1000,
            batchSize: 12,
            measureBatchSize: 3,
            itemBuilder: (context, index) {
              builderCalls++;
              builtAfterWarmup.add(index);
              return SizedBox(
                key: ValueKey<String>('$_probeKeyPrefix$index'),
                width: 240,
                height: 56 + ((index % 5) * 4),
                child: const ColoredBox(color: Colors.green),
              );
            },
          ),
        );

        await _pumpFrames(tester, 16);
        expect(controller.position.maxScrollExtent, greaterThan(0));

        builderCalls = 0;
        builtAfterWarmup.clear();
        var maxCallsInOneFrame = 0;
        var minimumCoverage = 1.0;

        for (var step = 0; step < 30; step++) {
          final position = controller.position;
          final target = step.isEven
              ? position.maxScrollExtent
              : position.minScrollExtent;
          position.jumpTo(target);

          final callsBeforeFrame = builderCalls;
          await tester.pump(const Duration(milliseconds: 16));
          maxCallsInOneFrame = math.max(
            maxCallsInOneFrame,
            builderCalls - callsBeforeFrame,
          );
          minimumCoverage = math.min(
            minimumCoverage,
            _visibleMainAxisCoverage(tester),
          );
        }

        expect(tester.takeException(), isNull);
        expect(builtAfterWarmup.any((index) => index >= 12), isTrue);
        expect(minimumCoverage, greaterThan(0.10));
        expect(maxCallsInOneFrame, lessThanOrEqualTo(30));
        expect(builderCalls, lessThan(600));
      },
    );
  });
}

Widget _harness({
  required ScrollController controller,
  required int itemCount,
  required int batchSize,
  required int measureBatchSize,
  required Widget Function(BuildContext, int) itemBuilder,
  bool fadeInItems = false,
  Duration fadeInDuration = const Duration(milliseconds: 200),
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          key: _viewportKey,
          width: 240,
          height: 200,
          child: LazyWrap.dynamic(
            itemCount: itemCount,
            controller: controller,
            batchSize: batchSize,
            measureBatchSize: measureBatchSize,
            cacheExtent: 0,
            loadThreshold: 80,
            fadeInItems: fadeInItems,
            fadeInDuration: fadeInDuration,
            fadeInCurve: Curves.linear,
            loadingBuilder: _staticLoadingBuilder,
            itemBuilder: itemBuilder,
          ),
        ),
      ),
    ),
  );
}

Widget _staticLoadingBuilder(BuildContext context) {
  return const SizedBox.shrink();
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

double? _closestFadeOpacity(Finder itemFinder) {
  final itemElement = itemFinder.evaluate().single;
  double? opacity;
  itemElement.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is FadeTransition) {
      opacity = widget.opacity.value;
      return false;
    }
    return true;
  });
  return opacity;
}

double _visibleMainAxisCoverage(WidgetTester tester) {
  final viewport = tester.getRect(find.byKey(_viewportKey));
  final spans = <(double, double)>[];
  final probes = find.byWidgetPredicate(
    (widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(_probeKeyPrefix);
    },
    skipOffstage: true,
  );

  for (final element in probes.evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      continue;
    }

    final itemRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!viewport.overlaps(itemRect)) continue;
    final intersection = viewport.intersect(itemRect);
    if (intersection.height > 0) {
      spans.add((intersection.top, intersection.bottom));
    }
  }

  if (spans.isEmpty) return 0;
  spans.sort((a, b) => a.$1.compareTo(b.$1));

  var covered = 0.0;
  var start = spans.first.$1;
  var end = spans.first.$2;
  for (final span in spans.skip(1)) {
    if (span.$1 <= end) {
      end = math.max(end, span.$2);
    } else {
      covered += end - start;
      start = span.$1;
      end = span.$2;
    }
  }
  covered += end - start;

  return covered / viewport.height;
}
