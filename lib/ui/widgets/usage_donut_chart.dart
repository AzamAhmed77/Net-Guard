import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/models/app_info.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';

class UsageDonutChart extends StatefulWidget {
  final List<MapEntry<AppInfo, double>> usageList;
  final double totalUsage;
  final AppStrings strings;
  final EdgeInsetsGeometry? margin;

  const UsageDonutChart({
    super.key,
    required this.usageList,
    required this.totalUsage,
    required this.strings,
    this.margin,
  });

  @override
  State<UsageDonutChart> createState() => _UsageDonutChartState();
}

class _UsageDonutChartState extends State<UsageDonutChart> {
  int _touchedIndex = -1;

  static const List<Color> _sliceColors = [
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF64748B), // Slate / Others
  ];

  String _formatMb(double mb) {
    if (mb >= 1024.0) {
      return '${(mb / 1024.0).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalUsage <= 0.05 || widget.usageList.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build top slices (up to 4 items + "Others")
    final List<MapEntry<String, double>> slices = [];
    double accountedMb = 0.0;
    final int topCount = widget.usageList.length < 4 ? widget.usageList.length : 4;

    for (int i = 0; i < topCount; i++) {
      final entry = widget.usageList[i];
      if (entry.value > 0.01) {
        slices.add(MapEntry(entry.key.name, entry.value));
        accountedMb += entry.value;
      }
    }

    final double remainingMb = widget.totalUsage - accountedMb;
    if (remainingMb > 0.1 && widget.usageList.length > topCount) {
      slices.add(MapEntry(widget.strings.otherApps, remainingMb));
    }

    if (slices.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pie_chart_rounded, size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 8),
              Text(
                widget.strings.usageChartTitle,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart + Legend layout
          Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex =
                                  pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2.5,
                        centerSpaceRadius: 36,
                        sections: List.generate(slices.length, (i) {
                          final isTouched = i == _touchedIndex;
                          final radius = isTouched ? 28.0 : 22.0;
                          final color = _sliceColors[i % _sliceColors.length];
                          final sliceVal = slices[i].value;

                          return PieChartSectionData(
                            color: color,
                            value: sliceVal,
                            title: '',
                            radius: radius,
                            badgePositionPercentageOffset: 0.98,
                          );
                        }),
                      ),
                    ),
                    // Center Info
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMb(widget.totalUsage),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.strings.totalUsageCenter,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Legend
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(slices.length, (i) {
                    final item = slices[i];
                    final color = _sliceColors[i % _sliceColors.length];
                    final pct = widget.totalUsage > 0
                        ? ((item.value / widget.totalUsage) * 100).toStringAsFixed(1)
                        : '0';
                    final isTouched = i == _touchedIndex;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isTouched ? color.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isTouched ? FontWeight.bold : FontWeight.w500,
                                color: isTouched ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
