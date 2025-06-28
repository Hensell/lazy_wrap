import 'package:flutter/widgets.dart';

typedef OnWidgetSizeChange = void Function(Size size);

class MeasureSize extends StatefulWidget {
  final Widget child;
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    super.key,
    required this.child,
    required this.onChange,
  });

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? oldSize;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _notifySize());
        }
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: LayoutBuilder(
          builder: (_, __) {
            if (mounted) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _notifySize());
            }
            return widget.child;
          },
        ),
      ),
    );
  }

  void _notifySize() {
    if (!mounted) return;
    final contextSize = context.size;
    if (contextSize != null && contextSize != oldSize) {
      oldSize = contextSize;
      widget.onChange(contextSize);
    }
  }
}
