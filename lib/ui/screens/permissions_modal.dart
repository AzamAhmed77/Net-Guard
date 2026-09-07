import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/themes/app_colors.dart';
import '../../core/services/method_channel_service.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/localization/app_strings.dart';

class PermissionsModal extends StatefulWidget {
  const PermissionsModal({super.key});

  @override
  State<PermissionsModal> createState() => _PermissionsModalState();
}

class _PermissionsModalState extends State<PermissionsModal>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<String, bool> _permissions = {
    'usageStats': false,
    'batteryOptimization': false,
    'notification': false,
    'vpn': false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    final status = await MethodChannelService.checkPermissionsStatus();
    if (mounted) {
      setState(() {
        _permissions = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context, listen: false);
    final strings = AppStrings(vpn.isArabic);

    final bool allOptimal = _permissions['usageStats'] == true &&
        _permissions['batteryOptimization'] == true &&
        _permissions['notification'] == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderDark, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Matte Minimalist Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCardDark,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(
                  bottom: BorderSide(color: AppColors.borderDark),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.permissionsTitle,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.permissionsSubtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Status Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: allOptimal
                    ? AppColors.green.withValues(alpha: 0.1)
                    : AppColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (allOptimal ? AppColors.green : AppColors.amber).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    allOptimal ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: allOptimal ? AppColors.green : AppColors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      allOptimal ? strings.permAllGranted : strings.permNotGranted,
                      style: TextStyle(
                        color: allOptimal ? AppColors.green : AppColors.amber,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body list
            Flexible(
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.accent),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        _buildPermissionTile(
                          icon: Icons.analytics_outlined,
                          color: AppColors.accent,
                          title: strings.permUsageTitle,
                          description: strings.permUsageDesc,
                          isGranted: _permissions['usageStats'] == true,
                          actionLabel: strings.permUsageAction,
                          onAction: () async {
                            await MethodChannelService.requestUsageStatsPermission();
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildPermissionTile(
                          icon: Icons.battery_saver_outlined,
                          color: AppColors.green,
                          title: strings.permBatteryTitle,
                          description: strings.permBatteryDesc,
                          isGranted: _permissions['batteryOptimization'] == true,
                          actionLabel: strings.permBatteryAction,
                          onAction: () async {
                            await MethodChannelService.requestBatteryOptimization();
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildPermissionTile(
                          icon: Icons.notifications_none_outlined,
                          color: AppColors.primaryLight,
                          title: strings.permNotifTitle,
                          description: strings.permNotifDesc,
                          isGranted: _permissions['notification'] == true,
                          actionLabel: strings.permNotifAction,
                          onAction: () async {
                            await MethodChannelService.requestNotificationPermission();
                          },
                        ),
                        const SizedBox(height: 10),
                        _buildPermissionTile(
                          icon: Icons.vpn_key_outlined,
                          color: AppColors.accent,
                          title: strings.permVpnTitle,
                          description: strings.permVpnDesc,
                          isGranted: _permissions['vpn'] == true,
                          actionLabel: strings.permVpnAction,
                          onAction: null,
                        ),
                        if (_permissions['usageStats'] != true) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.help_outline_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        strings.permRestrictedHelpTitle,
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  strings.permRestrictedHelpBody,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () => MethodChannelService.openAppSettings(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        strings.permOpenAppInfo,
                                        style: TextStyle(
                                          color: AppColors.accent,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_forward, color: AppColors.accent, size: 14),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceCardDark,
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
                      label: Text(
                        strings.permRefreshStatus,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      onPressed: _checkPermissions,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        strings.permDone,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool isGranted,
    required String actionLabel,
    VoidCallback? onAction,
  }) {
    final vpn = Provider.of<VpnManager>(context, listen: false);
    final strings = AppStrings(vpn.isArabic);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted ? AppColors.borderDark : color.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isGranted ? AppColors.surfaceHover : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: isGranted ? AppColors.textSecondary : color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted
                      ? AppColors.green.withValues(alpha: 0.15)
                      : AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: isGranted ? AppColors.green : AppColors.amber,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGranted ? strings.permGranted : strings.permRequired,
                      style: TextStyle(
                        color: isGranted ? AppColors.green : AppColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (!isGranted && onAction != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  actionLabel,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
