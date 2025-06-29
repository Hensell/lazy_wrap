import 'package:flutter/material.dart';
import 'package:lazy_wrap/lazy_wrap.dart';

void main() {
  runApp(const LazyWrapDemoApp());
}

class LazyWrapDemoApp extends StatelessWidget {
  const LazyWrapDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LazyWrap Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('LazyWrap Demo')),
        body: LazyWrap.fixed(
          itemCount: 10000,
          estimatedItemWidth: 160,
          estimatedItemHeight: 100,
          spacing: 12,
          runSpacing: 12,
          padding: const EdgeInsets.all(16),
          rowAlignment: MainAxisAlignment.start,
          itemBuilder: (context, index) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Item $index'),
              ),
            );
          },
        ),
      ),
    );
  }
}
