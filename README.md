# lazy_wrap

A Flutter widget that combines the layout behavior of `Wrap` with the performance of `ListView.builder`.

Perfect for displaying cards or widgets in multiple columns with efficient vertical scrolling.

## 🚀 Quick Example

```dart
// Fixed-size version (better performance, no layout jumps)
LazyWrap.fixed(
  itemCount: items.length,
  estimatedItemWidth: 120,
  estimatedItemHeight: 100,
  itemBuilder: (context, index) => ProductCard(item: items[index]),
  spacing: 8,
  runSpacing: 8,
  padding: EdgeInsets.all(12),
)

// Dynamic-size version (auto-measures height, good for complex UIs)
LazyWrap.dynamic(
  itemCount: items.length,
  itemBuilder: (context, index) => ProductCard(item: items[index]),
  spacing: 8,
  runSpacing: 8,
  padding: EdgeInsets.all(12),
  batchSize: 500,
)
```

## 🎯 Features

- Lazy scroll (only renders visible items)
- Wrap-style layout with efficient memory usage
- Responsive to available width
- Customizable spacing, padding, and alignment
- Supports both fixed and dynamic size measurement
- Clean animation and styling ready

## 📦 Installation

Add it to your `pubspec.yaml`:

```yaml
dependencies:
  lazy_wrap: ^0.0.8
```

## 🛠 Usage Tip

Use `LazyWrap.fixed` to eliminate layout jumps and maximize performance.

For widgets with highly variable size, use `LazyWrap.dynamic` and optionally apply chunked rendering or resize smoothing techniques.

## 🌀 Example

![LazyWrap Demo](https://github.com/Hensell/lazy_wrap/raw/1e3d41ad106b2f5f46033a23cff29954a83ef135/screenshots/1.gif)

### 💻 Live Demo

Check it out in action:  
👉 [**lazy-wrap-demo.pages.dev**](https://lazy-wrap-demo.pages.dev/)

## 💡 Inspired by

This package was built to fill the gap between `Wrap` layout and `ListView.builder` efficiency.
