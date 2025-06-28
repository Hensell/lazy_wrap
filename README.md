# lazy_wrap

A Flutter widget that combines the layout behavior of `Wrap` with the performance of `ListView.builder`.

Perfect for displaying cards or widgets in multiple columns with efficient vertical scrolling.

## 🚀 Quick Example

```dart
LazyWrap(
  itemCount: items.length,
  itemBuilder: (context, index) => ProductCard(item: items[index]),
  itemWidth: 120,
  spacing: 8,
  runSpacing: 8,
)
```

## 🎯 Features

- Lazy scroll (only renders visible items)
- Wrap-style layout
- Responsive to available width
- Customizable spacing
- Supports `ScrollController`, `padding`, and `shrinkWrap`

## 📦 Installation

Add it to your `pubspec.yaml`:

```yaml
dependencies:
  lazy_wrap: ^0.0.1
```
