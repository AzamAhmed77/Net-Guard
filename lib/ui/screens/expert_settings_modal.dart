import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/themes/app_colors.dart';
import '../widgets/glass_card.dart';

class ExpertSettingsModal extends StatefulWidget {
  const ExpertSettingsModal({Key? key}) : super(key: key);

  @override
  State<ExpertSettingsModal> createState() => _ExpertSettingsModalState();
}

class _ExpertSettingsModalState extends State<ExpertSettingsModal> {
  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<VpnManager>(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.primaryLight, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'الإعدادات المتقدمة (Expert Settings)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildOptionRow(
                title: 'وحدة تسريع النواة eBPF Kernel',
                subtitle: 'فلترة الحزم وتقييد السرعة داخل Kernel Space لتوفير البطارية',
                value: manager.config.ebpfEnabled,
                onChanged: (val) {
                  setState(() => manager.config.ebpfEnabled = val);
                  manager.syncNativeSettings();
                  manager.addLog("INFO", "تم ${val ? 'تفعيل' : 'إيقاف'} وحدة eBPF Kernel.");
                },
              ),

              const Divider(color: AppColors.borderDark, height: 20),

              _buildOptionRow(
                title: 'تحليل الحزم العميق (DPI Inspection)',
                subtitle: 'تحليل أنواع حركة المرور وتطبيق قواعد جودة الخدمة QoS',
                value: manager.config.dpiEnabled,
                onChanged: (val) {
                  setState(() => manager.config.dpiEnabled = val);
                  manager.syncNativeSettings();
                  manager.addLog("INFO", "تم ${val ? 'تفعيل' : 'إيقاف'} وحدة DPI.");
                },
              ),

              const Divider(color: AppColors.borderDark, height: 20),

              _buildOptionRow(
                title: 'حماية DNS Rebinding Protection',
                subtitle: 'منع البرمجيات الخبيثة من استغلال الشبكات المحلية',
                value: manager.config.dnsRebindingProtection,
                onChanged: (val) {
                  setState(() => manager.config.dnsRebindingProtection = val);
                  manager.syncNativeSettings();
                  manager.addLog("INFO", "تم ${val ? 'تفعيل' : 'إيقاف'} حماية DNS Rebinding.");
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondaryDark)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            activeColor: AppColors.green,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
