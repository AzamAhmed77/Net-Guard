import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/managers/vpn_manager.dart';
import 'permissions_modal.dart';
import 'about_modal.dart';
import 'expert_settings_modal.dart';
import 'live_logs_modal.dart';
import '../widgets/hotspot_qr_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<Color> _accentColors = [
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF8B5CF6), // Purple
    Color(0xFF6366F1), // Indigo
    Color(0xFFF59E0B), // Amber
  ];

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context);
    final strings = AppStrings(vpn.isArabic);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          strings.settingsTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ==========================================
          // 1. THEME & ACCENT COLOR
          // ==========================================
          _buildSectionHeader(strings.themeSection),
          _buildCard(
            children: [
              _buildTile(
                icon: Icons.dark_mode_outlined,
                title: strings.themeLabel,
                subtitle: strings.themeDark,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.accentColor,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: _accentColors.map((color) {
                        final isSelected = vpn.accentColorValue == color.toARGB32();
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () => vpn.setAccentColor(color),
                            child: _buildColorDot(color, isSelected: isSelected),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 2. CUSTOM PROFILE SETTINGS
          // ==========================================
          _buildSectionHeader(strings.customProfileTitle.toUpperCase()),
          _buildCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.app_settings_alt_rounded, color: AppColors.accent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  strings.customProfileCardTitle,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHover,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderDark),
                          ),
                          child: Text(
                            '${vpn.customizedAppsCount} ${vpn.isArabic ? "تطبيق مخصص" : "Custom Apps"}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      strings.customProfileDesc,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await vpn.saveCustomProfileSettings();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceHover,
                                foregroundColor: AppColors.accent,
                                elevation: 0,
                                side: const BorderSide(color: AppColors.borderDark),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.save_rounded, size: 18),
                              label: Text(
                                strings.saveCustomProfileBtn,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await vpn.restoreAndApplyCustomProfile();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceHover,
                              foregroundColor: const Color(0xFF8B5CF6),
                              elevation: 0,
                              side: const BorderSide(color: AppColors.borderDark),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.restore_rounded, size: 18),
                            label: Text(
                              strings.isAr ? 'استعادة' : 'Restore',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 3. MONITOR & PROTECTION
          // ==========================================
          _buildSectionHeader(strings.monitorProtectionSection),
          _buildCard(
            children: [
              _buildSwitchTile(
                icon: Icons.speed,
                title: strings.bgMonitor,
                subtitle: strings.bgMonitorDesc,
                value: vpn.isMonitorRunning,
                onChanged: (_) => vpn.toggleMonitorService(),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildSwitchTile(
                icon: Icons.warning_amber_rounded,
                title: strings.dataSpike,
                subtitle: strings.dataSpikeDesc,
                value: vpn.isSpikeAlertEnabled,
                onChanged: (_) => vpn.toggleSpikeAlert(),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildSwitchTile(
                icon: Icons.screen_lock_portrait_outlined,
                title: strings.lockdownScreenOff,
                subtitle: strings.lockdownScreenOffDesc,
                value: vpn.lockdownOnScreenOff,
                onChanged: (val) => vpn.toggleLockdownOnScreenOff(val),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildSwitchTile(
                icon: Icons.shield_outlined,
                title: strings.autoQuarantine,
                subtitle: strings.autoQuarantineDesc,
                value: vpn.autoQuarantineNewApps,
                onChanged: (val) => vpn.toggleAutoQuarantine(val),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 4. HOTSPOT SPEED CONTROLLER
          // ==========================================
          _buildSectionHeader(strings.hotspotSectionTitle),
          _buildCard(
            children: [
              _buildSwitchTile(
                icon: Icons.wifi_tethering_rounded,
                title: strings.hotspotControllerTitle,
                subtitle: vpn.isHotspotRunning
                    ? (vpn.isArabic ? 'الخدمة تعمل 🟢 (مستقلة عن VPN)' : 'Service ON 🟢 (Independent)')
                    : (vpn.isArabic ? 'الخدمة متوقفة ⚪ (ميزة اختيارية منفصلة)' : 'Service OFF ⚪ (Optional)'),
                value: vpn.isHotspotRunning,
                onChanged: (_) => vpn.toggleHotspotProxy(),
              ),
              if (vpn.isHotspotRunning) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.hotspotIndependentNote,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(color: AppColors.borderDark, height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vpn.isArabic ? 'تحديد سرعة البث للأجهزة المتصلة:' : 'Select Speed Limit for Devices:',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildHotspotSpeedChip(64, '64 KB/s', vpn),
                        _buildHotspotSpeedChip(128, '128 KB/s', vpn),
                        _buildHotspotSpeedChip(256, '256 KB/s', vpn),
                        _buildHotspotSpeedChip(512, '512 KB/s', vpn),
                        _buildHotspotSpeedChip(1024, '1 MB/s', vpn),
                        _buildHotspotSpeedChip(2048, '2 MB/s', vpn),
                        _buildHotspotSpeedChip(-1, vpn.isArabic ? 'مفتوح (∞)' : 'Unlimited (∞)', vpn),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              ListTile(
                leading: Icon(Icons.qr_code_2_rounded, color: AppColors.accent, size: 20),
                title: Text(
                  strings.hotspotQrCodeBtn,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  vpn.isArabic ? 'مسح سريع لربط أجهزة الضيوف تلقائياً' : 'Quick scan to connect guest devices',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                onTap: () => showHotspotQrDialog(context, strings),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              ListTile(
                leading: Icon(Icons.help_outline_rounded, color: AppColors.accent, size: 20),
                title: Text(
                  strings.hotspotSetupGuide,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  vpn.isArabic ? 'اضغط لعرض خطوات ربط الأجهزة بالبروكسي' : 'Tap to view proxy setup guide',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                onTap: () => _showHotspotGuideDialog(context, strings, vpn),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 4.5. SMART AUTOMATION & SCHEDULE
          // ==========================================
          _buildSectionHeader(strings.scheduleSection),
          _buildCard(
            children: [
              SwitchListTile.adaptive(
                secondary: Icon(
                  Icons.schedule_rounded,
                  color: vpn.isScheduleEnabled ? AppColors.accent : AppColors.textSecondary,
                  size: 22,
                ),
                title: Text(
                  strings.scheduleEnableTitle,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  strings.scheduleEnableDesc,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                value: vpn.isScheduleEnabled,
                activeTrackColor: AppColors.accent,
                onChanged: (val) {
                  vpn.updateScheduleSettings(enabled: val);
                },
              ),
              if (vpn.isScheduleEnabled) ...[
                if (vpn.isScheduleCurrentlyActive) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, color: AppColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.scheduleStatusActive,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(color: AppColors.borderDark, height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimePickerTile(
                              context: context,
                              label: strings.scheduleStartTime,
                              hour: vpn.scheduleStartHour,
                              minute: vpn.scheduleStartMinute,
                              isAr: vpn.isArabic,
                              onTimePicked: (h, m) {
                                vpn.updateScheduleSettings(startHour: h, startMinute: m);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTimePickerTile(
                              context: context,
                              label: strings.scheduleEndTime,
                              hour: vpn.scheduleEndHour,
                              minute: vpn.scheduleEndMinute,
                              isAr: vpn.isArabic,
                              onTimePicked: (h, m) {
                                vpn.updateScheduleSettings(endHour: h, endMinute: m);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        strings.scheduleAction,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildScheduleActionOption(
                              label: strings.scheduleActionEco,
                              icon: Icons.eco_rounded,
                              isSelected: vpn.scheduleAction == 'eco',
                              onTap: () => vpn.updateScheduleSettings(action: 'eco'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildScheduleActionOption(
                              label: strings.scheduleActionLockdown,
                              icon: Icons.lock_outline_rounded,
                              isSelected: vpn.scheduleAction == 'lockdown',
                              onTap: () => vpn.updateScheduleSettings(action: 'lockdown'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 5. ENCRYPTED DNS PROVIDER
          // ==========================================
          _buildSectionHeader(strings.dnsProviderTitle),
          _buildCard(
            children: [
              _buildDnsRadio(
                title: 'Cloudflare (1.1.1.1)',
                subtitle: strings.isAr ? 'أسرع DNS عالمي مشفر مع حماية الخصوصية' : 'Fastest encrypted DNS with zero logging',
                servers: ['1.1.1.1', '1.0.0.1'],
                providerName: 'Cloudflare',
                vpn: vpn,
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildDnsRadio(
                title: 'AdGuard DNS',
                subtitle: strings.isAr ? 'حجب تلقائي لكافة الإعلانات والتتبع' : 'Auto blocks all ads & tracking domains',
                servers: ['94.140.14.14', '94.140.15.15'],
                providerName: 'AdGuard',
                vpn: vpn,
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildDnsRadio(
                title: 'Google Public DNS',
                subtitle: strings.isAr ? 'خوادم موثوقة ومستقرة عالمياً (8.8.8.8)' : 'Reliable and fast global resolver',
                servers: ['8.8.8.8', '8.8.4.4'],
                providerName: 'Google',
                vpn: vpn,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 5. GENERAL & PERMISSIONS
          // ==========================================
          _buildSectionHeader(strings.generalSection),
          _buildCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.language, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          strings.languageLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        children: [
                          _buildLangTab('العربية', vpn.isArabic, () {
                            if (!vpn.isArabic) vpn.setLanguage('ar');
                          }),
                          _buildLangTab('English', !vpn.isArabic, () {
                            if (vpn.isArabic) vpn.setLanguage('en');
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildTile(
                icon: Icons.calendar_today_outlined,
                title: strings.planCycle,
                subtitle: strings.cycleStarts1st,
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildActionTile(
                icon: Icons.security,
                title: strings.systemPermissions,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const PermissionsModal(),
                ),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildActionTile(
                icon: Icons.tune_rounded,
                title: strings.expertSettingsTitle,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const ExpertSettingsModal(),
                ),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildActionTile(
                icon: Icons.terminal_rounded,
                title: strings.liveEventLogs,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const LiveLogsModal(),
                ),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildActionTile(
                icon: Icons.info_outline,
                title: strings.aboutVersion,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const AboutModal(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: value ? AppColors.accent : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              activeThumbColor: AppColors.accent,
              activeTrackColor: AppColors.accent.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.surfaceDark,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildDnsRadio({
    required String title,
    required String subtitle,
    required List<String> servers,
    required String providerName,
    required VpnManager vpn,
  }) {
    final isSelected = vpn.config.selectedDnsProvider == providerName;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        vpn.setDnsProvider(providerName);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color, {required bool isSelected}) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }

  Widget _buildLangTab(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildHotspotSpeedChip(int kbps, String label, VpnManager vpn) {
    final isSelected = vpn.hotspotDownloadLimitKbps == kbps;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surfaceHover,
      side: BorderSide(
        color: isSelected ? AppColors.accent : AppColors.borderDark,
      ),
      onSelected: (selected) {
        if (selected) {
          vpn.setHotspotLimits(downloadKbps: kbps, uploadKbps: kbps);
        }
      },
    );
  }

  void _showHotspotGuideDialog(BuildContext context, AppStrings strings, VpnManager vpn) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        title: Row(
          children: [
            Icon(Icons.wifi_tethering_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.hotspotSetupGuide,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.hotspotGuideIntro,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              _buildGuideStep(strings.hotspotGuideStep1),
              const SizedBox(height: 8),
              _buildGuideStep(strings.hotspotGuideStep2),
              const SizedBox(height: 8),
              _buildGuideStep(strings.hotspotGuideStep3),
              const SizedBox(height: 8),
              _buildGuideStep(strings.hotspotGuideStep4),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${strings.hotspotIpLabel} 192.168.43.1',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${strings.hotspotPortLabel} 8282',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.qr_code_2_rounded, color: AppColors.accent, size: 22),
                          tooltip: strings.hotspotQrCodeBtn,
                          onPressed: () => showHotspotQrDialog(context, strings),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: AppColors.accent, size: 20),
                          tooltip: 'نسخ',
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: '192.168.43.1:8282'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(strings.hotspotCopySuccess),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        strings.hotspotIndependentNote,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              strings.close,
              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildGuideStep(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, color: AppColors.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerTile({
    required BuildContext context,
    required String label,
    required int hour,
    required int minute,
    required bool isAr,
    required void Function(int hour, int minute) onTimePicked,
  }) {
    final time = TimeOfDay(hour: hour, minute: minute);
    final formattedTime = time.format(context);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onTimePicked(picked.hour, picked.minute);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.bgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedTime,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
                const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleActionOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderDark,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
