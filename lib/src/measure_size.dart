import 'package:flutter/widgets.dart';

/// Signature for a callback that receives a widget's size.
typedef OnWidgetSizeChange = void Function(Size size);

/// [MeasureSize] is a utility widget that listens for changes in the
/// rendered size of its [child] widget, and notifies [onChange] whenever
/// the size changes.
///
/// Useful for building layouts that depend on dynamic, unknown, or
/// runtime-calculated widget sizes (e.g. in virtualized/lazy wraps).
class MeasureSize extends StatefulWidget {
  /// {@macro measure_size}
  const MeasureSize({
    required this.child,
    required this.onChange,
    super.key,
  });

  /// The widget whose size you want to measure.
  final Widget child;

  /// Callback invoked whenever the child's size changes.
  final OnWidgetSizeChange onChange;
  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? oldSize;

  @override
  Widget build(BuildContext context) {
    // Listens for layout changes and notifies after the frame if needed.
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _notifySize());
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: LayoutBuilder(
          builder: (_, __) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _notifySize());
            return widget.child;
          },
        ),
      ),
    );
  }

  /// Checks the current context size and calls onChange if it changed.
  void _notifySize() {
    final contextSize = context.size;
    if (contextSize != null && contextSize != oldSize) {
      oldSize = contextSize;
      widget.onChange(contextSize);
    }
  }
}
