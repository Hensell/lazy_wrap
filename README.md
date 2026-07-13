# lazy_wrap

`lazy_wrap` brings lazy rendering to wrap-like Flutter layouts. It is designed
for large collections of chips, tags, cards, and tiles without eagerly building
every child.

Choose between two modes:

- `LazyWrap.fixed` for uniform item sizes and maximum performance.
- `LazyWrap.dynamic` for variable or unknown item sizes.

## Features

| Feature | Fixed | Dynamic |
|---|:---:|:---:|
| Lazy rendering | ✅ | ✅ |
| Vertical and horizontal scrolling | ✅ | ✅ |
| Variable item sizes | — | ✅ |
| Offstage measurement | — | ✅ |
| Optional fade-in | — | ✅ |
| Batched loading | — | ✅ |
| External `ScrollController` | — | ✅ |

`LazyWrap.dynamic` uses exact measured row geometry, applies backpressure while
measurement is in progress, and avoids transparent fade frames during large
scroll jumps. This keeps rapid reversals responsive even with very large item
counts.

## Installation

```yaml
dependencies:
  lazy_wrap: ^1.1.0
```

```dart
import 'package:lazy_wrap/lazy_wrap.dart';
```

## Fixed-size items

Use `LazyWrap.fixed` when every item has the same width and height. This is the
fastest mode because no measurement pass is required.

```dart
LazyWrap.fixed(
  itemCount: 10000,
  estimatedItemWidth: 120,
  estimatedItemHeight: 96,
  spacing: 8,
  runSpacing: 8,
  padding: const EdgeInsets.all(16),
  itemBuilder: (context, index) {
    return ProductCard(index: index);
  },
)
```

The dimensions supplied to fixed mode are used as the actual layout dimensions,
so they should match the intended size of every child.

## Variable-size items

Use `LazyWrap.dynamic` when item dimensions vary or cannot be known in advance.
Items are measured offstage before they enter the visible wrap.

```dart
LazyWrap.dynamic(
  itemCount: 10000,
  spacing: 8,
  runSpacing: 8,
  padding: const EdgeInsets.all(16),
  itemBuilder: (context, index) {
    return Chip(label: Text('Tag $index'));
  },
)
```

### Loading and animation

```dart
final controller = ScrollController();

LazyWrap.dynamic(
  itemCount: items.length,
  controller: controller,
  batchSize: 100,
  measureBatchSize: 20,
  loadThreshold: 400,
  cacheExtent: 400,
  fadeInItems: true,
  fadeInDuration: const Duration(milliseconds: 200),
  loadingBuilder: (context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  },
  itemBuilder: (context, index) => VariableCard(items[index]),
)
```

For heavy widgets, keep `measureBatchSize` conservative. Increasing
`cacheExtent` can make scrolling smoother at the cost of additional work and
memory.

## Choosing a mode

| Scenario | Recommended mode |
|---|---|
| Uniform cards or tiles | `LazyWrap.fixed` |
| Chips and tags with different widths | `LazyWrap.dynamic` |
| Items with variable heights | `LazyWrap.dynamic` |
| Maximum throughput with known dimensions | `LazyWrap.fixed` |

Start with fixed mode whenever the dimensions are truly uniform. Otherwise,
use dynamic mode with its default engine.

## Dynamic API

| Parameter | Default | Description |
|---|---:|---|
| `spacing` | `8` | Space between items in a run |
| `runSpacing` | `8` | Space between wrap runs |
| `padding` | `EdgeInsets.zero` | Padding around the content |
| `scrollDirection` | `Axis.vertical` | Scroll axis |
| `cacheExtent` | `300` | Pre-render distance in pixels |
| `batchSize` | `50` | Items admitted per load batch |
| `measureBatchSize` | `15` | Maximum items measured per pass |
| `loadThreshold` | `300` | Remaining distance that triggers loading |
| `fadeInItems` | `true` | Enables one-time item fade-in |
| `controller` | `null` | Optional external scroll controller |

`itemCount`, `spacing`, `runSpacing`, `cacheExtent`, and the batch-related
values must be non-negative; batch sizes must be greater than zero.

## Experimental engine

The default `LazyWrapEngine.offstageV1` is the production path. An experimental
vertical-only engine is also available for controlled evaluation:

```dart
LazyWrap.dynamic(
  itemCount: 50000,
  engine: LazyWrapEngine.sliverV2,
  itemWidthBuilder: (index) => 120 + (index % 4) * 12,
  itemHeightBuilder: (index) => 48 + (index % 3) * 8,
  itemBuilder: (context, index) => Card(
    child: Text('Item $index'),
  ),
)
```

`sliverV2` requires `itemWidthBuilder` and `itemHeightBuilder`, supports vertical
scrolling only, and does not currently use `batchSize` or `loadingBuilder`.

## Validation

The default dynamic engine is covered by automated rapid-scroll regressions and
an extreme widget test that loads 200,000 variable-size elements, reaches the
last item, returns to the first, and repeatedly jumps between both edges. Device
performance still depends on the complexity of each child.

The included example is also an interactive test lab with 1K–200K item
presets, fixed and dynamic modes, fade and batch controls, current-edge jumps,
automatic loading to the last item, and a 30-step rapid-bounce test.

## Demo

![LazyWrap Demo](https://github.com/Hensell/lazy_wrap_demo/raw/101d2a777d64b8ef283dee3c62da374d80cab835/screenshots/1.gif)

[Open the live demo](https://lazy-wrap-demo.pages.dev/)

## Support

If this package helps you, consider supporting its development:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/hensell)

Created by [Hensell](https://hensell.dev).
