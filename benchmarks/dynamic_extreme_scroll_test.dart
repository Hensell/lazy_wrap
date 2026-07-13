import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/lazy_wrap.dart';

const _itemCount = int.fromEnvironment(
  'EXTREME_ITEM_COUNT',
  defaultValue: 200000,
);
const _batchSize = int.fromEnvironment(
  'EXTREME_BATCH_SIZE',
  defaultValue: 5000,
);
const _viewportKey = Key('extreme-dynamic-viewport');
const _itemKeyPrefix = 'extreme-dynamic-item-';

void main() {
  testWidgets('dynamic traverses $_itemCount items from last to first', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    var builderCalls = 0;
    var maxBuiltIndex = -1;
    var peakRssBytes = ProcessInfo.currentRss;
    final stopwatch = Stopwatch()..start();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: _viewportKey,
            width: 420,
            height: 640,
            child: LazyWrap.dynamic(
              itemCount: _itemCount,
              controller: controller,
              batchSize: _batchSize,
              measureBatchSize: _batchSize,
              cacheExtent: 640,
              loadThreshold: 640,
              loadingBuilder: (_) => const SizedBox.shrink(),
              itemBuilder: (context, index) {
                builderCalls++;
                if (index > maxBuiltIndex) maxBuiltIndex = index;
                return SizedBox(
                  key: ValueKey<String>('$_itemKeyPrefix$index'),
                  width: 72 + ((index % 7) * 13),
                  height: 40 + ((index % 5) * 8),
                  child: ColoredBox(
                    color: index.isEven ? Colors.blue : Colors.orange,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await _pumpUntil(
      tester,
      () =>
          controller.hasClients &&
          maxBuiltIndex >= (_batchSize.clamp(1, _itemCount) - 1),
      label: 'initial batch build',
    );
    peakRssBytes = _maxInt(peakRssBytes, ProcessInfo.currentRss);
    await _pumpUntil(
      tester,
      () => controller.position.maxScrollExtent > 0,
      label: 'initial measured extent',
    );

    var loadCycles = 0;
    while (maxBuiltIndex < _itemCount - 1) {
      final beforeIndex = maxBuiltIndex;
      final beforeExtent = controller.position.maxScrollExtent;
      final edgeInset = beforeExtent < 1 ? beforeExtent : 1.0;
      controller.jumpTo(beforeExtent - edgeInset);
      await tester.pump(const Duration(milliseconds: 16));
      controller.jumpTo(controller.position.maxScrollExtent);

      await _pumpUntil(
        tester,
        () => maxBuiltIndex > beforeIndex,
        label: 'batch after index $beforeIndex',
      );
      peakRssBytes = _maxInt(peakRssBytes, ProcessInfo.currentRss);
      await _pumpUntil(
        tester,
        () => controller.position.maxScrollExtent > beforeExtent,
        label: 'extent after index $beforeIndex',
      );

      loadCycles++;
      peakRssBytes = _maxInt(peakRssBytes, ProcessInfo.currentRss);
      expect(tester.takeException(), isNull);
      expect(loadCycles, lessThanOrEqualTo((_itemCount / _batchSize).ceil()));
    }

    final finalExtent = controller.position.maxScrollExtent;
    expect(maxBuiltIndex, _itemCount - 1);
    expect(finalExtent, greaterThan(100000));

    controller.jumpTo(finalExtent);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(
        const ValueKey<String>('$_itemKeyPrefix${_itemCount - 1}'),
        skipOffstage: true,
      ),
      findsOneWidget,
    );
    expect(_visibleItemCount(), greaterThan(0));
    expect(_minimumVisibleFadeOpacity(tester), greaterThanOrEqualTo(0.99));

    controller.jumpTo(controller.position.minScrollExtent);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(
        const ValueKey<String>('${_itemKeyPrefix}0'),
        skipOffstage: true,
      ),
      findsOneWidget,
    );
    expect(_visibleItemCount(), greaterThan(0));
    expect(_minimumVisibleFadeOpacity(tester), greaterThanOrEqualTo(0.99));

    for (var i = 0; i < 12; i++) {
      final target = i.isEven
          ? controller.position.maxScrollExtent
          : controller.position.minScrollExtent;
      controller.jumpTo(target);
      await tester.pump(const Duration(milliseconds: 16));
      expect(_visibleItemCount(), greaterThan(0));
      expect(_minimumVisibleFadeOpacity(tester), greaterThanOrEqualTo(0.99));
      expect(tester.takeException(), isNull);
      peakRssBytes = _maxInt(peakRssBytes, ProcessInfo.currentRss);
    }

    stopwatch.stop();
    debugPrint(
      'EXTREME_DYNAMIC_RESULT '
      'items=$_itemCount '
      'batch=$_batchSize '
      'cycles=$loadCycles '
      'extent=${finalExtent.toStringAsFixed(1)} '
      'builder_calls=$builderCalls '
      'peak_rss_mb=${(peakRssBytes / (1024 * 1024)).toStringAsFixed(1)} '
      'elapsed_ms=${stopwatch.elapsedMilliseconds}',
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  required String label,
  int maxFrames = 30,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (predicate()) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('Timed out waiting for $label.');
}

int _visibleItemCount() {
  return find
      .byWidgetPredicate(
        (widget) {
          final key = widget.key;
          return key is ValueKey<String> &&
              key.value.startsWith(_itemKeyPrefix);
        },
        skipOffstage: true,
      )
      .evaluate()
      .length;
}

double _minimumVisibleFadeOpacity(WidgetTester tester) {
  final viewport = tester.getRect(find.byKey(_viewportKey));
  var minimumOpacity = 1.0;

  for (final element in find.byType(FadeTransition).evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      continue;
    }
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!viewport.overlaps(rect)) continue;

    final transition = element.widget as FadeTransition;
    if (transition.opacity.value < minimumOpacity) {
      minimumOpacity = transition.opacity.value;
    }
  }

  return minimumOpacity;
}

int _maxInt(int a, int b) => a > b ? a : b;
