import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/themes/app_colors.dart';
import '../../core/services/method_channel_service.dart';
import '../../core/localization/app_strings.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({Key? key}) : super(key: key);

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _activePeriod = 'week'; // 'week', 'month', 'this_month'
  String _networkFilter = 'all'; // 'all', 'wifi', 'mobile'
  Map<String, dynamic>? _statsWeek;
  Map<String, dynamic>? _statsMonth;
  Map<String, dynamic>? _statsThisMonth;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);
    try {
      final week = await MethodChannelService.getRealPeriodData('week');
      final month = await MethodChannelService.getRealPeriodData('month');
      final thisMonth = await MethodChannelService.getRealPeriodData('this_month');
      if (mounted) {
        setState(() {
          _statsWeek = week;
          _statsMonth = month;
          _statsThisMonth = thisMonth;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMb(double mb) {
    if (mb <= 0.05) return '0.0 MB';
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(2)} MB';
  }

  double _getCardValue(Map<String, dynamic>? stats) {
    if (stats == null) return 0.0;
    switch (_networkFilter) {
      case 'wifi':
        return (stats['wifiTotalMb'] as num?)?.toDouble() ?? 0.0;
      case 'mobile':
        return (stats['mobileTotalMb'] as num?)?.toDouble() ?? 0.0;
      default:
        return (stats['totalMb'] as num?)?.toDouble() ?? 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context);
    final strings = AppStrings(vpn.isArabic);

    // Active Dataset based on period
    Map<String, dynamic>? currentStats;
    switch (_activePeriod) {
      case 'month':
        currentStats = _statsMonth;
        break;
      case 'this_month':
        currentStats = _statsThisMonth;
        break;
      default:
        currentStats = _statsWeek;
    }

    // Top Cards Data (reacts to network filter)
    final double weekVal = _getCardValue(_statsWeek);
    final double monthVal = _getCardValue(_statsMonth);
    final double thisMonthVal = _getCardValue(_statsThisMonth);

    // Daily Points from current active period
    final List<Map<String, dynamic>> dailyPoints = [];
    final rawPoints = currentStats?['dailyPoints'];
    if (rawPoints is List) {
      for (var item in rawPoints) {
        if (item is Map) {
          final Map<String, dynamic> point = {};
          item.forEach((key, value) => point[key.toString()] = value);
          dailyPoints.add(point);
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // ==========================================
        // 1. TOP SUMMARY CARDS (7 Days, 30 Days, This Month)
        // ==========================================
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: strings.last7Days,
                value: _formatMb(weekVal),
                isSelected: _activePeriod == 'week',
                onTap: () => setState(() => _activePeriod = 'week'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                title: strings.last30Days,
                value: _formatMb(monthVal),
                isSelected: _activePeriod == 'month',
                onTap: () => setState(() => _activePeriod = 'month'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSummaryCard(
                title: strings.thisMonth,
                value: _formatMb(thisMonthVal),
                isSelected: _activePeriod == 'this_month',
                onTap: () => setState(() => _activePeriod = 'this_month'),
              ),
            ),
          ],
        ),
        if (_isLoading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ],
        const SizedBox(height: 20),

        // ==========================================
        // 2. DAILY USAGE HISTORY HEADER + NETWORK FILTER MENU
        // ==========================================
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                strings.dailyUsageHistory,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              PopupMenuButton<String>(
                initialValue: _networkFilter,
                onSelected: (val) {
                  setState(() => _networkFilter = val);
                },
                color: AppColors.surfaceCardDark,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.borderDark),
                ),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 16,
                          color: _networkFilter == 'all' ? AppColors.accent : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          strings.allNetworks,
                          style: TextStyle(
                            color: _networkFilter == 'all' ? AppColors.accent : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: _networkFilter == 'all' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'wifi',
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_rounded,
                          size: 16,
                          color: _networkFilter == 'wifi' ? AppColors.accent : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          strings.wifiOnly,
                          style: TextStyle(
                            color: _networkFilter == 'wifi' ? AppColors.accent : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: _networkFilter == 'wifi' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'mobile',
                    child: Row(
                      children: [
                        Icon(
                          Icons.signal_cellular_alt_rounded,
                          size: 16,
                          color: _networkFilter == 'mobile' ? const Color(0xFFF59E0B) : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          strings.mobileOnly,
                          style: TextStyle(
                            color: _networkFilter == 'mobile' ? const Color(0xFFF59E0B) : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: _networkFilter == 'mobile' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _networkFilter != 'all' ? AppColors.accent : AppColors.borderDark,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_rounded,
                        size: 16,
                        color: _networkFilter != 'all' ? AppColors.accent : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _networkFilter == 'wifi'
                            ? strings.wifiOnly
                            : _networkFilter == 'mobile'
                                ? (strings.isAr ? 'بيانات الهاتف' : 'Mobile Only')
                                : (strings.isAr ? 'الكل' : 'All'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _networkFilter != 'all' ? AppColors.accent : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ==========================================
        // 3. DAILY USAGE LIST (Real Data)
        // ==========================================
        if (dailyPoints.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceCardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Center(
              child: Text(
                strings.noLogsYet,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...dailyPoints.map((point) {
            final label = point['label']?.toString() ?? '';
            final totalMb = (point['totalMb'] as num?)?.toDouble() ?? 0.0;
            final wifiMb = (point['wifiMb'] as num?)?.toDouble() ?? 0.0;
            final mobileMb = (point['mobileMb'] as num?)?.toDouble() ?? 0.0;
            final downloadMb = (point['downloadMb'] as num?)?.toDouble() ?? 0.0;
            final uploadMb = (point['uploadMb'] as num?)?.toDouble() ?? 0.0;

            double displayMb = totalMb;
            Color numberColor = AppColors.textPrimary;
            if (_networkFilter == 'wifi') {
              displayMb = wifiMb;
              numberColor = AppColors.accent;
            } else if (_networkFilter == 'mobile') {
              displayMb = mobileMb;
              numberColor = const Color(0xFFF59E0B);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showDayDetailDialog(
                  context: context,
                  label: _localizeDayLabel(label, strings),
                  strings: strings,
                  wifiDownMb: wifiMb > 0 ? wifiMb * (downloadMb / (totalMb > 0 ? totalMb : 1.0)) : 0.0,
                  wifiUpMb: wifiMb > 0 ? wifiMb * (uploadMb / (totalMb > 0 ? totalMb : 1.0)) : 0.0,
                  mobileDownMb: mobileMb > 0 ? mobileMb * (downloadMb / (totalMb > 0 ? totalMb : 1.0)) : 0.0,
                  mobileUpMb: mobileMb > 0 ? mobileMb * (uploadMb / (totalMb > 0 ? totalMb : 1.0)) : 0.0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _localizeDayLabel(label, strings),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.wifi_rounded,
                                  size: 13,
                                  color: _networkFilter == 'wifi' ? AppColors.accent : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatMb(wifiMb),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _networkFilter == 'wifi' ? FontWeight.bold : FontWeight.normal,
                                    color: _networkFilter == 'wifi' ? AppColors.accent : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.signal_cellular_alt_rounded,
                                  size: 13,
                                  color: _networkFilter == 'mobile' ? const Color(0xFFF59E0B) : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatMb(mobileMb),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: _networkFilter == 'mobile' ? FontWeight.bold : FontWeight.normal,
                                    color: _networkFilter == 'mobile' ? const Color(0xFFF59E0B) : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatMb(displayMb),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: numberColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceHover : AppColors.surfaceCardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _localizeDayLabel(String raw, AppStrings strings) {
    if (strings.isAr) {
      if (raw == 'Today' || raw == 'اليوم') return 'اليوم';
      if (raw == 'Yesterday' || raw == 'أمس') return 'أمس';
      return raw
          .replaceAll('Sunday', 'الأحد')
          .replaceAll('Monday', 'الإثنين')
          .replaceAll('Tuesday', 'الثلاثاء')
          .replaceAll('Wednesday', 'الأربعاء')
          .replaceAll('Thursday', 'الخميس')
          .replaceAll('Friday', 'الجمعة')
          .replaceAll('Saturday', 'السبت');
    } else {
      if (raw == 'اليوم' || raw == 'Today') return 'Today';
      if (raw == 'أمس' || raw == 'Yesterday') return 'Yesterday';
      return raw
          .replaceAll('الأحد', 'Sunday')
          .replaceAll('الإثنين', 'Monday')
          .replaceAll('الثلاثاء', 'Tuesday')
          .replaceAll('الأربعاء', 'Wednesday')
          .replaceAll('الخميس', 'Thursday')
          .replaceAll('الجمعة', 'Friday')
          .replaceAll('السبت', 'Saturday');
    }
  }

  // =========================================================================
  // DAY DETAIL MODAL (Matching User Screenshot 3)
  // =========================================================================
  void _showDayDetailDialog({
    required BuildContext context,
    required String label,
    required AppStrings strings,
    required double wifiDownMb,
    required double wifiUpMb,
    required double mobileDownMb,
    required double mobileUpMb,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.borderDark),
          ),
          title: Column(
            children: [
              Icon(Icons.calendar_today_rounded, size: 28, color: AppColors.accent),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // WiFi Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wifi_rounded, size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          strings.wiFi,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(strings.liveDownload, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text(_formatMb(wifiDownMb), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(strings.liveUpload, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text(_formatMb(wifiUpMb), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Mobile Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.signal_cellular_alt_rounded, size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          strings.mobileData,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(strings.liveDownload, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text(_formatMb(mobileDownMb), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(strings.liveUpload, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text(_formatMb(mobileUpMb), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.red),
              label: Text(strings.delete, style: const TextStyle(color: AppColors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.ok, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }



}
