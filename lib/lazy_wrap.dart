/// Lazy Wrap
///
/// A highly optimized wrap-like widget for Flutter that only builds the
/// visible children on screen, improving performance for large lists.
///
/// Use `LazyWrap.fixed` for items of uniform size (best performance).
/// Use `LazyWrap.dynamic` for items of variable size (no layout jumps).
///
/// Example:
/// ```dart
/// LazyWrap.fixed(
///   itemCount: 1000,
///   estimatedItemWidth: 120,
///   estimatedItemHeight: 100,
///   itemBuilder: (context, index) => Card(child: Text('Item $index')),
/// )
///
/// LazyWrap.dynamic(
///   itemCount: 1000,
///   itemBuilder: (context, index) => Chip(label: Text('Tag $index')),
///   fadeInItems: true,
/// )
/// ```
library;

export 'src/lazy_wrap_engine.dart';
export 'src/lazy_wrap_view.dart';
