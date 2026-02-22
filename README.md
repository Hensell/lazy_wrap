# lazy_wrap

A performant Flutter widget that combines the layout of `Wrap` with lazy rendering. Perfect for large lists with variable-sized items.

## ✨ Features

| Feature | Fixed Mode | Dynamic Mode |
|---------|------------|--------------|
| Lazy rendering | ✅ | ✅ |
| Zero layout jumps | ✅ | ✅ (Offstage measurement) |
| Horizontal scroll | ✅ | ✅ |
| Fade-in animation | ❌ | ✅ |
| Custom loading indicator | ❌ | ✅ |

## 📦 Installation

```yaml
dependencies:
  lazy_wrap: ^1.1.0
```

## 🆕 What's New in `1.1.0`

- `LazyWrap.dynamic` now supports engine selection via `LazyWrapEngine`.
- New opt-in experimental engine: `LazyWrapEngine.sliverV2`.
- Fix for dynamic mode when `itemCount` shrinks while measurements are pending
  (prevents stale queued builds/out-of-range indices).
- Default behavior remains unchanged: `offstageV1` is still the default engine
  (no breaking changes).

## 🧭 Engine Status (Dynamic Mode)

| Engine | Status | Recommended for |
|--------|--------|-----------------|
| `offstageV1` | Stable (default) | Production / general use |
| `sliverV2` | Experimental opt-in | Controlled trials / benchmarking |

Notes:
- `sliverV3` exists as an internal deep exploration and is **not** part of the
  public API contract/recommended release path.

## 🥊 Why `lazy_wrap` (vs `Wrap` / `ListView.builder`)

This package targets a specific gap in Flutter UI primitives:

- `Wrap`: gives you a **2D wrap layout**, but it is **not lazy** (builds eagerly).
- `ListView.builder`: gives you **lazy rendering**, but it is **1D** (not a wrap layout).
- `lazy_wrap`: gives you a **wrap-like 2D layout + lazy rendering**, which is the
  missing combination for large chip/tag/card collections.

Quick positioning:

| Widget | 2D Wrap-like layout | Lazy rendering | Best for |
|--------|----------------------|----------------|----------|
| `Wrap` | ✅ | ❌ | Small collections / simple UIs |
| `ListView.builder` | ❌ (1D) | ✅ | Feeds/lists (1D) |
| `LazyWrap.dynamic` | ✅ | ✅ | Large wrap-like collections |
| `LazyWrap.fixed` | ✅ | ✅ | Large uniform grids/cards |

## 📊 Benchmark Snapshot (`lazy_wrap` vs `Wrap` vs `ListView.builder`)

Local sample benchmark (Linux profile mode, `2000` chip items, single run):

| Implementation | p95_build_ms | p95_raster_ms | % jank | peak_memory_mb | TTI ms |
|---|---:|---:|---:|---:|---:|
| `lazy_wrap.dynamic` (2D lazy) | `0.76` | `7.54` | `3.99%` | `174.08` | `231.48` |
| `SingleChildScrollView + Wrap` (2D eager) | `20.18` | `12.19` | `9.09%` | `412.30` | `1158.74` |
| `ListView.builder` (1D lazy) | `7.00` | `13.07` | `4.68%` | `168.95` | `223.74` |

What this shows:

- `lazy_wrap` dramatically outperforms eager `Wrap` on large wrap-like collections.
- `ListView.builder` remains a great choice for **1D** lists (different problem).
- `lazy_wrap` is the better fit when you need **wrap semantics + lazy rendering**.

Benchmark caveats:

- `Wrap` is a **2D eager** baseline (same layout family, different rendering model).
- `ListView.builder` is a **1D lazy** baseline (same rendering model, different layout family).
- Results vary by device, widget complexity, and scroll pattern.

Re-run locally:

```bash
dart run benchmarks/run_chip_competitor_comparison.dart --device linux
```

Generated report/example:
- `benchmarks/results/experiments/20260222_071200Z_chip_competitor_compare_report.md`
- `benchmarks/results/experiments/20260222_071200Z_chip_competitor_compare.json`

## 🚀 Usage

### Fixed Mode (Best Performance)

Use when all items have the **same size**:

```dart
LazyWrap.fixed(
  itemCount: 10000,
  estimatedItemWidth: 120,
  estimatedItemHeight: 100,
  itemBuilder: (context, index) => ProductCard(index),
  spacing: 8,
  runSpacing: 8,
)
```

### Dynamic Mode (Variable Sizes)

Use when items have **different sizes**:

```dart
LazyWrap.dynamic(
  itemCount: 10000,
  itemBuilder: (context, index) => VariableCard(index),
  spacing: 8,
  runSpacing: 8,
  
  // Optional customization
  fadeInItems: true,                    // Smooth fade-in animation
  fadeInDuration: Duration(milliseconds: 200),
  batchSize: 50,                        // Items per batch
  loadingBuilder: (ctx) => MyLoader(),  // Custom loading indicator
)
```

### Dynamic Mode (Engine Opt-In)

`LazyWrap.dynamic` now supports selecting an engine:

```dart
LazyWrap.dynamic(
  itemCount: 50000,
  engine: LazyWrapEngine.sliverV2, // Experimental opt-in
  itemWidthBuilder: (i) => 140 + ((i % 6) * 18),
  itemHeightBuilder: (i) => 80 + ((i % 5) * 22),
  itemBuilder: (context, index) => Card(child: Text('Card $index')),
)
```

Notes:
- `offstageV1` remains the default and fully backward compatible.
- `sliverV2` is currently experimental and supports vertical scrolling only.
- For `sliverV2`, `itemWidthBuilder` and `itemHeightBuilder` are required.
- `sliverV2` is best evaluated with deterministic item sizes (benchmarks/trials).

### Migration Guide (`offstageV1` -> `sliverV2` opt-in)

No migration is required for existing users. This remains valid and unchanged:

```dart
LazyWrap.dynamic(
  itemCount: 1000,
  itemBuilder: (context, index) => Chip(label: Text('Tag $index')),
)
```

To evaluate `sliverV2`, add explicit engine selection + deterministic size
builders:

```dart
LazyWrap.dynamic(
  itemCount: 1000,
  engine: LazyWrapEngine.sliverV2,
  itemWidthBuilder: (index) => 120 + (index % 4) * 12,
  itemHeightBuilder: (index) => 48 + (index % 3) * 8,
  itemBuilder: (context, index) => Card(child: Text('Item $index')),
)
```

Roll back is immediate by removing `engine` (or setting
`engine: LazyWrapEngine.offstageV1`).

Current limitations of `sliverV2`:
- Experimental quality level (recommended for benchmarking/adoption trials).
- Vertical scroll only (`scrollDirection: Axis.vertical`).
- Requires `itemWidthBuilder` and `itemHeightBuilder`.
- `batchSize`/`loadingBuilder` are currently not used by `sliverV2`.

## 🎯 When to Use Which

| Scenario | Recommended |
|----------|-------------|
| Grid of cards (same size) | `LazyWrap.fixed` |
| Tags/chips (variable width) | `LazyWrap.dynamic` (`offstageV1`) |
| Mixed content | `LazyWrap.dynamic` (`offstageV1`) |
| Engine experiments / A-B tests | `LazyWrap.dynamic(engine: LazyWrapEngine.sliverV2)` |
| Maximum performance | `LazyWrap.fixed` |

Practical rule:
- Start with `LazyWrap.fixed` when possible.
- Use `LazyWrap.dynamic` with default engine for variable-size production UIs.
- Opt into `sliverV2` only when you want to benchmark/test a specific screen.

## 🌀 Demo

![LazyWrap Demo](https://github.com/Hensell/lazy_wrap_demo/raw/101d2a777d64b8ef283dee3c62da374d80cab835/screenshots/1.gif)

👉 [**Live Demo**](https://lazy-wrap-demo.pages.dev/)

## 📋 API Reference

### Common Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `itemCount` | `int` | required | Total number of items |
| `itemBuilder` | `Widget Function(BuildContext, int)` | required | Builds each item |
| `spacing` | `double` | `8` | Horizontal space between items |
| `runSpacing` | `double` | `8` | Vertical space between rows |
| `padding` | `EdgeInsets` | `zero` | Padding around content |
| `scrollDirection` | `Axis` | `vertical` | Scroll direction |
| `cacheExtent` | `double` | `300` | Pre-render buffer in pixels |

### Fixed Mode Only

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `estimatedItemWidth` | `double` | required | Width of each item |
| `estimatedItemHeight` | `double` | required | Height of each item |

### Dynamic Mode Only

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `batchSize` | `int` | `50` | OffstageV1: items loaded per batch (`sliverV2`: no-op actual) |
| `fadeInItems` | `bool` | `true` | Enable fade-in animation |
| `fadeInDuration` | `Duration` | `200ms` | Fade animation duration |
| `loadingBuilder` | `Widget Function(BuildContext)?` | `null` | OffstageV1 custom loading indicator (`sliverV2`: no-op actual) |
| `engine` | `LazyWrapEngine` | `offstageV1` | Dynamic engine selection |
| `itemWidthBuilder` | `double Function(int)?` | `null` | Required when `engine: sliverV2` |
| `itemHeightBuilder` | `double Function(int)?` | `null` | Required when `engine: sliverV2` |

### Dynamic Engine Contract Summary

- `offstageV1`
  - Full dynamic feature set (`fadeInItems`, batching, `loadingBuilder`)
  - Default and backward-compatible path
- `sliverV2`
  - Experimental opt-in path
  - Vertical scrolling only
  - Requires `itemWidthBuilder` + `itemHeightBuilder`
  - `batchSize` and `loadingBuilder` are currently not used

## ☕ Support

If this package helps you, consider supporting:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/hensell)

## 📣 Author

Created by [Hensell](https://hensell.dev) • [GitHub](https://github.com/Hensell)

## Contributors

<a href="https://github.com/Hensell/lazy_wrap/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Hensell/lazy_wrap" />
</a>
