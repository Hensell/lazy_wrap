import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lazy_wrap/lazy_wrap.dart';

void main() {
  runApp(const LazyWrapTestApp());
}

/// Interactive test application for the public [LazyWrap] API.
class LazyWrapTestApp extends StatelessWidget {
  /// Creates the test application.
  const LazyWrapTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LazyWrap Test Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _TestLabPage(),
    );
  }
}

class _TestLabPage extends StatelessWidget {
  const _TestLabPage();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LazyWrap Test Lab'),
              Text(
                'Manual validation for large collections',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grid_view_rounded), text: 'Fixed'),
              Tab(
                icon: Icon(Icons.auto_awesome_mosaic_rounded),
                text: 'Dynamic',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FixedTestPage(),
            _DynamicTestPage(),
          ],
        ),
      ),
    );
  }
}

class _FixedTestPage extends StatefulWidget {
  const _FixedTestPage();

  @override
  State<_FixedTestPage> createState() => _FixedTestPageState();
}

class _FixedTestPageState extends State<_FixedTestPage>
    with AutomaticKeepAliveClientMixin {
  int _itemCount = 100000;
  Axis _axis = Axis.vertical;
  int _configurationId = 0;

  @override
  bool get wantKeepAlive => true;

  void _changeConfiguration(VoidCallback update) {
    setState(() {
      update();
      _configurationId++;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _ControlSurface(
          children: [
            _CountSelector(
              value: _itemCount,
              onChanged: (value) {
                _changeConfiguration(() => _itemCount = value);
              },
            ),
            _AxisSelector(
              value: _axis,
              onChanged: (value) {
                _changeConfiguration(() => _axis = value);
              },
            ),
            const _InfoChip(
              icon: Icons.speed_rounded,
              label: 'Exact fixed geometry',
            ),
          ],
        ),
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: LazyWrap.fixed(
              key: ValueKey('fixed-$_configurationId'),
              itemCount: _itemCount,
              estimatedItemWidth: 128,
              estimatedItemHeight: 88,
              scrollDirection: _axis,
              spacing: 10,
              runSpacing: 10,
              padding: const EdgeInsets.all(16),
              cacheExtent: 640,
              itemBuilder: (context, index) => _FixedTile(index: index),
            ),
          ),
        ),
      ],
    );
  }
}

class _DynamicTestPage extends StatefulWidget {
  const _DynamicTestPage();

  @override
  State<_DynamicTestPage> createState() => _DynamicTestPageState();
}

class _DynamicTestPageState extends State<_DynamicTestPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();
  final ValueNotifier<String> _status = ValueNotifier('Ready');

  int _itemCount = 10000;
  int _configurationId = 0;
  int _maxBuiltIndex = -1;
  int _runGeneration = 0;
  bool _fadeInItems = true;
  bool _aggressiveLoading = false;
  bool _isRunning = false;

  int get _batchSize => _aggressiveLoading ? 5000 : 100;
  int get _measureBatchSize => _aggressiveLoading ? 1000 : 20;
  double get _cacheExtent => _aggressiveLoading ? 640 : 400;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _runGeneration++;
    _controller.dispose();
    _status.dispose();
    super.dispose();
  }

  void _changeConfiguration(VoidCallback update) {
    _stopStress(updateStatus: false);
    if (_controller.hasClients) {
      _controller.jumpTo(_controller.position.minScrollExtent);
    }
    setState(() {
      update();
      _configurationId++;
      _maxBuiltIndex = -1;
    });
    _status.value = 'Configuration reset';
  }

  void _jumpTo(double offset) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    _controller.jumpTo(
      offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _jumpToTop() {
    if (!_controller.hasClients) return;
    _jumpTo(_controller.position.minScrollExtent);
    _status.value = 'Jumped to first loaded row';
  }

  void _jumpToBottom() {
    if (!_controller.hasClients) return;
    _jumpTo(_controller.position.maxScrollExtent);
    _status.value = 'Jumped to current loaded edge';
  }

  void _stopStress({bool updateStatus = true}) {
    _runGeneration++;
    if (_isRunning && mounted) {
      setState(() => _isRunning = false);
    }
    if (updateStatus) _status.value = 'Stress run stopped';
  }

  Future<void> _runRapidBounce() async {
    if (_isRunning) return;
    final generation = ++_runGeneration;
    setState(() => _isRunning = true);

    for (var step = 0; step < 30; step++) {
      if (!mounted || generation != _runGeneration) return;
      if (_controller.hasClients) {
        final position = _controller.position;
        _jumpTo(
          step.isEven ? position.maxScrollExtent : position.minScrollExtent,
        );
        _status.value = 'Rapid bounce ${step + 1}/30';
      }
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted || generation != _runGeneration) return;
    setState(() => _isRunning = false);
    _status.value = 'Rapid bounce complete — no blank frame expected';
  }

  Future<void> _loadToLastItem() async {
    if (_isRunning) return;
    final generation = ++_runGeneration;
    setState(() => _isRunning = true);
    var cycles = 0;
    final framesPerBatch = (_batchSize / _measureBatchSize).ceil() + 3;
    final maxCycles = ((_itemCount / _batchSize).ceil() * framesPerBatch) + 20;

    while (mounted &&
        generation == _runGeneration &&
        _maxBuiltIndex < _itemCount - 1 &&
        cycles < maxCycles) {
      if (_controller.hasClients) {
        final maxExtent = _controller.position.maxScrollExtent;
        _jumpTo(math.max(0, maxExtent - 1));
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || generation != _runGeneration) return;
        _jumpTo(_controller.position.maxScrollExtent);
      }

      cycles++;
      _status.value =
          'Loading edge • built through ${_maxBuiltIndex + 1} / $_itemCount';
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted || generation != _runGeneration) return;
    if (_controller.hasClients) {
      _jumpTo(_controller.position.maxScrollExtent);
    }
    setState(() => _isRunning = false);
    _status.value = _maxBuiltIndex >= _itemCount - 1
        ? 'Reached item $_itemCount — try Rapid bounce now'
        : 'Stopped at item ${_maxBuiltIndex + 1}; press Load to last again';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        _ControlSurface(
          children: [
            _CountSelector(
              value: _itemCount,
              onChanged: (value) {
                _changeConfiguration(() => _itemCount = value);
              },
            ),
            FilterChip(
              selected: _fadeInItems,
              avatar: const Icon(Icons.animation_rounded, size: 18),
              label: const Text('Fade'),
              onSelected: (value) {
                _changeConfiguration(() => _fadeInItems = value);
              },
            ),
            FilterChip(
              selected: _aggressiveLoading,
              avatar: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('Stress batches'),
              onSelected: (value) {
                _changeConfiguration(() => _aggressiveLoading = value);
              },
            ),
            OutlinedButton.icon(
              onPressed: _isRunning ? null : _jumpToTop,
              icon: const Icon(Icons.vertical_align_top_rounded),
              label: const Text('Top'),
            ),
            OutlinedButton.icon(
              onPressed: _isRunning ? null : _jumpToBottom,
              icon: const Icon(Icons.vertical_align_bottom_rounded),
              label: const Text('Current end'),
            ),
            FilledButton.tonalIcon(
              onPressed: _isRunning ? null : _loadToLastItem,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('Load to last'),
            ),
            FilledButton.icon(
              onPressed: _isRunning ? _stopStress : _runRapidBounce,
              icon: Icon(
                _isRunning ? Icons.stop_rounded : Icons.swap_vert_rounded,
              ),
              label: Text(_isRunning ? 'Stop' : 'Rapid bounce'),
            ),
          ],
        ),
        _DynamicStatusBar(
          controller: _controller,
          status: _status,
          itemCount: _itemCount,
          batchSize: _batchSize,
          measureBatchSize: _measureBatchSize,
        ),
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: LazyWrap.dynamic(
              key: ValueKey('dynamic-$_configurationId'),
              itemCount: _itemCount,
              controller: _controller,
              batchSize: _batchSize,
              measureBatchSize: _measureBatchSize,
              cacheExtent: _cacheExtent,
              loadThreshold: _cacheExtent,
              fadeInItems: _fadeInItems,
              fadeInDuration: const Duration(milliseconds: 350),
              spacing: 8,
              runSpacing: 8,
              padding: const EdgeInsets.all(16),
              loadingBuilder: (context) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              itemBuilder: (context, index) {
                if (index > _maxBuiltIndex) _maxBuiltIndex = index;
                return _DynamicTile(index: index);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlSurface extends StatelessWidget {
  const _ControlSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

class _CountSelector extends StatelessWidget {
  const _CountSelector({required this.value, required this.onChanged});

  static const values = [1000, 10000, 50000, 200000];

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<int>(
      key: const Key('item-count-selector'),
      initialSelection: value,
      width: 150,
      label: const Text('Items'),
      leadingIcon: const Icon(Icons.data_array_rounded),
      dropdownMenuEntries: values
          .map(
            (count) => DropdownMenuEntry<int>(
              value: count,
              label: _formatCount(count),
            ),
          )
          .toList(growable: false),
      onSelected: (next) {
        if (next != null && next != value) onChanged(next);
      },
    );
  }
}

class _AxisSelector extends StatelessWidget {
  const _AxisSelector({required this.value, required this.onChanged});

  final Axis value;
  final ValueChanged<Axis> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<Axis>(
      segments: const [
        ButtonSegment(
          value: Axis.vertical,
          icon: Icon(Icons.swap_vert_rounded),
          label: Text('Vertical'),
        ),
        ButtonSegment(
          value: Axis.horizontal,
          icon: Icon(Icons.swap_horiz_rounded),
          label: Text('Horizontal'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _DynamicStatusBar extends StatelessWidget {
  const _DynamicStatusBar({
    required this.controller,
    required this.status,
    required this.itemCount,
    required this.batchSize,
    required this.measureBatchSize,
  });

  final ScrollController controller;
  final ValueNotifier<String> status;
  final int itemCount;
  final int batchSize;
  final int measureBatchSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHigh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final statusText = ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (context, message, _) => Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
          final metrics = AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final pixels = controller.hasClients
                  ? controller.position.pixels
                  : 0.0;
              final maxExtent = controller.hasClients
                  ? controller.position.maxScrollExtent
                  : 0.0;
              return Text(
                '${_formatCount(itemCount)} • '
                'batch $batchSize/$measureBatchSize • '
                '${pixels.toStringAsFixed(0)} / '
                '${maxExtent.toStringAsFixed(0)} px',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              );
            },
          );

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: constraints.maxWidth < 600
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      statusText,
                      const SizedBox(height: 3),
                      SizedBox(width: double.infinity, child: metrics),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: statusText),
                      const SizedBox(width: 12),
                      Flexible(child: metrics),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _FixedTile extends StatelessWidget {
  const _FixedTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = Color.lerp(
      colorScheme.primaryContainer,
      colorScheme.tertiaryContainer,
      (index % 9) / 8,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          '#$index',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
    );
  }
}

class _DynamicTile extends StatelessWidget {
  const _DynamicTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = 84.0 + ((index % 7) * 16);
    final height = 42.0 + ((index % 4) * 10);
    final color = index.isEven
        ? colorScheme.secondaryContainer
        : colorScheme.tertiaryContainer;

    return Container(
      key: ValueKey('dynamic-item-$index'),
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14 + (index % 3) * 4),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        'Item $index',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

String _formatCount(int value) {
  if (value >= 1000) {
    final thousands = value / 1000;
    final digits = value % 1000 == 0 ? 0 : 1;
    return '${thousands.toStringAsFixed(digits)}K';
  }
  return '$value';
}
