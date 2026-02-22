import 'package:flutter/material.dart';
import 'package:lazy_wrap/lazy_wrap.dart';

void main() {
  runApp(const LazyWrapDemoApp());
}

/// Demo app showcasing both fixed and dynamic modes of [LazyWrap].
class LazyWrapDemoApp extends StatelessWidget {
  const LazyWrapDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LazyWrap Demo',
      theme: ThemeData(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

/// Demo page with tabs for fixed and dynamic modes.
class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('LazyWrap Demo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fixed Mode'),
              Tab(text: 'Dynamic Mode'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FixedModeDemo(),
            _DynamicModeDemo(),
          ],
        ),
      ),
    );
  }
}

/// Fixed mode: all items have the same size.
class _FixedModeDemo extends StatelessWidget {
  const _FixedModeDemo();

  @override
  Widget build(BuildContext context) {
    return LazyWrap.fixed(
      itemCount: 10000,
      estimatedItemWidth: 160,
      estimatedItemHeight: 100,
      spacing: 12,
      runSpacing: 12,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Card(
          child: Center(
            child: Text('Item $index'),
          ),
        );
      },
    );
  }
}

/// Dynamic mode: items have different sizes + fade-in animation.
class _DynamicModeDemo extends StatelessWidget {
  const _DynamicModeDemo();

  @override
  Widget build(BuildContext context) {
    return LazyWrap.dynamic(
      itemCount: 10000,
      spacing: 8,
      runSpacing: 8,
      padding: const EdgeInsets.all(16),
      fadeInItems: true,
      batchSize: 50,
      itemBuilder: (context, index) {
        // Variable-width chips to demonstrate dynamic measurement
        return Chip(
          label: Text('Tag $index${'!' * (index % 5)}'),
        );
      },
    );
  }
}
