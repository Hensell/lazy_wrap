
# lazy_wrap

A Flutter widget that combines the layout behavior of `Wrap` with the performance of `ListView.builder`.

Perfect for displaying cards or widgets in multiple columns with efficient vertical scrolling.

## 🚀 Quick Example

```dart
LazyWrap(
  itemCount: items.length,
  itemBuilder: (context, index) => ProductCard(item: items[index]),
  estimatedItemWidth: 120,
  estimatedItemHeight: 100,
  spacing: 8,
  runSpacing: 8,
  padding: EdgeInsets.all(12),
  useDynamicMeasurement: false, // or true for auto size measuring
)
```

## 🎯 Features

- Lazy scroll (only renders visible items)
- Wrap-style layout with efficient memory usage
- Responsive to available width
- Customizable spacing, padding, and alignment
- Supports both fixed and dynamic size measurement
- Slider control example for border radius
- Switch toggle for dynamic/fixed mode
- Clean animation and styling ready

## 📦 Installation

Add it to your `pubspec.yaml`:

```yaml
dependencies:
  lazy_wrap: ^0.0.7
```

## 🛠 Usage Tip

Use `useDynamicMeasurement: false` to eliminate layout jumps and maximize performance.

For widgets with highly variable size, use `true` and optionally apply batch updates or smooth resize techniques.

### Demo
<img src="https://github.com/Hensell/lazy_wrap/raw/1e3d41ad106b2f5f46033a23cff29954a83ef135/screenshots/1.gif" width="200" height="417" />

## 💡 Inspired by

This package was built to fill the gap between `Wrap` layout and `ListView.builder` efficiency.

