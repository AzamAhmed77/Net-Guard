import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';

class DnsTab extends StatelessWidget {
  const DnsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context);
    final strings = AppStrings(vpn.isArabic);
    final isVpnActive = vpn.config.isVpnActive;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ==========================================
        // 1. HERO BLOCKER STATUS CARD
        // ==========================================
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isVpnActive ? AppColors.accent.withOpacity(0.4) : AppColors.borderDark,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVpnActive
                          ? AppColors.accent.withOpacity(0.15)
                          : AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isVpnActive
                            ? AppColors.accent.withOpacity(0.3)
                            : AppColors.borderDark,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isVpnActive ? AppColors.accent : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isVpnActive
                              ? (strings.isAr ? 'محمي ومفعل' : 'Protected')
                              : (strings.isAr ? 'متوقف' : 'Inactive'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isVpnActive ? AppColors.accent : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.shield_rounded,
                    color: AppColors.accent,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                isVpnActive ? strings.blockerActive : strings.blockerInactive,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isVpnActive ? strings.blockerActiveSub : strings.blockerInactiveSub,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => vpn.toggleVpn(),
                  icon: Icon(
                    isVpnActive ? Icons.power_settings_new_rounded : Icons.flash_on_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    isVpnActive ? strings.stopBlocker : strings.startBlocker,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isVpnActive ? AppColors.surfaceHover : AppColors.accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isVpnActive ? AppColors.borderDark : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ==========================================
        // 2. DEFAULT ACTION POLICY (ALLOW ALL vs BLOCK ALL)
        // ==========================================
        _buildSectionHeader(strings.defaultAction.toUpperCase()),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        vpn.toggleMasterBlockAll(false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !vpn.isBlockAllMode && vpn.activeSecurityProfile != 'custom'
                              ? AppColors.accent
                              : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !vpn.isBlockAllMode && vpn.activeSecurityProfile != 'custom'
                                ? AppColors.accent
                                : AppColors.borderDark,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          strings.allowAll,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: !vpn.isBlockAllMode && vpn.activeSecurityProfile != 'custom'
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        vpn.toggleMasterBlockAll(true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: vpn.isBlockAllMode ? AppColors.red : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: vpn.isBlockAllMode ? AppColors.red : AppColors.borderDark,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          strings.blockAll,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: vpn.isBlockAllMode ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await vpn.restoreAndApplyCustomProfile();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: vpn.activeSecurityProfile == 'custom' && !vpn.isBlockAllMode
                              ? const Color(0xFF8B5CF6)
                              : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: vpn.activeSecurityProfile == 'custom' && !vpn.isBlockAllMode
                                ? const Color(0xFF8B5CF6)
                                : AppColors.borderDark,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          strings.filterCustom,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: vpn.activeSecurityProfile == 'custom' && !vpn.isBlockAllMode
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                vpn.isBlockAllMode
                    ? strings.blockAllDesc
                    : (vpn.activeSecurityProfile == 'custom'
                        ? (strings.isAr
                            ? 'الوضع المخصص: تم تطبيق إعدادات وتخصيصات التطبيقات المحفوظة'
                            : 'Custom Mode: Saved app settings and rules applied')
                        : strings.allowAllDesc),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ==========================================
        // 3. SMART DNS FILTERS
        // ==========================================
        _buildSectionHeader(strings.dnsFiltersTitle.toUpperCase()),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: [
              _buildSwitchTile(
                icon: Icons.ad_units_outlined,
                title: strings.blockAdsTitle,
                subtitle: strings.blockAdsDesc,
                value: vpn.config.blockAds,
                onChanged: (val) {
                  vpn.config.blockAds = val;
                  vpn.syncNativeSettings();
                  vpn.refresh();
                },
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildSwitchTile(
                icon: Icons.family_restroom_outlined,
                title: strings.blockAdultTitle,
                subtitle: strings.blockAdultDesc,
                value: vpn.config.blockAdult,
                onChanged: (val) {
                  vpn.config.blockAdult = val;
                  vpn.syncNativeSettings();
                  vpn.refresh();
                },
              ),
              const Divider(color: AppColors.borderDark, height: 1),
              _buildSwitchTile(
                icon: Icons.public_off_outlined,
                title: strings.blockSocialTitle,
                subtitle: strings.blockSocialDesc,
                value: vpn.config.blockSocial,
                onChanged: (val) {
                  vpn.config.blockSocial = val;
                  vpn.syncNativeSettings();
                  vpn.refresh();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ==========================================
        // 4. SMART SCHEDULE
        // ==========================================
        _buildSectionHeader(strings.enableSchedule.toUpperCase()),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCardDark,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.enableSchedule,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.scheduleDesc,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: vpn.config.schedEnabled,
                    activeColor: AppColors.accent,
                    onChanged: (val) {
                      vpn.config.schedEnabled = val;
                      vpn.syncNativeSettings();
                      vpn.refresh();
                    },
                  ),
                ],
              ),
              if (vpn.config.schedEnabled) ...[
                const SizedBox(height: 12),
                const Divider(color: AppColors.borderDark, height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePicker(
                        context,
                        label: strings.fromHour,
                        hour: vpn.config.schedStartH,
                        minute: vpn.config.schedStartM,
                        onTimePicked: (h, m) {
                          vpn.config.schedStartH = h;
                          vpn.config.schedStartM = m;
                          vpn.syncNativeSettings();
                          vpn.refresh();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimePicker(
                        context,
                        label: strings.toHour,
                        hour: vpn.config.schedEndH,
                        minute: vpn.config.schedEndM,
                        onTimePicked: (h, m) {
                          vpn.config.schedEndH = h;
                          vpn.config.schedEndM = m;
                          vpn.syncNativeSettings();
                          vpn.refresh();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

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

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
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
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(
    BuildContext context, {
    required String label,
    required int hour,
    required int minute,
    required Function(int h, int m) onTimePicked,
  }) {
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
        );
        if (time != null) {
          onTimePicked(time.hour, time.minute);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(timeStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
