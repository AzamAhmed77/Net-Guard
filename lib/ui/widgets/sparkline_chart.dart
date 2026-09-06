import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SparklineChartWidget extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;

  const SparklineChartWidget({
    Key? key,
    required this.data,
    required this.color,
    this.height = 45,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return SizedBox(height: height);

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
