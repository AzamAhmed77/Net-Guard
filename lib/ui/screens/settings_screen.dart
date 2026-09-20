import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/managers/vpn_manager.dart';
import 'permissions_modal.dart';
import 'about_modal.dart';
import 'expert_settings_modal.dart';
import 'live_logs_modal.dart';

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
          // 2. MONITOR & PROTECTION
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
          // 4. SMART AUTOMATION & SCHEDULE
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
          // 5. UNIFIED SECURE DNS & IPV6 PROTECTION
          // ==========================================
          _buildSectionHeader(strings.isAr ? 'نظام خوادم DNS والحماية المتقدمة' : 'Secure DNS & Protection'),
          _buildCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.isAr ? 'مزود خادم DNS المفضل' : 'Preferred DNS Provider',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDohChip('Cloudflare', vpn.config.dohProvider == 'cloudflare', () {
                            vpn.setUnifiedDnsProvider('cloudflare');
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDohChip('AdGuard', vpn.config.dohProvider == 'adguard', () {
                            vpn.setUnifiedDnsProvider('adguard');
                          }),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDohChip('Google', vpn.config.dohProvider == 'google', () {
                            vpn.setUnifiedDnsProvider('google');
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildSwitchTile(
                icon: Icons.lock_outline_rounded,
                title: strings.dohTitle,
                subtitle: vpn.config.dohEnabled
                    ? (strings.isAr ? 'مفعّل: استعلامات مشفرة بالكامل عبر HTTPS لمنع التجسس' : 'Enabled: Fully encrypted queries via HTTPS')
                    : (strings.isAr ? 'معطّل: اتصال مباشر عبر بروتوكول IP العادي' : 'Disabled: Standard direct IP connection'),
                value: vpn.config.dohEnabled,
                onChanged: (val) => vpn.setDohEnabled(val),
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildSwitchTile(
                icon: Icons.security_rounded,
                title: strings.ipv6ProtectionTitle,
                subtitle: strings.ipv6ProtectionDesc,
                value: vpn.config.ipv6LeakProtection,
                onChanged: (val) => vpn.setIpv6LeakProtection(val),
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


  Widget _buildDohChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.borderDark),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
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
