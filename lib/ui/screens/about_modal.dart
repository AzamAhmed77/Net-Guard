import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../widgets/glass_card.dart';

class AboutModal extends StatelessWidget {
  const AboutModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                  children: const [
                    Icon(Icons.info_rounded, color: AppColors.amber, size: 26),
                    SizedBox(width: 8),
                    Text('حول Net Guard & الأمان', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                children: const [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.shield_rounded, size: 36, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text('Net Guard Framework v1.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Network Guardian & Intelligent Traffic Controller', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'نظام بيئي سيبراني محلي يعتمد على مبادئ الثقة الصفرية (Zero-Trust) ومعالجة الحزم على مستوى النواة (Kernel-Level) دون الحاجة لأي خوادم خارجية لحماية الخصوصية المطلقة 100%.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderDark),
            const SizedBox(height: 8),
            const Center(
              child: Text('© 2027 Net Guard Security. جميع الحقوق محفوظة.', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryDark)),
            ),
          ],
        ),
      ),
    );
  }
}
