/// row_builder.dart
List<List<int>> buildRowGroups({
  required int itemCount,
  required double maxWidth,
  required double spacing,
  required Map<int, double> itemWidths,
}) {
  final rowGroups = <List<int>>[];
  int current = 0;

  while (current < itemCount) {
    double rowWidth = 0;
    final row = <int>[];

    while (current < itemCount) {
      final isMeasured = itemWidths.containsKey(current);
      final width = itemWidths[current] ?? 160;
      final nextTotal = rowWidth + width + (row.isNotEmpty ? spacing : 0);

      if (!isMeasured && row.isNotEmpty) break;
      if (nextTotal > maxWidth && row.isNotEmpty) break;

      rowWidth = nextTotal;
      row.add(current);
      current++;
    }

    if (row.isEmpty) {
      row.add(current);
      current++;
    }

    rowGroups.add(row);
  }

  return rowGroups;
}
