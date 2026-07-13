## [1.1.1]

### Added
- Added rapid-scroll regression coverage for measurement progress, edge
  bouncing, fade re-entry, row-spacing gaps, and large scroll offsets.
- Added an extreme validation scenario with 200,000 variable-size items,
  complete last-to-first traversal, and repeated edge jumps.
- Rebuilt the example as an interactive fixed/dynamic test lab with presets up
  to 200,000 items and manual rapid-scroll controls.

### Changed
- Dynamic mode now uses exact precomputed row geometry instead of estimated
  variable-row offsets, making large jumps and rapid reversals deterministic.
- Row offsets and extents now use 64-bit precision for very large scroll areas.
- Internal benchmarks, planning documents, development tests, and experimental
  spike sources are excluded from the pub.dev archive.
- Refreshed the README around the public fixed and dynamic APIs.

### Fixed
- Prevented dynamic Offstage measurement from stalling when consecutive
  sub-batches contain items with identical sizes.
- Added strict measurement backpressure so rapid edge scrolling cannot enqueue
  multiple unmeasured load batches and starve the UI thread.
- Removed the artificial load delay and made static custom loading indicators
  advance the measurement pipeline without requiring additional user input.
- Made one-time fade-ins resilient to row recycling and skipped transparent
  transitions during high-velocity scrolling, preventing gray/blank flashes.
- Kept loading state consistent when `itemCount` shrinks during pending work.
- Prevented following slivers from painting inside `runSpacing` gaps.

---

## [1.1.0]

### Added
- Public engine enum: `LazyWrapEngine { offstageV1, sliverV2 }`.
- `engine` parameter in `LazyWrap.dynamic` and `DynamicLazyWrap`.
- `itemWidthBuilder` and `itemHeightBuilder` for `sliverV2` opt-in.
- Engine parity tests and benchmark runner integration for `sliverV2`.

### Changed
- `DynamicLazyWrap` now routes internally by engine while preserving the
  existing default behavior (`offstageV1`).
- Benchmark scenario `dynamic_card_50k_sliver_v2` now uses the public API path
  (`LazyWrap.dynamic(engine: LazyWrapEngine.sliverV2)`).
- Offstage V1 visible widget cache now uses area-gated defaults tuned for
  large-card scenarios (`OFFSTAGE_VISIBLE_WIDGET_CACHE_CAPACITY=256`,
  `OFFSTAGE_ADAPTIVE_VISIBLE_WIDGET_CACHE=true`,
  `OFFSTAGE_VISIBLE_WIDGET_CACHE_MIN_ITEM_AREA=12000`).
- Added adaptive offstage measurement batch policy as opt-in experimental path
  (`OFFSTAGE_ADAPTIVE_MEASURE_BATCH`, `OFFSTAGE_LARGE_ITEM_MEASURE_BATCH_CAP`);
  default remains disabled to preserve current behavior.

### Fixed
- Cleared stale measurement queues/state when `itemCount` shrinks in dynamic
  mode, preventing out-of-range item builds during pending measurement.

### Notes
- `sliverV2` is experimental and opt-in.
- Default engine remains `offstageV1` (no breaking change).
- `sliverV3` work remains internal/deep exploration and is not part of the
  public release surface in `1.1.0`.

---

## [1.0.0]

### 🚀 Major Release - Zero Layout Jumps

- **Offstage measurement**: Items are now measured invisibly before display
- **Zero layout jumps**: No more "5 items → 10 items" sudden changes
- **Fade-in animation**: Optional smooth appearance (`fadeInItems: true`)
- **Simplified API**: Removed `estimatedItemMainSize` (no longer needed)
- **Updated SDK**: Requires Flutter 3.38+ and Dart 3.10+

### Breaking Changes
- Removed `estimatedItemMainSize` and `estimatedItemCrossSize` params
- Removed `animateRows`, `cleanupOffscreenSizes`, `memoryBufferMultiplier` params

---

## [0.1.1] 
- Bug fixed.

## [0.1.0] 
- Update documentation.

## [0.0.9+3] 
- Update screenshot.

## [0.0.9+2] 
- Update screenshot.

## [0.0.9+1] 
- Update screenshot.

## [0.0.9] 
- Added horizontal scroll.

## [0.0.8+6] 
- Added constructors.

## [0.0.8+5] 
- Update dynamic lazy wrap.

## [0.0.8+4] 
- Update default values.

## [0.0.8+3] 
- Added live demo.

## [0.0.8+2] 
- Bug fixed.

## [0.0.8+1] 
### Fixed
- Fixed row alignment issue that caused overflow when using `MainAxisAlignment.center`.
- Wrapped `Row` in `SizedBox` with calculated width to prevent layout overflow.

## 0.0.8
- Added `rowAlignment` to allow horizontal alignment of children inside each row (e.g. center).

## 0.0.7
- Added fixed mode

## 0.0.6
- Performance improve

## 0.0.5
- Bug fixed.

## 0.0.4
- Bug fixed.

## 0.0.3
- Bug fixed.

## 0.0.2
- Added `rowAlignment` to allow horizontal alignment of children inside each row (e.g. center).

## 0.0.1
- Initial release.
