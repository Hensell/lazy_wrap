import 'package:flutter_test/flutter_test.dart';
import 'package:lazy_wrap/src/offstage_visible_cache_policy.dart';

void main() {
  group('estimateVisibleItemDensity', () {
    test('estimates dense viewport for chip-like items', () {
      final density = estimateVisibleItemDensity(
        averageItemMainExtent: 80,
        averageItemCrossExtent: 32,
        viewportMainExtent: 360,
        viewportCrossExtent: 640,
        spacing: 8,
        runSpacing: 8,
      );

      expect(density.itemsPerRun, 4);
      expect(density.runsPerViewport, 16);
      expect(density.itemsPerViewport, 64);
    });

    test('returns minimal density for invalid inputs', () {
      final density = estimateVisibleItemDensity(
        averageItemMainExtent: 80,
        averageItemCrossExtent: 32,
        viewportMainExtent: 0,
        viewportCrossExtent: 640,
        spacing: 8,
        runSpacing: 8,
      );

      expect(density.itemsPerRun, 1);
      expect(density.runsPerViewport, 1);
      expect(density.itemsPerViewport, 1);
    });
  });

  group('computeAdaptiveVisibleCacheCapacity', () {
    test('returns 0 when base capacity is not positive', () {
      final result = computeAdaptiveVisibleCacheCapacity(
        const OffstageVisibleCachePolicyInput(
          baseCapacity: 0,
          minCapacity: 16,
          averageItemMainExtent: 80,
          averageItemCrossExtent: 32,
          viewportMainExtent: 360,
          viewportCrossExtent: 640,
          spacing: 8,
          runSpacing: 8,
        ),
      );

      expect(result, 0);
    });

    test('falls back to base capacity when viewport metrics are invalid', () {
      final result = computeAdaptiveVisibleCacheCapacity(
        const OffstageVisibleCachePolicyInput(
          baseCapacity: 256,
          minCapacity: 16,
          averageItemMainExtent: 80,
          averageItemCrossExtent: 32,
          viewportMainExtent: 0,
          viewportCrossExtent: 640,
          spacing: 8,
          runSpacing: 8,
        ),
      );

      expect(result, 256);
    });

    test('keeps large capacity for chip-like small items', () {
      final result = computeAdaptiveVisibleCacheCapacity(
        const OffstageVisibleCachePolicyInput(
          baseCapacity: 512,
          minCapacity: 16,
          averageItemMainExtent: 80,
          averageItemCrossExtent: 32,
          viewportMainExtent: 360,
          viewportCrossExtent: 640,
          spacing: 8,
          runSpacing: 8,
        ),
      );

      expect(result, 512);
    });

    test('reduces capacity for card-like larger items', () {
      final result = computeAdaptiveVisibleCacheCapacity(
        const OffstageVisibleCachePolicyInput(
          baseCapacity: 512,
          minCapacity: 16,
          averageItemMainExtent: 320,
          averageItemCrossExtent: 180,
          viewportMainExtent: 360,
          viewportCrossExtent: 640,
          spacing: 8,
          runSpacing: 8,
        ),
      );

      expect(result, 16);
    });

    test('respects min and max bounds', () {
      final result = computeAdaptiveVisibleCacheCapacity(
        const OffstageVisibleCachePolicyInput(
          baseCapacity: 64,
          minCapacity: 40,
          averageItemMainExtent: 500,
          averageItemCrossExtent: 300,
          viewportMainExtent: 360,
          viewportCrossExtent: 640,
          spacing: 8,
          runSpacing: 8,
        ),
      );

      expect(result, inInclusiveRange(40, 64));
    });
  });

  group('computeAdaptiveMeasureBatchSize', () {
    test('returns base size when samples are insufficient', () {
      final result = computeAdaptiveMeasureBatchSize(
        const OffstageMeasureBatchPolicyInput(
          baseMeasureBatchSize: 16,
          largeItemBatchCap: 8,
          averageItemArea: 24000,
          minLargeItemArea: 12000,
          sampleCount: 4,
        ),
      );

      expect(result, 16);
    });

    test('returns base size for small item area', () {
      final result = computeAdaptiveMeasureBatchSize(
        const OffstageMeasureBatchPolicyInput(
          baseMeasureBatchSize: 16,
          largeItemBatchCap: 8,
          averageItemArea: 4000,
          minLargeItemArea: 12000,
          sampleCount: 16,
        ),
      );

      expect(result, 16);
    });

    test('caps batch size for large item area', () {
      final result = computeAdaptiveMeasureBatchSize(
        const OffstageMeasureBatchPolicyInput(
          baseMeasureBatchSize: 20,
          largeItemBatchCap: 8,
          averageItemArea: 22000,
          minLargeItemArea: 12000,
          sampleCount: 24,
        ),
      );

      expect(result, 8);
    });

    test('never returns less than 1', () {
      final result = computeAdaptiveMeasureBatchSize(
        const OffstageMeasureBatchPolicyInput(
          baseMeasureBatchSize: 0,
          largeItemBatchCap: 0,
          averageItemArea: 22000,
          minLargeItemArea: 12000,
          sampleCount: 24,
        ),
      );

      expect(result, 1);
    });
  });
}
