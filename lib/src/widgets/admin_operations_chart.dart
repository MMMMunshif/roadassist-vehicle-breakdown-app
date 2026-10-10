part of '../screens.dart';

/// Four operational metrics share a comparison chart; actual units remain visible.
class AdminOperationsChart extends StatefulWidget {
  const AdminOperationsChart({super.key, this.records, this.today});
  final List<Map<String, dynamic>>? records;
  final DateTime? today;
  @override
  State<AdminOperationsChart> createState() => _AdminOperationsChartState();
}

class _AdminOperationsChartState extends State<AdminOperationsChart> {
  int days = 7;
  int? selectedDay;
  final visible = <int>{0, 1, 2, 3};
  late final now = widget.today ?? DateTime.now();
  late final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 29));
  late final streams = [
    for (final field in ['createdAt', 'completedAt', 'acceptedAt'])
      FirebaseFirestore.instance
          .collection('requests')
          .where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy(field, descending: true)
          .limit(1000)
          .snapshots(),
  ];
  static const names = [
    'Requests',
    'Completed jobs',
    'Response time',
    'Service value',
  ];
  static const colors = [
    Color(0xFF168BFF),
    Color(0xFF00A88F),
    Color(0xFFB277F3),
    Color(0xFFE09818),
  ];
  @override
  Widget build(BuildContext context) {
    if (widget.records != null) return chart(widget.records!, false);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: streams[0],
      builder: (context, a) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: streams[1],
            builder: (context, b) =>
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: streams[2],
                  builder: (context, c) {
                    if (a.hasError || b.hasError || c.hasError)
                      return const InlineMessage(
                        icon: Icons.cloud_off_outlined,
                        text: 'Assistance trends could not be loaded.',
                      );
                    if (!a.hasData || !b.hasData || !c.hasData)
                      return const LinearProgressIndicator();
                    final unique = {
                      for (final d in [
                        ...a.data!.docs,
                        ...b.data!.docs,
                        ...c.data!.docs,
                      ])
                        d.id: d.data(),
                    };
                    return chart(
                      unique.values.toList(),
                      [a, b, c].any((s) => s.data!.docs.length == 1000),
                    );
                  },
                ),
          ),
    );
  }

  Widget chart(List<Map<String, dynamic>> records, bool capped) {
    final today = DateTime(now.year, now.month, now.day);
    final values = List.generate(4, (_) => List<double?>.filled(days, 0));
    final responseCounts = List<int>.filled(days, 0);
    int? bucket(dynamic raw) {
      if (raw is! Timestamp) return null;
      final d = raw.toDate().toLocal();
      final offset = today.difference(DateTime(d.year, d.month, d.day)).inDays;
      return offset >= 0 && offset < days ? days - 1 - offset : null;
    }

    for (final record in records) {
      final created = record['createdAt'], accepted = record['acceptedAt'];
      final requestIndex = bucket(created);
      if (requestIndex != null)
        values[0][requestIndex] = values[0][requestIndex]! + 1;
      final completeIndex = bucket(record['completedAt']);
      if (record['status'] == 'completed' && completeIndex != null) {
        values[1][completeIndex] = values[1][completeIndex]! + 1;
        final amount = record['finalCost'];
        if (amount is num && amount.isFinite && amount >= 0)
          values[3][completeIndex] =
              values[3][completeIndex]! + amount.toDouble();
      }
      final responseIndex = bucket(accepted);
      if (responseIndex != null &&
          created is Timestamp &&
          accepted is Timestamp) {
        final minutes =
            accepted.toDate().difference(created.toDate()).inMilliseconds /
            60000;
        if (minutes >= 0) {
          values[2][responseIndex] = values[2][responseIndex]! + minutes;
          responseCounts[responseIndex]++;
        }
      }
    }
    for (var i = 0; i < days; i++) {
      values[2][i] = responseCounts[i] == 0
          ? null
          : values[2][i]! / responseCounts[i];
    }
    final totals = [
      values[0].fold<double>(0, (a, b) => a + (b ?? 0)),
      values[1].fold<double>(0, (a, b) => a + (b ?? 0)),
      responseCounts.fold<int>(0, (a, b) => a + b) == 0
          ? null
          : List.generate(
                  days,
                  (i) => (values[2][i] ?? 0) * responseCounts[i],
                ).fold<double>(0, (a, b) => a + b) /
                responseCounts.fold<int>(0, (a, b) => a + b),
      values[3].fold<double>(0, (a, b) => a + (b ?? 0)),
    ];
    String actual(int metric, double? value) => value == null
        ? 'No data'
        : switch (metric) {
            2 => '${value.toStringAsFixed(1)} min',
            3 => 'Rs. ${value.toStringAsFixed(2)}',
            _ => value.toInt().toString(),
          };
    final single = visible.length == 1;
    final plotted = [
      for (final series in values)
        [
          for (final value in series)
            value == null
                ? null
                : single
                ? value
                : series.whereType<double>().fold<double>(
                        0,
                        (a, b) => a > b ? a : b,
                      ) ==
                      0
                ? 0.0
                : value /
                      series.whereType<double>().fold<double>(
                        0,
                        (a, b) => a > b ? a : b,
                      ) *
                      100,
        ],
    ];
    final index = selectedDay?.clamp(0, days - 1);
    String dateLabel(int i) {
      final date = today.subtract(Duration(days: days - 1 - i));
      return '${date.day}/${date.month}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assistance trends',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final count in [7, 30])
                  ChoiceChip(
                    label: Text('$count Days'),
                    selected: days == count,
                    onSelected: (_) => setState(() {
                      days = count;
                      selectedDay = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 4; i++)
                  FilterChip(
                    avatar: Icon(Icons.show_chart, color: colors[i], size: 18),
                    label: SizedBox(
                      width: MediaQuery.textScalerOf(context).scale(14) > 20
                          ? 120
                          : null,
                      child: Text(names[i]),
                    ),
                    selected: visible.contains(i),
                    onSelected: (on) => setState(() {
                      if (on) {
                        visible.add(i);
                      } else if (visible.length > 1) {
                        visible.remove(i);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              single
                  ? 'Actual scale: ${names[visible.single]} (0 to ${actual(visible.single, values[visible.single].whereType<double>().fold<double>(1, (a, b) => a > b ? a : b))})'
                  : 'Comparison: 0-100% of the highest day of each metric. These percentages are relative levels, not growth.',
            ),
            const Text(
              'Lower response time is better. Days without response data have gaps.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                void select(Offset position) => setState(
                  () => selectedDay =
                      ((position.dx - 8) /
                              (constraints.maxWidth - 16) *
                              (days - 1))
                          .round()
                          .clamp(0, days - 1),
                );
                return MouseRegion(
                  onHover: (event) => select(event.localPosition),
                  child: GestureDetector(
                    onTapDown: (details) => select(details.localPosition),
                    onHorizontalDragUpdate: (details) =>
                        select(details.localPosition),
                    child: Semantics(
                      label:
                          'Interactive assistance trend graph. Tap a day for exact figures, or expand daily figures below.',
                      child: SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _OperationsLinePainter(
                            plotted,
                            visible,
                            colors,
                            Theme.of(context).colorScheme.outlineVariant,
                            index,
                            !single,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    dateLabel(0),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    dateLabel(days ~/ 2),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    dateLabel(days - 1),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (index != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '${dateLabel(index)}  |  ${visible.map((i) => '${names[i]}: ${actual(i, values[i][index])}').join('  |  ')}',
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (var i = 0; i < 4; i++)
                  Text(
                    '${names[i]}: ${actual(i, totals[i])}',
                    style: TextStyle(
                      color: colors[i],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Response time: request to first acceptance, grouped by acceptance date. Service value: completed final bills, not app revenue. Missing final bills are excluded.',
              style: TextStyle(fontSize: 12),
            ),
            if (capped)
              const Text(
                'Record limit reached. Figures may be incomplete (maximum 1,000 records per date query).',
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('View daily figures'),
              children: [
                for (var d = 0; d < days; d++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '${dateLabel(d)}: ${List.generate(4, (i) => '${names[i]} ${actual(i, values[i][d])}').join(', ')}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationsLinePainter extends CustomPainter {
  _OperationsLinePainter(
    this.values,
    this.visible,
    this.colors,
    this.grid,
    this.selected,
    this.comparison,
  );
  final List<List<double?>> values;
  final Set<int> visible;
  final List<Color> colors;
  final Color grid;
  final int? selected;
  final bool comparison;
  @override
  void paint(Canvas canvas, Size size) {
    final max = comparison
        ? 100.0
        : values[visible.single].whereType<double>().fold<double>(
            1,
            (a, b) => a > b ? a : b,
          );
    const inset = 8.0;
    for (var i = 0; i < 5; i++) {
      final y = inset + (size.height - 16) * i / 4;
      canvas.drawLine(
        Offset(inset, y),
        Offset(size.width - inset, y),
        Paint()
          ..color = grid
          ..strokeWidth = .5,
      );
    }
    for (final metric in visible) {
      var connected = false;
      final path = Path();
      for (var d = 0; d < values[metric].length; d++) {
        final value = values[metric][d];
        if (value == null) {
          connected = false;
          continue;
        }
        final point = Offset(
          inset + (size.width - 16) * d / (values[metric].length - 1),
          inset + (size.height - 16) * (1 - value / max),
        );
        if (connected) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          connected = true;
        }
        canvas.drawCircle(
          point,
          selected == d ? 4 : 2,
          Paint()..color = colors[metric],
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colors[metric]
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (selected != null) {
      final x = inset + (size.width - 16) * selected! / (values[0].length - 1);
      canvas.drawLine(
        Offset(x, inset),
        Offset(x, size.height - inset),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OperationsLinePainter old) => true;
}
