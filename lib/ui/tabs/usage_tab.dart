import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/models/app_info.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/method_channel_service.dart';

class UsageTab extends StatefulWidget {
  const UsageTab({Key? key}) : super(key: key);

  @override
  State<UsageTab> createState() => _UsageTabState();
}

class _UsageTabState extends State<UsageTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Active filters
  String _session = 'today'; // 'today', 'yesterday', 'this_week', 'last_7_days', 'this_month', 'last_month', 'this_year', 'all_time', 'custom'
  DateTimeRange? _customDateRange;
  String _networkFilter = 'all'; // 'all', 'wifi', 'mobile'

  // Per-app traffic data split by network type
  Map<String, double> _wifiTraffic = {};
  Map<String, double> _mobileTraffic = {};
  double _totalWifiMb = 0.0;
  double _totalMobileMb = 0.0;
  bool _isLoadingTraffic = false;

  @override
  void initState() {
    super.initState();
    _loadPerAppTrafficByNetwork();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPerAppTrafficByNetwork() async {
    setState(() => _isLoadingTraffic = true);
    try {
      final data = await MethodChannelService.getPerAppTrafficByNetwork(
        session: _session,
        startTime: _customDateRange?.start.millisecondsSinceEpoch,
        endTime: _customDateRange?.end.millisecondsSinceEpoch,
      );
      if (mounted) {
        setState(() {
          _wifiTraffic = Map<String, double>.from(
            (data['wifi'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
          );
          _mobileTraffic = Map<String, double>.from(
            (data['mobile'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ?? {},
          );
          _totalWifiMb = (data['totalWifiMb'] as num?)?.toDouble() ?? 0.0;
          _totalMobileMb = (data['totalMobileMb'] as num?)?.toDouble() ?? 0.0;
          _isLoadingTraffic = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTraffic = false);
    }
  }

  double _getAppUsage(AppInfo app) {
    switch (_networkFilter) {
      case 'wifi':
        return _wifiTraffic[app.packageName] ?? 0.0;
      case 'mobile':
        return _mobileTraffic[app.packageName] ?? 0.0;
      default:
        return (_wifiTraffic[app.packageName] ?? 0.0) + (_mobileTraffic[app.packageName] ?? 0.0);
    }
  }

  double _getTotalUsage(List<AppInfo> apps) {
    if (_networkFilter == 'wifi') {
      if (_totalWifiMb > 0) return _totalWifiMb;
      return _wifiTraffic.values.fold(0.0, (s, v) => s + v);
    } else if (_networkFilter == 'mobile') {
      if (_totalMobileMb > 0) return _totalMobileMb;
      return _mobileTraffic.values.fold(0.0, (s, v) => s + v);
    } else {
      final sumNative = _totalWifiMb + _totalMobileMb;
      if (sumNative > 0) return sumNative;
      double total = 0.0;
      for (var app in apps) {
        total += _getAppUsage(app);
      }
      return total;
    }
  }

  String _formatMb(double mb) {
    if (mb <= 0.05) return '\u200E0.0 MB';
    if (mb >= 1024) {
      return '\u200E${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '\u200E${mb.toStringAsFixed(2)} MB';
  }

  String _getSessionLabel(AppStrings strings) {
    switch (_session) {
      case 'today':
        return strings.today;
      case 'yesterday':
        return strings.yesterday;
      case 'this_week':
        return strings.thisWeek;
      case 'last_7_days':
        return strings.last7Days;
      case 'this_month':
        return strings.thisMonth;
      case 'last_month':
        return strings.lastMonth;
      case 'this_year':
        return strings.thisYear;
      case 'all_time':
        return strings.allTime;
      case 'custom':
        if (_customDateRange != null) {
          final s = _customDateRange!.start;
          final e = _customDateRange!.end;
          return '${s.month}/${s.day} - ${e.month}/${e.day}';
        }
        return strings.customPeriod;
      default:
        return strings.today;
    }
  }

  String _getNetworkLabel(AppStrings strings) {
    switch (_networkFilter) {
      case 'wifi':
        return strings.wifiOnly;
      case 'mobile':
        return strings.mobileOnly;
      default:
        return strings.allNetworks;
    }
  }

  // =========================================================================
  // FILTER MODAL BOTTOM SHEET (Matching Image 2 Reference)
  // =========================================================================
  void _showFilterBottomSheet(BuildContext context, AppStrings strings) {
    String tempSession = _session;
    String tempNetwork = _networkFilter;
    DateTimeRange? tempCustomRange = _customDateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141517),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top header: Back arrow + Filter title
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          strings.filterTitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Section title: Filters + Reset
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.filters,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempSession = 'today';
                              tempNetwork = 'all';
                              tempCustomRange = null;
                            });
                          },
                          child: Text(
                            strings.reset,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Subheading: Select session
                    Text(
                      strings.selectSession,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Session Buttons Grid (4 rows x 2 columns)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSessionButton(
                            label: strings.today,
                            isSelected: tempSession == 'today',
                            onTap: () => setModalState(() => tempSession = 'today'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSessionButton(
                            label: strings.yesterday,
                            isSelected: tempSession == 'yesterday',
                            onTap: () => setModalState(() => tempSession = 'yesterday'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSessionButton(
                            label: strings.thisWeek,
                            isSelected: tempSession == 'this_week',
                            onTap: () => setModalState(() => tempSession = 'this_week'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSessionButton(
                            label: strings.last7Days,
                            isSelected: tempSession == 'last_7_days',
                            onTap: () => setModalState(() => tempSession = 'last_7_days'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSessionButton(
                            label: strings.thisMonth,
                            isSelected: tempSession == 'this_month',
                            onTap: () => setModalState(() => tempSession = 'this_month'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSessionButton(
                            label: strings.lastMonth,
                            isSelected: tempSession == 'last_month',
                            onTap: () => setModalState(() => tempSession = 'last_month'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSessionButton(
                            label: strings.thisYear,
                            isSelected: tempSession == 'this_year',
                            onTap: () => setModalState(() => tempSession = 'this_year'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSessionButton(
                            label: strings.allTime,
                            isSelected: tempSession == 'all_time',
                            onTap: () => setModalState(() => tempSession = 'all_time'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Add Custom Button (Full width)
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: tempCustomRange ??
                              DateTimeRange(
                                start: DateTime.now().subtract(const Duration(days: 7)),
                                end: DateTime.now(),
                              ),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: AppColors.accent,
                                  onPrimary: Colors.white,
                                  surface: AppColors.surfaceCardDark,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setModalState(() {
                            tempCustomRange = picked;
                            tempSession = 'custom';
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: tempSession == 'custom' ? Colors.white : const Color(0xFF26282D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: tempSession == 'custom' ? Colors.white : Colors.transparent,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tempCustomRange != null && tempSession == 'custom'
                              ? '${tempCustomRange!.start.year}/${tempCustomRange!.start.month}/${tempCustomRange!.start.day} - ${tempCustomRange!.end.year}/${tempCustomRange!.end.month}/${tempCustomRange!.end.day}'
                              : strings.addCustom,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: tempSession == 'custom' ? Colors.black : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Subheading: Network Type
                    Text(
                      strings.networkType,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Network Type Buttons (Mobile data vs Wi-Fi)
                    Row(
                      children: [
                        Expanded(
                          child: _buildNetworkButton(
                            label: strings.mobileData,
                            icon: Icons.signal_cellular_alt_rounded,
                            isSelected: tempNetwork == 'mobile' || tempNetwork == 'all',
                            onTap: () {
                              setModalState(() {
                                if (tempNetwork == 'mobile') {
                                  tempNetwork = 'all';
                                } else if (tempNetwork == 'all') {
                                  tempNetwork = 'wifi';
                                } else {
                                  tempNetwork = 'mobile';
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNetworkButton(
                            label: strings.wiFi,
                            icon: Icons.wifi_rounded,
                            isSelected: tempNetwork == 'wifi' || tempNetwork == 'all',
                            onTap: () {
                              setModalState(() {
                                if (tempNetwork == 'wifi') {
                                  tempNetwork = 'all';
                                } else if (tempNetwork == 'all') {
                                  tempNetwork = 'mobile';
                                } else {
                                  tempNetwork = 'wifi';
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Apply Filters Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _session = tempSession;
                            _networkFilter = tempNetwork;
                            _customDateRange = tempCustomRange;
                          });
                          _loadPerAppTrafficByNetwork();
                        },
                        child: Text(
                          strings.applyFilters,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSessionButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF26282D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF26282D),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.black : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context);
    final strings = AppStrings(vpn.isArabic);
    final allApps = vpn.apps;

    // Build usage list sorted by usage
    final List<MapEntry<AppInfo, double>> usageList = allApps
        .map((app) => MapEntry(app, _getAppUsage(app)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Filter by search
    final filtered = _searchQuery.isEmpty
        ? usageList
        : usageList.where((entry) {
            return entry.key.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                entry.key.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

    final double totalUsage = _getTotalUsage(allApps);
    final double maxAppUsage = filtered.isEmpty ? 1.0 : filtered.first.value;
    final int activeCount = usageList.where((e) => e.value > 0.05).length;

    return Column(
      children: [
        // ==========================================
        // TOP HEADER: Session & Total + Filter Modal Button
        // ==========================================
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _getSessionLabel(strings),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                            ),
                            child: Text(
                              _formatMb(totalUsage),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$activeCount ${strings.activeAppsCount} • ${_getNetworkLabel(strings)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Filter Trigger Button (Opens Bottom Sheet matching Image 2)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showFilterBottomSheet(context, strings),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _session != 'today' || _networkFilter != 'all'
                              ? AppColors.accent
                              : AppColors.borderDark,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: _session != 'today' || _networkFilter != 'all'
                                ? AppColors.accent
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            strings.filterTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _session != 'today' || _networkFilter != 'all'
                                  ? AppColors.accent
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: strings.searchApps,
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceCardDark,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_isLoadingTraffic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),

        // ==========================================
        // APP USAGE LIST
        // ==========================================
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pie_chart_outline_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text(
                        strings.noAppsUsageFound,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surfaceCardDark,
                  onRefresh: _loadPerAppTrafficByNetwork,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length + 1, // +1 for bottom padding
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return const SizedBox(height: 90);
                      }

                      final entry = filtered[index];
                      final app = entry.key;
                      final usageMb = entry.value;
                      final ratio = maxAppUsage > 0.05 ? (usageMb / maxAppUsage).clamp(0.0, 1.0) : 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCardDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // App Icon
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceHover,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: app.iconBytes != null
                                        ? Image.memory(
                                            app.iconBytes!,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(Icons.android, color: AppColors.textSecondary, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // App Name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (_networkFilter == 'all') ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.wifi_rounded, size: 10, color: AppColors.textSecondary),
                                            const SizedBox(width: 3),
                                            Text(
                                              _formatMb(_wifiTraffic[app.packageName] ?? 0.0),
                                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.signal_cellular_alt_rounded, size: 10, color: AppColors.textSecondary),
                                            const SizedBox(width: 3),
                                            Text(
                                              _formatMb(_mobileTraffic[app.packageName] ?? 0.0),
                                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Usage value
                                Text(
                                  _formatMb(usageMb),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _networkFilter == 'wifi'
                                        ? const Color(0xFF06B6D4)
                                        : _networkFilter == 'mobile'
                                            ? const Color(0xFFF59E0B)
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Usage Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 4,
                                backgroundColor: AppColors.surfaceHover,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _networkFilter == 'wifi'
                                      ? const Color(0xFF06B6D4) // Cyan for WiFi
                                      : _networkFilter == 'mobile'
                                          ? const Color(0xFFF59E0B) // Amber for Mobile
                                          : AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
