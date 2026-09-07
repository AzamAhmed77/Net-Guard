import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/themes/app_colors.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/localization/app_strings.dart';
import '../widgets/glass_card.dart';

class AboutModal extends StatelessWidget {
  const AboutModal({super.key});

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context, listen: false);
    final strings = AppStrings(vpn.isArabic);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_rounded, color: AppColors.amber, size: 26),
                    const SizedBox(width: 8),
                    Text(strings.aboutTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.shield_rounded, size: 36, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(strings.aboutFrameworkVersion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(strings.aboutFrameworkDesc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.aboutBody,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderDark),
            const SizedBox(height: 8),
            Center(
              child: Text(strings.aboutCopyright, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
            ),
          ],
        ),
      ),
    );
  }
}
