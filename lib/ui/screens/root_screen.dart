import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/themes/app_colors.dart';
import '../../core/services/method_channel_service.dart';
import '../../core/localization/app_strings.dart';
import '../widgets/bottom_dock.dart';
import '../tabs/dashboard_tab.dart';
import '../tabs/history_tab.dart';
import '../tabs/firewall_tab.dart';
import '../tabs/dns_tab.dart';
import '../tabs/usage_tab.dart';
import 'settings_screen.dart';
import 'permissions_modal.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({Key? key}) : super(key: key);

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  int _activeTab = 0;

  final List<Widget> _tabs = [
    const DashboardTab(),
    const DnsTab(),
    const FirewallTab(),
    const UsageTab(),
    const HistoryTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final manager = Provider.of<VpnManager>(context, listen: false);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      manager.pauseTrafficTicker();
    } else if (state == AppLifecycleState.resumed) {
      manager.resumeTrafficTicker();
    }
  }

  Future<void> _checkInitialPermissions() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    try {
      final status = await MethodChannelService.checkPermissionsStatus();
      if (status['usageStats'] != true || status['batteryOptimization'] != true) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => const PermissionsModal(),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<VpnManager>(context);
    final strings = AppStrings(manager.isArabic);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        titleSpacing: 16,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceCardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Icon(
                Icons.flash_on_rounded,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Net Guard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Connection Status Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 13),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: manager.config.isVpnActive
                  ? AppColors.accent.withOpacity(0.15)
                  : AppColors.surfaceHover,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: manager.config.isVpnActive
                    ? AppColors.accent.withOpacity(0.3)
                    : AppColors.borderDark,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: manager.config.isVpnActive ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  manager.config.isVpnActive
                      ? (manager.isArabic ? 'محمي 🟢' : 'Protected')
                      : (manager.isArabic ? 'متوقف ⚪' : 'Off'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: manager.config.isVpnActive ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Settings Screen Button
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textPrimary,
              size: 22,
            ),
            tooltip: strings.settingsTitle,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _activeTab,
        children: _tabs,
      ),
      bottomNavigationBar: isKeyboardOpen
          ? null
          : Container(
              color: AppColors.bgDark,
              child: SafeArea(
                top: false,
                child: BottomDockWidget(
                  activeTab: _activeTab,
                  onTabSelected: (index) => setState(() => _activeTab = index),
                ),
              ),
            ),
    );
  }
}
