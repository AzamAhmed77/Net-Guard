import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../widgets/glass_card.dart';

class HotspotControllerModal extends StatelessWidget {
  const HotspotControllerModal({super.key});

  static const List<Map<String, dynamic>> _speedPresets = [
    {'kbps': 64, 'labelAr': '64 KB/s (توفير فائق)', 'labelEn': '64 KB/s (Ultra Eco)'},
    {'kbps': 128, 'labelAr': '128 KB/s (توفير)', 'labelEn': '128 KB/s (Eco)'},
    {'kbps': 256, 'labelAr': '256 KB/s (مراسلة)', 'labelEn': '256 KB/s (Chat)'},
    {'kbps': 512, 'labelAr': '512 KB/s (عادي)', 'labelEn': '512 KB/s (Normal)'},
    {'kbps': 1024, 'labelAr': '1 MB/s (فيديو)', 'labelEn': '1 MB/s (Video)'},
    {'kbps': 2048, 'labelAr': '2 MB/s (سريع)', 'labelEn': '2 MB/s (Fast)'},
    {'kbps': -1, 'labelAr': 'مفتوح (∞)', 'labelEn': 'Unlimited (∞)'},
  ];

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context);
    final strings = AppStrings(vpn.isArabic);
    final isAr = vpn.isArabic;
    final isRunning = vpn.isHotspotRunning;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── العنوان وزر الإغلاق ──
            Row(
              children: [
                Icon(
                  Icons.wifi_tethering_rounded,
                  color: isRunning ? AppColors.accent : AppColors.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.hotspotControllerTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── 1. تشغيل أو إيقاف الخدمة ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isRunning
                    ? AppColors.accent.withValues(alpha: 0.1)
                    : AppColors.surfaceCardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isRunning
                      ? AppColors.accent.withValues(alpha: 0.4)
                      : AppColors.borderDark,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRunning
                        ? (isAr ? 'الخدمة تعمل 🟢' : 'Service ON 🟢')
                        : (isAr ? 'الخدمة متوقفة ⚪' : 'Service OFF ⚪'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isRunning ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                  Switch.adaptive(
                    value: isRunning,
                    activeThumbColor: AppColors.accent,
                    onChanged: (_) => vpn.toggleHotspotProxy(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 2. تحديد السرعة ──
            Text(
              isAr ? 'تحديد سرعة البث:' : 'Select Speed Limit:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _speedPresets.map((preset) {
                final kbps = preset['kbps'] as int;
                final isSelected = vpn.hotspotDownloadLimitKbps == kbps;
                return ChoiceChip(
                  label: Text(
                    isAr ? preset['labelAr'] : preset['labelEn'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceCardDark,
                  side: BorderSide(
                    color: isSelected ? AppColors.accent : AppColors.borderDark,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      vpn.setHotspotLimits(downloadKbps: kbps, uploadKbps: kbps);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── زر تم / إغلاق ──
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceHover,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.borderDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  strings.close,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
