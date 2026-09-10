import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/models/app_info.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/method_channel_service.dart';
import '../widgets/usage_donut_chart.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Map<String, double> _wifiTraffic = {};
  Map<String, double> _mobileTraffic = {};
  double _totalWifiMb = 0.0;
  double _totalMobileMb = 0.0;
  bool _hasLoadedTraffic = false;

  @override
  void initState() {
    super.initState();
    _loadTodayTraffic();
  }

  Future<void> _loadTodayTraffic() async {
    try {
      final data = await MethodChannelService.getPerAppTrafficByNetwork(
        session: 'today',
      );
      if (mounted) {
        setState(() {
          _wifiTraffic = Map<String, double>.from(
            (data['wifi'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
          );
          _mobileTraffic = Map<String, double>.from(
            (data['mobile'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
          );
          _totalWifiMb = (data['totalWifiMb'] as num?)?.toDouble() ?? 0.0;
          _totalMobileMb = (data['totalMobileMb'] as num?)?.toDouble() ?? 0.0;
          _hasLoadedTraffic = true;
        });
      }
    } catch (_) {}
  }

  String _formatSpeed(double kbps) {
    if (kbps <= 0) return '\u200E0 KB/s';
    if (kbps >= 1024) {
      return '\u200E${(kbps / 1024).toStringAsFixed(1)} MB/s';
    }
    return '\u200E${kbps.toStringAsFixed(0)} KB/s';
  }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context);
    final strings = AppStrings(vpn.isArabic);

    final dlLimit = vpn.config.downloadSpeedLimit;
    final isDownloadUnlimited = dlLimit < 0;
    final ulLimit = vpn.config.uploadSpeedLimit;
    final isUploadUnlimited = ulLimit < 0;

    // Build per-app usage list for the donut chart
    final List<AppInfo> allApps = List<AppInfo>.from(vpn.apps);
    final existingPkgs = allApps.map((a) => a.packageName).toSet();
    final allTrafficPkgs = {..._wifiTraffic.keys, ..._mobileTraffic.keys};

    for (final pkg in allTrafficPkgs) {
      if (!existingPkgs.contains(pkg)) {
        if (pkg == 'com.cybnux.tethering_hotspot') {
          allApps.add(AppInfo(
            name: vpn.isArabic ? 'نقطة اتصال الهواتف (بث)' : 'Tethering & Hotspot',
            packageName: pkg,
            isSystem: true,
          ));
        } else if (pkg == 'com.cybnux.uninstalled_apps') {
          allApps.add(AppInfo(
            name: vpn.isArabic ? 'تطبيقات محذوفة' : 'Uninstalled Applications',
            packageName: pkg,
            isSystem: false,
          ));
        } else {
          allApps.add(AppInfo(
            name: pkg,
            packageName: pkg,
            isSystem: false,
          ));
        }
        existingPkgs.add(pkg);
      }
    }

    final List<MapEntry<AppInfo, double>> usageList = allApps
        .map((app) {
          final usage = (_wifiTraffic[app.packageName] ?? 0.0) + (_mobileTraffic[app.packageName] ?? 0.0);
          return MapEntry(app, usage);
        })
        .where((entry) => entry.value > 0.01)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalUsage = (_totalWifiMb + _totalMobileMb) > 0
        ? (_totalWifiMb + _totalMobileMb)
        : usageList.fold(0.0, (s, e) => s + e.value);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ==========================================
        // 1. CURRENT SPEED CARD
        // ==========================================
        _buildSectionHeader(strings.currentSpeed.toUpperCase()),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.liveDownload,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatSpeed(vpn.currentDownloadSpeed),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_upward_rounded,
                            color: AppColors.textSecondary,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.liveUpload,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatSpeed(vpn.currentUploadSpeed),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: AppColors.borderDark, height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.averageSpeed,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatSpeed(vpn.avgDownloadSpeed),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.maximumSpeed,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatSpeed(vpn.peakDownloadSpeed),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ==========================================
        // 2. SPEED CONTROL & PRESETS CARD
        // ==========================================
        _buildSectionHeader(strings.speedControl.toUpperCase()),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceCardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Presets row
              Text(
                strings.speedPresets,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPresetChip(
                      label: strings.presetDefault,
                      isSelected: vpn.activePreset == 'default',
                      onTap: () => vpn.setPreset('default'),
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: strings.presetEco,
                      isSelected: vpn.activePreset == 'eco',
                      onTap: () => vpn.setPreset('eco'),
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: strings.presetUnlimited,
                      isSelected: vpn.activePreset == 'unlimited',
                      onTap: () => vpn.setPreset('unlimited'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // 2.1 DOWNLOAD SPEED LIMIT (SLIDER + MANUAL INPUT)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        strings.downloadSpeedLimit,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      _showSpeedInputDialog(
                        context: context,
                        title: strings.downloadSpeedLimit,
                        currentValue: dlLimit,
                        onConfirm: (val) => vpn.setDownloadSpeedLimit(val),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isDownloadUnlimited ? strings.noLimitsInfinite : '\u200E$dlLimit KB/s',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 12, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.surfaceHover,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: isDownloadUnlimited ? 5000.0 : dlLimit.toDouble().clamp(0.0, 5000.0),
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    onChanged: (val) {
                      final int limit = val.toInt();
                      vpn.setDownloadSpeedLimit(limit == 5000 ? -1 : limit);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // 2.2 UPLOAD SPEED LIMIT (SLIDER + MANUAL INPUT)
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        strings.uploadSpeedLimit,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      _showSpeedInputDialog(
                        context: context,
                        title: strings.uploadSpeedLimit,
                        currentValue: ulLimit,
                        onConfirm: (val) => vpn.setUploadSpeedLimit(val),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isUploadUnlimited ? strings.noLimitsInfinite : '\u200E$ulLimit KB/s',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 12, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Directionality(
                textDirection: TextDirection.ltr,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: AppColors.surfaceHover,
                    thumbColor: AppColors.accent,
                    overlayColor: AppColors.accent.withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: isUploadUnlimited ? 5000.0 : ulLimit.toDouble().clamp(0.0, 5000.0),
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    onChanged: (val) {
                      final int limit = val.toInt();
                      vpn.setUploadSpeedLimit(limit == 5000 ? -1 : limit);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // ==========================================
        // 3. DATA USAGE BREAKDOWN (DONUT CHART)
        // ==========================================
        if (_hasLoadedTraffic && totalUsage > 0.05 && usageList.isNotEmpty) ...[
          UsageDonutChart(
            usageList: usageList,
            totalUsage: totalUsage,
            strings: strings,
            margin: EdgeInsets.zero,
          ),
          const SizedBox(height: 22),
        ],

        const SizedBox(height: 100),
      ],
    );
  }

  void _showSpeedInputDialog({
    required BuildContext context,
    required String title,
    required int currentValue,
    required Function(int) onConfirm,
  }) {
    final controller = TextEditingController(
      text: currentValue < 0 ? '' : currentValue.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.borderDark),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.of(context).enterSpeedKbps,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '512 (أو 0 للكتم، أو -1 للمفتوح)',
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceHover,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                AppStrings.of(context).cancel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final text = controller.text.trim();
                final val = int.tryParse(text) ?? -1;
                onConfirm(val);
                Navigator.pop(ctx);
              },
              child: Text(
                AppStrings.of(context).setSpeed,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderDark,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
