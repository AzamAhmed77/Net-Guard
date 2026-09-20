import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/models/app_info.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';

class FirewallTab extends StatefulWidget {
  const FirewallTab({super.key});

  @override
  State<FirewallTab> createState() => _FirewallTabState();
}

class _FirewallTabState extends State<FirewallTab> {
  String _searchQuery = '';
  String _activeFilter = 'all'; // all, blocked, allowed, custom
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatMb(double mb) {
    if (mb <= 0.05) return '\u200E0.0 MB';
    if (mb >= 1024) {
      return '\u200E${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '\u200E${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context);
    final strings = AppStrings(vpn.isArabic);
    final allApps = vpn.apps;
    final double totalAppsUsage = vpn.todayUsageMb;
    final double maxAppUsage = allApps.isEmpty
        ? 1.0
        : allApps.map((a) => a.totalMb).reduce((a, b) => a > b ? a : b);

    final filteredApps = allApps.where((app) {
      final matchesSearch = _searchQuery.isEmpty ||
          app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final isBlocked = vpn.isBlockAllMode
          ? (!app.isWifiAllowed && !app.isMobileAllowed && !app.isTempAllowed)
          : app.isEffectivelyBlocked;

      switch (_activeFilter) {
        case 'blocked':
          return isBlocked;
        case 'allowed':
          return !isBlocked;
        case 'custom':
          return !app.isWifiAllowed ||
              !app.isMobileAllowed ||
              app.speedMode != 'default' ||
              app.customSpeedLimitKbps > 0;
        case 'all':
        default:
          return true;
      }
    }).toList();

    if (_activeFilter == 'custom') {
      filteredApps.sort((a, b) {
        final aC = (!a.isWifiAllowed || !a.isMobileAllowed || a.speedMode != 'default') ? 1 : 0;
        final bC = (!b.isWifiAllowed || !b.isMobileAllowed || b.speedMode != 'default') ? 1 : 0;
        return bC.compareTo(aC);
      });
    }

    return Column(
      children: [
        // ==========================================
        // TOP CONTROL HEADER
        // ==========================================
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              // Info & Filter status row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        strings.totalToday,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _formatMb(totalAppsUsage),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${filteredApps.length} ${strings.activeAppsCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar + Batch Toggle
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: strings.searchApps,
                          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => vpn.toggleBatchMode(),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: vpn.isBatchMode ? AppColors.accent : AppColors.surfaceCardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: vpn.isBatchMode ? AppColors.accent : AppColors.borderDark,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            vpn.isBatchMode ? Icons.check_box : Icons.checklist,
                            size: 18,
                            color: vpn.isBatchMode ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            strings.batchMode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: vpn.isBatchMode ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filter Chips
              Row(
                children: [
                  _buildFilterChip(strings.filterAll, 'all', vpn, strings),
                  const SizedBox(width: 8),
                  _buildFilterChip(strings.filterBlocked, 'blocked', vpn, strings),
                  const SizedBox(width: 8),
                  _buildFilterChip(strings.filterAllowed, 'allowed', vpn, strings),
                  const SizedBox(width: 8),
                  _buildFilterChip(strings.filterCustom, 'custom', vpn, strings),
                ],
              ),

              // Batch actions row if batch mode active
              if (vpn.isBatchMode) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${vpn.selectedAppsCount} ${vpn.isArabic ? 'محدد' : 'selected'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildBatchActionButton(
                                label: strings.selectAll,
                                onTap: () => vpn.batchToggleSelectAll(true),
                              ),
                              const SizedBox(width: 6),
                              _buildBatchActionButton(
                                label: strings.allowSelected,
                                color: AppColors.accent,
                                onTap: () => vpn.batchSetAccess(allow: true),
                              ),
                              const SizedBox(width: 6),
                              _buildBatchActionButton(
                                label: strings.blockSelected,
                                color: AppColors.red,
                                onTap: () => vpn.batchSetAccess(allow: false),
                              ),
                              const SizedBox(width: 6),
                              _buildBatchActionButton(
                                label: strings.presetDefault,
                                onTap: () => vpn.batchSetSpeedMode('default'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ==========================================
        // APPS LIST
        // ==========================================
        Expanded(
          child: vpn.isLoadingApps
              ? Center(child: CircularProgressIndicator(color: AppColors.accent))
              : filteredApps.isEmpty
                  ? Center(
                      child: Text(
                        strings.noAppsUsageFound,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 16),
                      itemCount: filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = filteredApps[index];
                        return _buildAppCard(context, vpn, app, maxAppUsage, strings);
                      },
                    ),
        ),
      ],
    );
  }

  void _showProfileSaveSnackBar(BuildContext context, String message, VpnManager vpn, AppStrings strings) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        action: SnackBarAction(
          label: strings.isAr ? '💾 حفظ كملف' : '💾 Save Profile',
          textColor: AppColors.accent,
          onPressed: () async {
            await vpn.saveCustomProfileSettings();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.isAr
                              ? 'تم حفظ التخصيص في ملفك المخصص بنجاح'
                              : 'Saved to custom profile successfully',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.accent,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showCustomProfileBottomSheet(BuildContext context, VpnManager vpn, AppStrings strings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AppColors.borderDark, width: 1),
              left: BorderSide(color: AppColors.borderDark, width: 1),
              right: BorderSide(color: AppColors.borderDark, width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.app_settings_alt_rounded, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.isAr ? 'إدارة الملف المخصص' : 'Custom Profile Management',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vpn.customizedAppsCount} ${strings.isAr ? "تطبيق مخصص بقواعد خاصة" : "apps with custom rules"}',
                          style: TextStyle(fontSize: 12, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                strings.isAr
                    ? 'يمكنك حفظ إعدادات وسرعات التطبيقات المخصصة الحالية كملف دائم، أو استعادة ملفك المحفوظ مسبقاً بضغطة واحدة.'
                    : 'Save current custom app speeds & firewall rules as your permanent profile, or restore previously saved settings.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Action 1: Save Profile
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await vpn.saveCustomProfileSettings();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.isAr
                                    ? 'تم حفظ التخصيص الحالي كملف مخصص بنجاح'
                                    : 'Current setup saved to custom profile successfully',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.accent,
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.save_rounded, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isAr ? 'حفظ التخصيص الحالي كملف دائم' : 'Save Current Setup Permanently',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              strings.isAr ? 'اعتماد قواعد وسرعات التطبيقات الحالية' : 'Persist current app limits permanently',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action 2: Restore Profile
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  await vpn.restoreAndApplyCustomProfile();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.replay_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.isAr
                                    ? 'تم استعادة وتطبيق ملفك المخصص بنجاح'
                                    : 'Custom profile restored and applied',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF8B5CF6),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.restore_rounded, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.isAr ? 'استعادة الملف المحفوظ' : 'Restore Saved Profile',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              strings.isAr ? 'الرجوع للقواعد والسرعات المحفوظة سابقاً' : 'Revert to previously saved rules',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String key, VpnManager vpn, AppStrings strings) {
    final isSelected = _activeFilter == key;
    final displayLabel = (key == 'custom' && vpn.customizedAppsCount > 0)
        ? '$label \u202A(${vpn.customizedAppsCount})\u202C'
        : label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (key == 'custom' && isSelected) {
          _showCustomProfileBottomSheet(context, vpn, strings);
        } else {
          setState(() => _activeFilter = key);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceCardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderDark,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (key == 'custom') ...[
              const SizedBox(width: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showCustomProfileBottomSheet(context, vpn, strings),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.surfaceHover,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 14,
                    color: isSelected ? Colors.white : AppColors.accent,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatchActionButton({
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color != null ? color.withValues(alpha: 0.15) : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color ?? AppColors.borderDark),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard(
    BuildContext context,
    VpnManager vpn,
    AppInfo app,
    double maxAppUsage,
    AppStrings strings,
  ) {
    final isBlocked = vpn.isBlockAllMode
        ? (!app.isWifiAllowed && !app.isMobileAllowed && !app.isTempAllowed)
        : app.isEffectivelyBlocked;
    final usageRatio = (app.totalMb / (maxAppUsage > 0 ? maxAppUsage : 1.0)).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: app.isSelected
              ? AppColors.accent
              : (isBlocked ? AppColors.red.withValues(alpha: 0.3) : AppColors.borderDark),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Checkbox if batch mode
              if (vpn.isBatchMode) ...[
                Checkbox(
                  value: app.isSelected,
                  activeColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() => app.isSelected = val ?? false);
                    vpn.refresh();
                  },
                ),
                const SizedBox(width: 4),
              ],

              // App Icon & Name (Tappable to open speed & pass settings)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAppSpeedDialog(context, vpn, app, strings),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHover,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: app.iconBytes != null
                              ? Image.memory(
                                  app.iconBytes!,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.android, color: AppColors.textSecondary, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.packageName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Controls: Wi-Fi, Mobile, Speed Mode
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wi-Fi Button
                  _buildNetworkToggleButton(
                    icon: Icons.wifi,
                    isActive: app.isWifiAllowed,
                    onTap: () {
                      vpn.toggleAppWifi(app);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),

                  // Mobile Data Button
                  _buildNetworkToggleButton(
                    icon: Icons.network_cell,
                    isActive: app.isMobileAllowed,
                    onTap: () {
                      vpn.toggleAppMobile(app);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),

                  // Speed Mode Menu
                  _buildSpeedModeBadge(context, vpn, app, strings),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Proportional Usage Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: usageRatio,
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceHover,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isBlocked ? AppColors.textSecondary : AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatMb(app.totalMb),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // Temporary Pass notice if active
          if (app.isTempAllowed) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 12, color: Color(0xFF00E5FF)),
                const SizedBox(width: 4),
                Text(
                  '${strings.tempPass}: ${strings.minRemaining(app.remainingTempMinutes)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF00E5FF)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => vpn.revokeTemporaryPass(app),
                  child: Text(
                    strings.revoke,
                    style: const TextStyle(fontSize: 10, color: AppColors.red),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.accent.withValues(alpha: 0.4) : AppColors.borderDark,
          ),
        ),
        child: Icon(
          icon,
          size: 17,
          color: isActive ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSpeedModeBadge(
    BuildContext context,
    VpnManager vpn,
    AppInfo app,
    AppStrings strings,
  ) {
    String badgeText = strings.presetDefault;
    Color badgeColor = AppColors.textSecondary;

    if (app.speedMode == 'unlimited') {
      badgeText = '∞';
      badgeColor = AppColors.accent;
    } else if (app.speedMode == 'custom') {
      badgeText = app.customSpeedLimitKbps == 0 ? (strings.isAr ? 'كتم 0' : '0K') : '${app.customSpeedLimitKbps}K';
      badgeColor = const Color(0xFFF59E0B);
    } else {
      if (vpn.config.downloadSpeedLimit > 0) {
        badgeText = '${vpn.config.downloadSpeedLimit}K';
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showAppSpeedDialog(context, vpn, app, strings),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              badgeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showAppSpeedDialog(
    BuildContext context,
    VpnManager vpn,
    AppInfo app,
    AppStrings strings,
  ) {
    int customKbps = app.customSpeedLimitKbps;
    String selectedMode = app.speedMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHover,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: app.iconBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(app.iconBytes!),
                              )
                            : const Icon(Icons.android, size: 20, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              app.packageName,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Clarification Banner ──
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            strings.isAr
                                ? 'الوضع العادي يتبع السرعة العامة للداشبورد. لتقييد سرعة هذا التطبيق بشكل منفصل، اختر «مخصص» وحدد السرعة ثم احفظ.'
                                : 'Default mode follows the main dashboard limit. To restrict this app individually, choose "Custom", set the speed, and save.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Speed Mode: Default ──
                  _buildSpeedModeOption(
                    icon: Icons.settings_backup_restore,
                    iconColor: AppColors.textSecondary,
                    title: strings.presetDefault,
                    subtitle: vpn.config.downloadSpeedLimit > 0
                        ? (strings.isAr
                            ? 'يتبع السرعة العامة الرئيسية (${vpn.config.downloadSpeedLimit} KB/s)'
                            : 'Follows master limit (${vpn.config.downloadSpeedLimit} KB/s)')
                        : (strings.isAr
                            ? 'يتبع السرعة العامة للداشبورد (غير مقيد حالياً - بدون سقف)'
                            : 'Follows master limit (Currently unrestricted)'),
                    isSelected: selectedMode == 'default',
                    onTap: () {
                      vpn.setAppSpeedMode(app, 'default');
                      Navigator.pop(ctx);
                      final isGloballyLimited = vpn.config.downloadSpeedLimit > 0;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            strings.isAr
                                ? (isGloballyLimited
                                    ? 'تم ضبط ${app.name} على الوضع العادي (مقيد بالسرعة العامة: ${vpn.config.downloadSpeedLimit} KB/s)'
                                    : 'تم ضبط ${app.name} على الوضع العادي (السرعة العامة غير مقيدة)')
                                : '${app.name} set to Default speed mode',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppColors.surfaceCardDark,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── Speed Mode: Unlimited ──
                  _buildSpeedModeOption(
                    icon: Icons.all_inclusive,
                    iconColor: AppColors.accent,
                    title: strings.presetUnlimited,
                    subtitle: strings.isAr ? 'سرعة قصوى غير مقيدة أبداً' : 'No speed limit applied',
                    isSelected: selectedMode == 'unlimited',
                    onTap: () {
                      vpn.setAppSpeedMode(app, 'unlimited');
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            strings.isAr
                                ? 'تم ضبط ${app.name} على سرعة مفتوحة غير مقيدة (∞)'
                                : '${app.name} set to Unlimited speed mode',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppColors.surfaceCardDark,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── Speed Mode: Custom ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selectedMode == 'custom'
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                          : AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selectedMode == 'custom'
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                            : AppColors.borderDark,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed, color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(width: 10),
                            Text(
                              strings.profileCustom,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: customKbps == 0
                                    ? AppColors.red.withValues(alpha: 0.15)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: customKbps == 0
                                      ? AppColors.red.withValues(alpha: 0.4)
                                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                customKbps == 0
                                    ? (strings.isAr ? 'كتم كامل' : 'Muted')
                                    : '\u200E$customKbps KB/s',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: customKbps == 0 ? AppColors.red : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Quick Presets
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final preset in [
                                {'label': strings.isAr ? 'كتم 0' : '0 Mute', 'val': 0},
                                {'label': '64K', 'val': 64},
                                {'label': '128K', 'val': 128},
                                {'label': '256K', 'val': 256},
                                {'label': '512K', 'val': 512},
                                {'label': '1024K', 'val': 1024},
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        customKbps = preset['val'] as int;
                                        selectedMode = 'custom';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (selectedMode == 'custom' && customKbps == preset['val'])
                                            ? const Color(0xFFF59E0B)
                                            : AppColors.surfaceCardDark,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (selectedMode == 'custom' && customKbps == preset['val'])
                                              ? const Color(0xFFF59E0B)
                                              : AppColors.borderDark,
                                        ),
                                      ),
                                      child: Text(
                                        preset['label'] as String,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: (selectedMode == 'custom' && customKbps == preset['val'])
                                              ? Colors.black
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SliderTheme(
                          data: SliderTheme.of(ctx).copyWith(
                            activeTrackColor: customKbps == 0 ? AppColors.red : const Color(0xFFF59E0B),
                            inactiveTrackColor: AppColors.surfaceCardDark,
                            thumbColor: customKbps == 0 ? AppColors.red : const Color(0xFFF59E0B),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: customKbps.toDouble().clamp(0.0, 4096.0),
                            min: 0,
                            max: 4096,
                            divisions: 128,
                            onChanged: (val) {
                              setSheetState(() {
                                customKbps = val.toInt();
                                selectedMode = 'custom';
                              });
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              strings.isAr ? '0 (كتم)' : '0 (Mute)',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                            const Text(
                              '\u200E4096 KB/s',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              vpn.setAppSpeedMode(app, 'custom', customSpeedKbps: customKbps);
                              Navigator.pop(ctx);
                              final speedText = customKbps == 0
                                  ? (strings.isAr ? 'كتم كامل 0 KB/s' : '0 KB/s (Muted)')
                                  : '\u200E$customKbps KB/s';
                              _showProfileSaveSnackBar(
                                context,
                                strings.isAr
                                    ? 'تم ضبط سرعة ${app.name} على $speedText'
                                    : '${app.name} speed set to $speedText',
                                vpn,
                                strings,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              strings.save,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.borderDark, height: 1),
                  const SizedBox(height: 14),

                  // Temporary Pass Section
                  Text(
                    strings.tempPassDuration,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            vpn.grantTemporaryPass(app, const Duration(minutes: 15));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.isAr
                                      ? 'تم منح تصريح مؤقت لـ ${app.name} لمدة 15 دقيقة'
                                      : 'Granted 15 min temporary pass for ${app.name}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: AppColors.surfaceCardDark,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(strings.minutes15, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            vpn.grantTemporaryPass(app, const Duration(minutes: 30));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.isAr
                                      ? 'تم منح تصريح مؤقت لـ ${app.name} لمدة 30 دقيقة'
                                      : 'Granted 30 min temporary pass for ${app.name}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: AppColors.surfaceCardDark,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(strings.minutes30, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            vpn.grantTemporaryPass(app, const Duration(hours: 1));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.isAr
                                      ? 'تم منح تصريح مؤقت لـ ${app.name} لمدة ساعة واحدة'
                                      : 'Granted 1 hour temporary pass for ${app.name}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: AppColors.surfaceCardDark,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.borderDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(strings.hour1, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSpeedModeOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surfaceHover,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.5) : AppColors.borderDark,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }

}
