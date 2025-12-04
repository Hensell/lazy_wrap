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
  lazy_wrap: ^1.0.0
```

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
  fadeInDuration: Duration(ms: 200),
  batchSize: 50,                        // Items per batch
  loadingBuilder: (ctx) => MyLoader(),  // Custom loading indicator
)
```

## 🎯 When to Use Which

| Scenario | Recommended |
|----------|-------------|
| Grid of cards (same size) | `LazyWrap.fixed` |
| Tags/chips (variable width) | `LazyWrap.dynamic` |
| Mixed content | `LazyWrap.dynamic` |
| Maximum performance | `LazyWrap.fixed` |

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
| `batchSize` | `int` | `50` | Items loaded per batch |
| `fadeInItems` | `bool` | `true` | Enable fade-in animation |
| `fadeInDuration` | `Duration` | `200ms` | Fade animation duration |
| `loadingBuilder` | `Widget Function(BuildContext)?` | `null` | Custom loading indicator |

## ☕ Support

If this package helps you, consider supporting:

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/hensell)

## 📣 Author

Created by [Hensell](https://hensell.dev) • [GitHub](https://github.com/Hensell)

## Contributors

<a href="https://github.com/Hensell/lazy_wrap/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Hensell/lazy_wrap" />
</a>
