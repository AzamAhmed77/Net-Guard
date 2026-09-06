import 'dart:convert';
import 'dart:typed_data';

class AppInfo {
  final String name;
  final String packageName;
  final bool isSystem;
  final String? iconBase64;
  final Uint8List? iconBytes;
  final int uid;
  double totalMb;
  bool isWifiAllowed;
  bool isMobileAllowed;
  bool isExemptFromBlacklist;

  // 3 Speed Modes:
  // 'default' = يتبع إعدادات السرعة العامة بالرئيسية (التلقائي)
  // 'unlimited' = سرعة مفتوحة كاملة بدون أي تقييد (∞)
  // 'custom' = سرعة مخصصة محددة بالكيلوبايت (0 إلى أي رقم)
  String speedMode;
  int customSpeedLimitKbps;

  // Security & Firewall Features
  bool isQuarantined;
  bool hasTrackers;
  DateTime? tempAllowUntil;
  bool isSelected;

  AppInfo({
    required this.name,
    required this.packageName,
    this.isSystem = false,
    this.iconBase64,
    this.iconBytes,
    this.uid = 0,
    this.totalMb = 0.0,
    this.isWifiAllowed = true,
    this.isMobileAllowed = true,
    this.isExemptFromBlacklist = false,
    this.speedMode = 'default',
    this.customSpeedLimitKbps = 0,
    this.isQuarantined = false,
    this.hasTrackers = false,
    this.tempAllowUntil,
    this.isSelected = false,
  });

  bool get isTempAllowed =>
      tempAllowUntil != null && DateTime.now().isBefore(tempAllowUntil!);

  int get remainingTempMinutes {
    if (tempAllowUntil == null) return 0;
    final diff = tempAllowUntil!.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff : 0;
  }

  bool get isEffectivelyBlocked {
    if (isTempAllowed) return false;
    if (!isWifiAllowed && !isMobileAllowed) return true;
    if (speedMode == 'custom' && customSpeedLimitKbps == 0) return true;
    return false;
  }

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    final pkg = json['packageName'] ?? '';
    final name = json['appName'] ?? json['name'] ?? '';
    final rawIcon = json['appIcon'] ?? json['iconBase64'];
    Uint8List? cachedBytes;
    if (rawIcon != null && rawIcon is String && rawIcon.isNotEmpty) {
      try {
        cachedBytes = base64Decode(rawIcon);
      } catch (_) {}
    }

    final isTrackerSuspicious = pkg.contains('ad') ||
        pkg.contains('tracker') ||
        pkg.contains('analytics') ||
        pkg.contains('facebook') ||
        pkg.contains('tiktok') ||
        pkg.contains('snapchat') ||
        pkg.contains('game');

    return AppInfo(
      name: name,
      packageName: pkg,
      isSystem: json['isSystem'] ?? false,
      iconBase64: rawIcon,
      iconBytes: cachedBytes,
      uid: json['uid'] ?? 0,
      totalMb: (json['totalMb'] ?? 0.0).toDouble(),
      hasTrackers: isTrackerSuspicious,
      speedMode: json['speedMode'] ?? 'default',
      customSpeedLimitKbps: json['customSpeedLimitKbps'] ?? 0,
    );
  }
}
