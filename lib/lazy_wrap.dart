/// Lazy Wrap
///
/// A highly optimized wrap-like widget for Flutter that only builds the
/// visible children on screen, improving performance for large lists.
///
/// Example:
/// ```dart
/// LazyWrapView(
///   children: List.generate(1000, (i) => Text('Item \$i')),
/// )
/// ```
library;

export 'src/lazy_wrap_view.dart';
