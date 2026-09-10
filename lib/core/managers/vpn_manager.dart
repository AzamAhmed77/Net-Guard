import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/vpn_config.dart';
import '../models/app_info.dart';
import '../services/method_channel_service.dart';
import '../services/storage_service.dart';
import '../themes/app_colors.dart';

class VpnManager extends ChangeNotifier {
  VpnConfig config = VpnConfig();
  final bool isDarkMode = true; // Permanent Dark Mode
  Timer? _statsTimer;
  Timer? _tempPassTimer;
  bool _statsRequestInFlight = false;

  double _currentDownloadSpeed = 0.0;
  double _currentUploadSpeed = 0.0;
  double _totalDownloadMb = 0.0;
  double _totalUploadMb = 0.0;
  final int _activeConnections = 0;
  bool _isLoadingApps = false;
  bool _isVpnTransitioning = false;

  // Security & Firewall State
  bool autoQuarantineNewApps = false;
  bool lockdownOnScreenOff = false;
  String activeSecurityProfile = 'default';
  String activePreset = 'default';
  bool isBatchMode = false;
  int lastManualDownloadLimit = -1;
  int lastManualUploadLimit = -1;
  double _todayRealUsageMb = 0.0;
  double get todayUsageMb => _todayRealUsageMb > 0.0
      ? _todayRealUsageMb
      : _apps.fold(0.0, (sum, a) => sum + a.totalMb);

  // Hotspot Speed Controller State
  bool _isHotspotRunning = false;
  int _hotspotPort = 8282;
  String _hotspotIp = '192.168.43.1';
  int _hotspotDownloadLimitKbps = -1; // -1 = Unlimited
  int _hotspotUploadLimitKbps = -1;   // -1 = Unlimited
  int _hotspotActiveClients = 0;
  int _hotspotTotalRxBytes = 0;
  int _hotspotTotalTxBytes = 0;

  bool get isHotspotRunning => _isHotspotRunning;
  int get hotspotPort => _hotspotPort;
  String get hotspotIp => _hotspotIp;
  int get hotspotDownloadLimitKbps => _hotspotDownloadLimitKbps;
  int get hotspotUploadLimitKbps => _hotspotUploadLimitKbps;
  int get hotspotActiveClients => _hotspotActiveClients;
  int get hotspotTotalRxBytes => _hotspotTotalRxBytes;
  int get hotspotTotalTxBytes => _hotspotTotalTxBytes;

  // History & Logs
  final List<double> _downloadHistory = List.generate(30, (_) => 0.0);
  final List<double> _uploadHistory = List.generate(30, (_) => 0.0);
  final List<Map<String, String>> _terminalLogs = [];
  final List<AppInfo> _apps = [];

  // Getters
  double get currentDownloadSpeed => _currentDownloadSpeed;
  double get currentUploadSpeed => _currentUploadSpeed;
  double get totalDownloadMb => _totalDownloadMb;
  double get totalUploadMb => _totalUploadMb;
  int get activeConnections => _activeConnections;
  bool get isLoadingApps => _isLoadingApps;
  bool get isVpnTransitioning => _isVpnTransitioning;
  List<double> get downloadHistory => List.unmodifiable(_downloadHistory);
  List<double> get uploadHistory => List.unmodifiable(_uploadHistory);
  List<Map<String, String>> get terminalLogs =>
      List.unmodifiable(_terminalLogs);
  List<AppInfo> get apps => _apps;

  double get peakDownloadSpeed {
    if (_downloadHistory.isEmpty) return _currentDownloadSpeed;
    final maxVal = _downloadHistory.reduce((a, b) => a > b ? a : b);
    return maxVal > _currentDownloadSpeed ? maxVal : _currentDownloadSpeed;
  }

  double get avgDownloadSpeed {
    final nonZero = _downloadHistory.where((s) => s > 0).toList();
    if (nonZero.isEmpty) {
      return _currentDownloadSpeed > 0 ? _currentDownloadSpeed : 0.0;
    }
    return nonZero.reduce((a, b) => a + b) / nonZero.length;
  }

  void refresh() => notifyListeners();

  bool get isBlockAllMode => config.globalMode == 'blacklist';

  int get selectedAppsCount => _apps.where((a) => a.isSelected).length;

  int get blockedAppsCount {
    if (isBlockAllMode) {
      return _apps
          .where(
              (a) => !a.isWifiAllowed && !a.isMobileAllowed && !a.isTempAllowed)
          .length;
    }
    return _apps.where((a) => a.isEffectivelyBlocked).length;
  }

  int get allowedAppsCount {
    if (isBlockAllMode) {
      return _apps
          .where(
              (a) => (a.isWifiAllowed || a.isMobileAllowed) || a.isTempAllowed)
          .length;
    }
    return _apps.where((a) => !a.isEffectivelyBlocked).length;
  }

  int get tempPassAppsCount => _apps.where((a) => a.isTempAllowed).length;

  int get trackerFlaggedCount => _apps.where((a) => a.hasTrackers).length;

  int get securityScore {
    int score = 45;
    if (config.isVpnActive) score += 20;
    if (config.blockAds) score += 10;
    if (config.blockAdult) score += 5;
    if (isBlockAllMode) score += 10;
    if (autoQuarantineNewApps) score += 5;
    if (lockdownOnScreenOff) score += 5;
    return score.clamp(0, 100);
  }

  String get securityLevelText {
    final score = securityScore;
    if (_currentLocale.languageCode == 'en') {
      if (score >= 90) return 'Iron Shield (Excellent)';
      if (score >= 70) return 'Advanced Protection (Very Good)';
      if (score >= 50) return 'Moderate Protection (Medium)';
      return 'Low Protection (Needs Upgrade)';
    } else {
      if (score >= 90) return 'درع حديدي (ممتاز)';
      if (score >= 70) return 'حماية متقدمة (جيد جداً)';
      if (score >= 50) return 'حماية معتدلة (متوسط)';
      return 'حماية منخفضة (بحاجة لترقية)';
    }
  }

  VpnManager() {
    _initStorageAndApps();
    _startRealTrafficTicker();
    _startTempPassWatchdog();
  }

  Future<void> _initStorageAndApps() async {
    try {
      final savedLang = await StorageService.loadLanguage();
      _currentLocale = Locale(savedLang);
      await MethodChannelService.setAppLanguage(savedLang);
    } catch (_) {}

    final savedConfig = await StorageService.loadConfig();
    if (savedConfig != null) {
      config = savedConfig;
      if (config.presetMode == 'default' ||
          config.presetMode == 'eco' ||
          config.presetMode == 'unlimited') {
        activePreset = config.presetMode;
      }
      addLog(
          "OK",
          isArabic
              ? "تم استرجاع الإعدادات المحفوظة بنجاح."
              : "Saved settings restored successfully.");
    }
    _isMonitorRunning = await StorageService.loadMonitorEnabled();
    _isSpikeAlertEnabled = await StorageService.loadSpikeAlertEnabled();
    lockdownOnScreenOff = await StorageService.loadLockdownScreenOff();
    autoQuarantineNewApps = await StorageService.loadAutoQuarantine();
    MethodChannelService.setAutoQuarantine(autoQuarantineNewApps);

    final savedManual = await StorageService.loadManualLimits();
    lastManualDownloadLimit = savedManual['dl'] ?? config.downloadSpeedLimit;
    lastManualUploadLimit = savedManual['ul'] ?? config.uploadSpeedLimit;
    if (activePreset == 'default') {
      config.downloadSpeedLimit = lastManualDownloadLimit;
      config.uploadSpeedLimit = lastManualUploadLimit;
    }

    final savedHotspot = await StorageService.loadHotspotSettings();
    _hotspotPort = savedHotspot['port'] ?? 8282;
    _hotspotDownloadLimitKbps = savedHotspot['dlLimit'] ?? -1;
    _hotspotUploadLimitKbps = savedHotspot['ulLimit'] ?? -1;
    await refreshHotspotStatus();

    await fetchInstalledApps();
    syncNativeSettings();

    try {
      final nativeEvents = await MethodChannelService.getNativeEventLogs();
      for (final event in nativeEvents) {
        if (event is Map) {
          addLog(
            event['level']?.toString() ?? 'INFO',
            event['message']?.toString() ?? '',
          );
        }
      }
    } catch (_) {}

    try {
      final savedAccent = await StorageService.loadAccentColor();
      if (savedAccent != null) {
        _accentColorValue = savedAccent;
        AppColors.accent = Color(savedAccent);
      }
    } catch (_) {}

    MethodChannelService.initializeChannelCallbacks();
    MethodChannelService.onVpnStateChanged = (bool isRunning) {
      config.isVpnActive = isRunning;
      _persistState();
      notifyListeners();
    };
    MethodChannelService.onVpnToggledFromNotification = () async {
      final isRunning = await MethodChannelService.isVpnRunning();
      config.isVpnActive = isRunning;
      _persistState();
      notifyListeners();
    };
    try {
      _isMonitorRunning = await MethodChannelService.isMonitorRunning();
      _isSpikeAlertEnabled = await MethodChannelService.isSpikeAlertEnabled();
    } catch (_) {}
    notifyListeners();
  }

  Locale _currentLocale = const Locale('ar');
  Locale get currentLocale => _currentLocale;
  bool get isArabic => _currentLocale.languageCode == 'ar';

  int _accentColorValue = 0xFF10B981;
  int get accentColorValue => _accentColorValue;

  Future<void> setAccentColor(Color color) async {
    _accentColorValue = color.toARGB32();
    AppColors.accent = color;
    await StorageService.saveAccentColor(color.toARGB32());
    notifyListeners();
  }

  void setPreset(String preset) {
    activePreset = preset;
    activeSecurityProfile = preset;
    config.presetMode = preset;
    switch (preset) {
      case 'eco':
        config.downloadSpeedLimit = 256;
        config.uploadSpeedLimit = 128;
        addLog(
            "OK",
            isArabic
                ? "🔋 تم تفعيل [وضع التوفير] — السرعة: 256K تنزيل / 128K رفع."
                : "🔋 [Eco Mode] active: Speed set to 256K down / 128K up.");
        break;
      case 'unlimited':
        config.downloadSpeedLimit = -1;
        config.uploadSpeedLimit = -1;
        for (var app in _apps) {
          if (app.speedMode != 'custom') {
            app.speedMode = 'default';
          }
          app.isWifiAllowed = true;
          app.isMobileAllowed = true;
        }
        addLog(
            "OK",
            isArabic
                ? "🚀 تم تفعيل [الوضع المفتوح] — بدون أي قيود على السرعة."
                : "🚀 [Unlimited Mode] active: No bandwidth limits.");
        break;
      case 'default':
      default:
        activePreset = 'default';
        // يحتفظ الوضع العادي بآخر سرعة حددها المستخدم يدوياً (سواء بتحريك الأشرطة أو الكتابة)
        config.downloadSpeedLimit = lastManualDownloadLimit;
        config.uploadSpeedLimit = lastManualUploadLimit;
        for (var app in _apps) {
          if (app.speedMode != 'custom') {
            app.speedMode = 'default';
          }
          app.isWifiAllowed = true;
          app.isMobileAllowed = true;
        }
        addLog(
            "OK",
            isArabic
                ? "⚡ تم تفعيل [الوضع العادي] — تطبيق آخر سرعة قمت بضبطها يدوياً."
                : "⚡ [Default Mode] active: Applied your manual speeds.");
        break;
    }
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void resetAllAppsToDefault() {
    for (var app in _apps) {
      app.speedMode = 'default';
      app.customSpeedLimitKbps = 0;
      app.isWifiAllowed = true;
      app.isMobileAllowed = true;
      app.tempAllowUntil = null;
    }
    _persistState();
    StorageService.saveAppSettings(_apps);
    syncNativeSettings();
    addLog(
        "OK",
        isArabic
            ? "⚡ تم ضبط جميع التطبيقات على الوضع العادي (يتبع سرعة الرئيسية)."
            : "⚡ All apps reset to Default mode (follows main speed).");
    notifyListeners();
  }

  void setDownloadSpeedLimit(int kbps) {
    config.downloadSpeedLimit = kbps;
    lastManualDownloadLimit = kbps;
    activePreset = 'default';
    config.presetMode = 'default';
    StorageService.saveManualLimits(
        lastManualDownloadLimit, lastManualUploadLimit);
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void setUploadSpeedLimit(int kbps) {
    config.uploadSpeedLimit = kbps;
    lastManualUploadLimit = kbps;
    activePreset = 'default';
    config.presetMode = 'default';
    StorageService.saveManualLimits(
        lastManualDownloadLimit, lastManualUploadLimit);
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void setCustomSpeeds(int dlKbps, int ulKbps) {
    config.downloadSpeedLimit = dlKbps;
    config.uploadSpeedLimit = ulKbps;
    lastManualDownloadLimit = dlKbps;
    lastManualUploadLimit = ulKbps;
    activePreset = 'default';
    config.presetMode = 'default';
    StorageService.saveManualLimits(
        lastManualDownloadLimit, lastManualUploadLimit);
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  int get customizedAppsCount {
    return _apps
        .where((a) =>
            !a.isWifiAllowed || !a.isMobileAllowed || a.speedMode != 'default')
        .length;
  }

  Future<int> saveCustomProfileSettings() async {
    final count = customizedAppsCount;
    await StorageService.saveCustomProfileSettings(
      _apps,
      config.downloadSpeedLimit,
      config.uploadSpeedLimit,
    );
    activeSecurityProfile = 'custom';
    _persistState();
    syncNativeSettings();
    addLog(
        "OK",
        isArabic
            ? "تم حفظ إعدادات وتكوين الوضع المخصص بنجاح ($count تطبيق معدل)."
            : "Custom profile settings saved ($count customized apps).");
    notifyListeners();
    return count;
  }

  Future<int> restoreAndApplyCustomProfile() async {
    final count = await StorageService.restoreCustomProfileSettings(_apps);
    if (count >= 0) {
      activeSecurityProfile = 'custom';
      config.globalMode = 'whitelist';
      _persistState();
      syncNativeSettings();
      addLog(
          "OK",
          isArabic
              ? "تم استعادة وتطبيق إعدادات الوضع المخصص بنجاح ($count تطبيق)."
              : "Custom profile restored and applied ($count apps).");
      notifyListeners();
      return count;
    }
    return -1;
  }

  void setDnsProvider(String provider) {
    config.selectedDnsProvider = provider;
    if (provider == 'Cloudflare') {
      config.dnsServers = ['1.1.1.1', '1.0.0.1'];
    } else if (provider == 'AdGuard') {
      config.dnsServers = ['94.140.14.14', '94.140.15.15'];
    } else if (provider == 'Google') {
      config.dnsServers = ['8.8.8.8', '8.8.4.4'];
    }
    _persistState();
    syncNativeSettings();
    addLog(
        "INFO",
        isArabic
            ? "تم اختيار مزود DNS: $provider"
            : "Selected DNS Provider: $provider");
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    _currentLocale = Locale(langCode);
    await StorageService.saveLanguage(langCode);
    await MethodChannelService.setAppLanguage(langCode);
    notifyListeners();
  }

  bool _isMonitorRunning = true;
  bool get isMonitorRunning => _isMonitorRunning;

  bool _isSpikeAlertEnabled = true;
  bool get isSpikeAlertEnabled => _isSpikeAlertEnabled;

  Future<void> toggleMonitorService() async {
    if (_isMonitorRunning) {
      final stopped = await MethodChannelService.stopMonitorService();
      if (stopped) {
        _isMonitorRunning = false;
        await StorageService.saveMonitorEnabled(false);
        addLog(
            "INFO",
            isArabic
                ? "تم إيقاف مراقب السرعة في الخلفية."
                : "Background speed monitor stopped.");
      } else {
        addLog(
            "WARN",
            isArabic
                ? "تعذر إيقاف مراقب السرعة."
                : "Could not stop the background speed monitor.");
      }
    } else {
      final started = await MethodChannelService.startMonitorService();
      if (started) {
        _isMonitorRunning = true;
        await StorageService.saveMonitorEnabled(true);
        addLog(
            "INFO",
            isArabic
                ? "تم تشغيل مراقب السرعة في الخلفية بنجاح."
                : "Background speed monitor started successfully.");
      } else {
        addLog(
            "WARN",
            isArabic
                ? "تعذر تشغيل مراقب السرعة."
                : "Could not start the background speed monitor.");
      }
    }
    notifyListeners();
  }

  Future<void> toggleSpikeAlert() async {
    _isSpikeAlertEnabled = !_isSpikeAlertEnabled;
    await MethodChannelService.setSpikeAlertEnabled(_isSpikeAlertEnabled);
    await StorageService.saveSpikeAlertEnabled(_isSpikeAlertEnabled);
    addLog(
        "INFO",
        _isSpikeAlertEnabled
            ? (isArabic
                ? "تم تفعيل كاشف النزيف السري للبيانات."
                : "Data spike detector enabled.")
            : (isArabic
                ? "تم تعطيل كاشف النزيف السري للبيانات."
                : "Data spike detector disabled."));
    notifyListeners();
  }

  void _persistState() {
    StorageService.saveConfig(config);
    StorageService.saveAppSettings(_apps);
  }

  // ── Hotspot Speed Controller Methods ──
  Future<void> refreshHotspotStatus() async {
    try {
      final status = await MethodChannelService.getHotspotProxyStatus();
      if (status.isNotEmpty) {
        _isHotspotRunning = status['isRunning'] == true;
        _hotspotPort = (status['port'] as num?)?.toInt() ?? _hotspotPort;
        _hotspotIp = status['ip']?.toString() ?? _hotspotIp;
        _hotspotActiveClients = (status['activeClients'] as num?)?.toInt() ?? 0;
        _hotspotTotalRxBytes = (status['totalRxBytes'] as num?)?.toInt() ?? 0;
        _hotspotTotalTxBytes = (status['totalTxBytes'] as num?)?.toInt() ?? 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> startHotspotProxy() async {
    final dlBps = _hotspotDownloadLimitKbps > 0
        ? _hotspotDownloadLimitKbps * 1024
        : -1;
    final ulBps = _hotspotUploadLimitKbps > 0
        ? _hotspotUploadLimitKbps * 1024
        : -1;
    final success = await MethodChannelService.startHotspotProxy(
      port: _hotspotPort,
      downloadLimit: dlBps,
      uploadLimit: ulBps,
    );
    if (success) {
      _isHotspotRunning = true;
      _hotspotIp = await MethodChannelService.getHotspotIp();
      addLog(
          "INFO",
          isArabic
              ? "تم تشغيل متحكم سرعة نقطة الاتصال (Hotspot) بنجاح على المنفذ $_hotspotPort."
              : "Hotspot speed controller started on port $_hotspotPort.");
      await StorageService.saveHotspotSettings(
        port: _hotspotPort,
        dlLimit: _hotspotDownloadLimitKbps,
        ulLimit: _hotspotUploadLimitKbps,
      );
      notifyListeners();
    }
    return success;
  }

  Future<void> stopHotspotProxy() async {
    await MethodChannelService.stopHotspotProxy();
    _isHotspotRunning = false;
    _hotspotActiveClients = 0;
    addLog(
        "INFO",
        isArabic
            ? "تم إيقاف متحكم سرعة بث نقطة الاتصال."
            : "Hotspot speed controller stopped.");
    notifyListeners();
  }

  Future<void> toggleHotspotProxy() async {
    if (_isHotspotRunning) {
      await stopHotspotProxy();
    } else {
      await startHotspotProxy();
    }
  }

  Future<void> setHotspotLimits({
    required int downloadKbps,
    required int uploadKbps,
  }) async {
    _hotspotDownloadLimitKbps = downloadKbps;
    _hotspotUploadLimitKbps = uploadKbps;
    final dlBps = downloadKbps > 0 ? downloadKbps * 1024 : -1;
    final ulBps = uploadKbps > 0 ? uploadKbps * 1024 : -1;
    if (_isHotspotRunning) {
      await MethodChannelService.updateHotspotRates(
        downloadLimit: dlBps,
        uploadLimit: ulBps,
      );
    }
    await StorageService.saveHotspotSettings(
      port: _hotspotPort,
      dlLimit: downloadKbps,
      ulLimit: uploadKbps,
    );
    notifyListeners();
  }

  Future<void> setHotspotPort(int port) async {
    _hotspotPort = port;
    if (_isHotspotRunning) {
      await stopHotspotProxy();
      await startHotspotProxy();
    } else {
      await StorageService.saveHotspotSettings(
        port: port,
        dlLimit: _hotspotDownloadLimitKbps,
        ulLimit: _hotspotUploadLimitKbps,
      );
      notifyListeners();
    }
  }


  void toggleBlockAllMode(bool blockAll) {
    config.globalMode = blockAll ? 'blacklist' : 'whitelist';
    if (blockAll) {
      activeSecurityProfile = 'block_all';
      // حظر جميع التطبيقات تلقائياً ليصبح الاستثناء يدوي فقط
      for (var app in _apps) {
        app.isWifiAllowed = false;
        app.isMobileAllowed = false;
        app.tempAllowUntil = null;
      }
      addLog(
          "WARN",
          isArabic
              ? "🛡️ تم تفعيل [وضع الحظر الشامل]: تم حظر جميع التطبيقات. الاستثناء يدوي لكل تطبيق."
              : "🛡️ [Master Block All] active: All apps blocked except whitelisted.");
    } else {
      activeSecurityProfile = 'allow_all';
      for (var app in _apps) {
        app.isWifiAllowed = true;
        app.isMobileAllowed = true;
      }
      addLog(
          "INFO",
          isArabic
              ? "🛡️ تم إيقاف [وضع الحظر الشامل] وفتح الاتصال لجميع التطبيقات."
              : "🛡️ [Master Block All] disabled: Internet access restored for all apps.");
    }
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void toggleMasterBlockAll(bool blockAll) => toggleBlockAllMode(blockAll);

  void addCustomBlockedDomain(String domain) {
    final clean = domain.trim().toLowerCase();
    if (clean.isNotEmpty && !config.blockedDomains.contains(clean)) {
      config.blockedDomains.add(clean);
      _persistState();
      syncNativeSettings();
      addLog(
          "WARN",
          isArabic
              ? "تمت إضافة $clean إلى قائمة الحظر."
              : "Added $clean to custom blocklist.");
      notifyListeners();
    }
  }

  void removeCustomBlockedDomain(String domain) {
    if (config.blockedDomains.remove(domain)) {
      _persistState();
      syncNativeSettings();
      addLog(
          "INFO",
          isArabic
              ? "تمت إزالة $domain من قائمة الحظر."
              : "Removed $domain from custom blocklist.");
      notifyListeners();
    }
  }

  void toggleAutoQuarantine(bool val) {
    autoQuarantineNewApps = val;
    if (!val) {
      for (final app in _apps) {
        if (app.isQuarantined) {
          app.isWifiAllowed = true;
          app.isMobileAllowed = true;
          app.isQuarantined = false;
          app.tempAllowUntil = null;
        }
      }
      StorageService.saveAppSettings(_apps);
      syncNativeSettings();
    }
    StorageService.saveAutoQuarantine(val);
    MethodChannelService.setAutoQuarantine(val);
    addLog(
        val ? "OK" : "WARN",
        isArabic
            ? "عزل التطبيقات الجديدة: ${val ? 'مفعّل' : 'معطّل'}"
            : "Quarantine new apps: ${val ? 'Enabled' : 'Disabled'}");
    _persistState();
    notifyListeners();
  }

  void toggleLockdownOnScreenOff(bool val) {
    lockdownOnScreenOff = val;
    StorageService.saveLockdownScreenOff(val);
    addLog(
        val ? "OK" : "WARN",
        isArabic
            ? "الحظر عند قفل الشاشة: ${val ? 'مفعّل' : 'معطّل'}"
            : "Block on screen off: ${val ? 'Enabled' : 'Disabled'}");
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void toggleBatchMode() {
    isBatchMode = !isBatchMode;
    if (!isBatchMode) {
      for (var app in _apps) {
        app.isSelected = false;
      }
    }
    notifyListeners();
  }

  void batchToggleSelectAll(bool select) {
    for (var app in _apps) {
      app.isSelected = select;
    }
    notifyListeners();
  }

  void batchSetAccess({required bool allow}) {
    int count = 0;
    for (var app in _apps) {
      if (app.isSelected) {
        app.isWifiAllowed = allow;
        app.isMobileAllowed = allow;
        app.tempAllowUntil = null;
        count++;
      }
    }
    _persistState();
    syncNativeSettings();
    addLog(
        "INFO",
        isArabic
            ? "تم ${allow ? 'فتح' : 'حظر'} الإنترنت عن $count تطبيق محدد."
            : "Internet ${allow ? 'allowed' : 'blocked'} for $count selected apps.");
    notifyListeners();
  }

  void batchSetSpeedMode(String mode, {int customSpeedKbps = 0}) {
    int count = 0;
    for (var app in _apps) {
      if (app.isSelected) {
        app.speedMode = mode;
        if (mode == 'custom') {
          app.customSpeedLimitKbps = customSpeedKbps;
        }
        count++;
      }
    }
    _persistState();
    syncNativeSettings();
    addLog(
        "INFO",
        isArabic
            ? "تم تحديث وضع سرعة $count تطبيق إلى $mode"
            : "Updated speed mode for $count apps to $mode");
    notifyListeners();
  }

  void setAppSpeedMode(AppInfo app, String mode, {int customSpeedKbps = 0}) {
    app.speedMode = mode;
    if (mode == 'custom') {
      app.customSpeedLimitKbps = customSpeedKbps;
    }
    _persistState();
    syncNativeSettings();
    final modeTitle = mode == 'default'
        ? (isArabic ? 'عادي (يتبع الرئيسية)' : 'Default (Follows Main)')
        : mode == 'unlimited'
            ? (isArabic ? 'مفتوح (غير مقيد ∞)' : 'Unlimited (∞)')
            : (isArabic
                ? 'مخصص \u202A(${customSpeedKbps == 0 ? '0 KB/s كتم' : '\u200E$customSpeedKbps KB/s'})\u202C'
                : 'Custom (${customSpeedKbps == 0 ? '0 KB/s Muted' : '$customSpeedKbps KB/s'})');
    addLog(
        "INFO",
        isArabic
            ? "سرعة ${app.name} → $modeTitle"
            : "${app.name} speed → $modeTitle");
    notifyListeners();
  }

  void grantTemporaryPass(AppInfo app, Duration duration) {
    app.tempAllowUntil = DateTime.now().add(duration);
    app.isWifiAllowed = true;
    app.isMobileAllowed = true;
    addLog(
        "OK",
        isArabic
            ? "تصريح مؤقت لـ ${app.name} لمدة ${duration.inMinutes} دقيقة."
            : "Temporary pass for ${app.name} (${duration.inMinutes} mins).");
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void revokeTemporaryPass(AppInfo app) {
    app.tempAllowUntil = null;
    app.isWifiAllowed = false;
    app.isMobileAllowed = false;
    addLog(
        "WARN",
        isArabic
            ? "تم إلغاء التصريح المؤقت لـ ${app.name} وإعادته للحظر."
            : "Temporary pass revoked for ${app.name}; app blocked.");
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void toggleAppWifi(AppInfo app) {
    app.isWifiAllowed = !app.isWifiAllowed;
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void toggleAppMobile(AppInfo app) {
    app.isMobileAllowed = !app.isMobileAllowed;
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  Future<void> applySecurityProfile(String profile) async {
    activeSecurityProfile = profile;
    switch (profile) {
      case 'ultra_saver':
        setPreset('eco');
        break;

      case 'focus':
        for (var app in _apps) {
          final isSocial = app.packageName.contains('youtube') ||
              app.packageName.contains('tiktok') ||
              app.packageName.contains('instagram') ||
              app.packageName.contains('facebook') ||
              app.packageName.contains('snapchat') ||
              app.packageName.contains('twitter');
          if (isSocial) {
            app.isWifiAllowed = false;
            app.isMobileAllowed = false;
            app.speedMode = 'custom';
            app.customSpeedLimitKbps = 0;
          } else {
            app.isWifiAllowed = true;
            app.isMobileAllowed = true;
            app.speedMode = 'default';
          }
        }
        addLog(
            "INFO",
            isArabic
                ? "🎯 تم تفعيل [وضع التركيز] — حظر شبكات التواصل الاجتماعي."
                : "🎯 [Focus Mode] active: Social media apps blocked.");
        break;

      case 'custom':
      default:
        // استرجاع الإعدادات والتخصيصات اليدوية التي حددها المستخدم سابقاً بدقة 100%
        final restored =
            await StorageService.restoreCustomProfileSettings(_apps);
        if (restored >= 0) {
          final limits = await StorageService.loadManualLimits();
          if (limits['dl'] != null && limits['dl']! >= 0) {
            config.downloadSpeedLimit = limits['dl']!;
          }
          if (limits['ul'] != null && limits['ul']! >= 0) {
            config.uploadSpeedLimit = limits['ul']!;
          }
        }
        addLog(
            "OK",
            isArabic
                ? "✨ تم استرجاع جميع إعداداتك وتخصيصاتك اليدوية للوضع المخصص بالكامل."
                : "✨ Custom profile manual settings restored completely.");
        break;
    }
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  Future<bool> saveCustomProfileManualSettings() async {
    try {
      await StorageService.saveManualCustomSettings(
        _apps,
        config.downloadSpeedLimit,
        config.uploadSpeedLimit,
      );
      _persistState();
      syncNativeSettings();
      addLog(
          "OK",
          isArabic
              ? "💾 تم حفظ الإعدادات والتخصيصات اليدوية بنجاح."
              : "💾 Manual custom profile settings saved successfully.");
      notifyListeners();
      return true;
    } catch (e) {
      addLog(
          "ERR",
          isArabic
              ? "فشل حفظ الإعدادات: ${e.toString()}"
              : "Failed to save settings: ${e.toString()}");
      return false;
    }
  }

  Future<void> fetchInstalledApps() async {
    if (_isLoadingApps) return;
    _isLoadingApps = true;
    notifyListeners();
    try {
      final List<dynamic> appsJson =
          await MethodChannelService.getInstalledApps();
      _apps.clear();
      for (var item in appsJson) {
        _apps.add(AppInfo.fromJson(Map<String, dynamic>.from(item)));
      }
      try {
        final appTraffic = await MethodChannelService.getPerAppTraffic();
        if (appTraffic.isNotEmpty) {
          for (var app in _apps) {
            if (appTraffic.containsKey(app.packageName)) {
              app.totalMb = appTraffic[app.packageName]!;
            }
          }
        }
      } catch (_) {}
      await StorageService.applySavedAppSettings(_apps,
          autoQuarantine: autoQuarantineNewApps);
      addLog(
          "OK",
          isArabic
              ? "تم فحص وتطبيق إعدادات ${_apps.length} تطبيق."
              : "Scanned and applied settings for ${_apps.length} apps.");
    } catch (e) {
      _apps.clear();
      addLog(
          "WARN",
          isArabic
              ? "تعذر قراءة قائمة التطبيقات من النظام: ${e.toString()}"
              : "Could not read app list from system: ${e.toString()}");
    } finally {
      _isLoadingApps = false;
      notifyListeners();
    }
  }

  Future<void> toggleVpn() async {
    if (_isVpnTransitioning) return;

    _isVpnTransitioning = true;
    config.isVpnActive = !config.isVpnActive;
    _persistState();
    notifyListeners();
    try {
      if (config.isVpnActive) {
        final List<String> blockedWifiApps = [];
        final List<String> blockedDataApps = [];
        final List<String> allowedFirewallApps = [];
        final Map<String, dynamic> modesMap = {};
        final Map<String, dynamic> limitsMap = {};

        for (var app in _apps) {
          if (!app.isWifiAllowed && !app.isTempAllowed) {
            blockedWifiApps.add(app.packageName);
          }
          if (!app.isMobileAllowed && !app.isTempAllowed) {
            blockedDataApps.add(app.packageName);
          }

          if (isBlockAllMode &&
              ((app.isWifiAllowed || app.isMobileAllowed) ||
                  app.isTempAllowed)) {
            allowedFirewallApps.add(app.packageName);
          }

          modesMap[app.packageName] = app.speedMode;
          if (app.speedMode == 'custom') {
            limitsMap[app.packageName] = app.customSpeedLimitKbps;
          }
        }

        final String appSpeedConfigsJson = json.encode({
          'modes': modesMap,
          'limits': limitsMap,
          'isGamingMode': false,
        });

        final dlBytes = config.downloadSpeedLimit == -1
            ? -1
            : config.downloadSpeedLimit * 1024;
        final ulBytes =
            config.uploadSpeedLimit == -1 ? -1 : config.uploadSpeedLimit * 1024;

        final started = await MethodChannelService.startVpn(
          downloadLimit: dlBytes,
          uploadLimit: ulBytes,
          blockedWifiApps: blockedWifiApps,
          blockedDataApps: blockedDataApps,
          blockAllFirewall: isBlockAllMode,
          allowedFirewallApps: allowedFirewallApps,
          dnsAdBlock: config.blockAds,
          dnsAdultBlock: config.blockAdult,
          dnsSocialBlock: config.blockSocial,
          dnsCustomBlocked: config.blockedDomains,
          dnsServers: _resolveActiveDnsServers(),
          dataCapBytes: config.dataCapMb * 1024 * 1024,
          dataCapAction: config.capAction,
          schedEnabled: config.scheduleEnabled,
          schedStartH: config.activeScheduleStartHour,
          schedStartM: config.schedStartM,
          schedEndH: config.activeScheduleEndHour,
          schedEndM: config.schedEndM,
          appSpeedConfigs: appSpeedConfigsJson,
          lockdownScreenOff: lockdownOnScreenOff,
          ebpfEnabled: config.ebpfEnabled,
          dpiEnabled: config.dpiEnabled,
          dnsRebindingProtection: config.dnsRebindingProtection,
        );

        if (started) {
          addLog(
              "OK",
              isArabic
                  ? "تم تشغيل محرك VPN وتطبيق السرعات المحددة."
                  : "VPN engine active; configured speed limits applied.");
        } else {
          config.isVpnActive = false;
          addLog(
              "WARN",
              isArabic
                  ? "يتطلب VPN موافقة الإذن من أندرويد."
                  : "VPN requires user permission from Android.");
        }
      } else {
        final stopped = await MethodChannelService.stopVpn();
        if (stopped) {
          addLog(
              "WARN",
              isArabic
                  ? "تم إيقاف خدمة VPN واسترجاع السرعة الافتراضية."
                  : "VPN service stopped; default speeds restored.");
        } else {
          config.isVpnActive = true;
        }
      }
    } finally {
      _isVpnTransitioning = false;
      _persistState();
      notifyListeners();
    }
  }

  void updateConfigFromJson(Map<String, dynamic> map) {
    final imported = VpnConfig.fromJson(map);
    config.globalMode = imported.globalMode;
    config.downloadSpeedLimit = imported.downloadSpeedLimit;
    config.uploadSpeedLimit = imported.uploadSpeedLimit;
    config.presetMode = imported.presetMode;
    config.ebpfEnabled = imported.ebpfEnabled;
    config.dpiEnabled = imported.dpiEnabled;
    config.blockAds = imported.blockAds;
    config.blockAdult = imported.blockAdult;
    config.blockSocial = imported.blockSocial;
    config.dnsRebindingProtection = imported.dnsRebindingProtection;
    config.selectedDnsProvider = imported.selectedDnsProvider;
    config.customDnsPrimary = imported.customDnsPrimary;
    config.customDnsSecondary = imported.customDnsSecondary;
    config.blockedDomains = imported.blockedDomains;
    config.dataCapMb = imported.dataCapMb;
    config.capAction = imported.capAction;
    config.scheduleEnabled = imported.scheduleEnabled;
    config.activeScheduleStartHour = imported.activeScheduleStartHour;
    config.activeScheduleEndHour = imported.activeScheduleEndHour;
    config.proxyEnabled = imported.proxyEnabled;
    config.upstreamProxyHost = imported.upstreamProxyHost;
    config.upstreamProxyPort = imported.upstreamProxyPort;
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void syncNativeSettings() {
    _persistState();
    final List<String> blockedWifiApps = [];
    final List<String> blockedDataApps = [];
    final List<String> allowedFirewallApps = [];
    final Map<String, dynamic> modesMap = {};
    final Map<String, dynamic> limitsMap = {};

    for (var app in _apps) {
      if (!app.isWifiAllowed && !app.isTempAllowed) {
        blockedWifiApps.add(app.packageName);
      }
      if (!app.isMobileAllowed && !app.isTempAllowed) {
        blockedDataApps.add(app.packageName);
      }

      if (isBlockAllMode) {
        if ((app.isWifiAllowed || app.isMobileAllowed) || app.isTempAllowed) {
          allowedFirewallApps.add(app.packageName);
        }
      }

      modesMap[app.packageName] = app.speedMode;
      if (app.speedMode == 'custom') {
        limitsMap[app.packageName] = app.customSpeedLimitKbps;
      }
    }

    final String appSpeedConfigsJson = json.encode({
      'modes': modesMap,
      'limits': limitsMap,
      'isGamingMode': false,
    });

    final dlBytes =
        config.downloadSpeedLimit == -1 ? -1 : config.downloadSpeedLimit * 1024;
    final ulBytes =
        config.uploadSpeedLimit == -1 ? -1 : config.uploadSpeedLimit * 1024;

    MethodChannelService.updateSettings(
      downloadLimit: dlBytes,
      uploadLimit: ulBytes,
      blockedWifiApps: blockedWifiApps,
      blockedDataApps: blockedDataApps,
      blockAllFirewall: isBlockAllMode,
      allowedFirewallApps: allowedFirewallApps,
      dnsAdBlock: config.blockAds,
      dnsAdultBlock: config.blockAdult,
      dnsSocialBlock: config.blockSocial,
      dnsCustomBlocked: config.blockedDomains,
      dnsServers: _resolveActiveDnsServers(),
      dataCapBytes: config.dataCapMb * 1024 * 1024,
      dataCapAction: config.capAction,
      schedEnabled: config.scheduleEnabled,
      schedStartH: config.activeScheduleStartHour,
      schedStartM: config.schedStartM,
      schedEndH: config.activeScheduleEndHour,
      schedEndM: config.schedEndM,
      appSpeedConfigs: appSpeedConfigsJson,
      lockdownScreenOff: lockdownOnScreenOff,
      ebpfEnabled: config.ebpfEnabled,
      dpiEnabled: config.dpiEnabled,
      dnsRebindingProtection: config.dnsRebindingProtection,
    );
  }

  List<String> _resolveActiveDnsServers() {
    if (config.blockAdult && config.selectedDnsProvider == 'Cloudflare') {
      return [
        '1.1.1.3',
        '1.0.0.3'
      ]; // Cloudflare Family (Malware + Adult Block)
    }
    if (config.blockAdult && config.selectedDnsProvider == 'AdGuard') {
      return ['94.140.14.15', '94.140.15.16']; // AdGuard Family
    }
    switch (config.selectedDnsProvider) {
      case 'Google':
        return ['8.8.8.8', '8.8.4.4'];
      case 'Quad9':
        return ['9.9.9.9', '149.112.112.112'];
      case 'AdGuard':
        return ['94.140.14.14', '94.140.15.15'];
      case 'Cloudflare':
      default:
        return ['1.1.1.1', '1.0.0.1'];
    }
  }

  void addBlockedDomain(String domain) {
    String cleanDomain =
        domain.trim().replaceAll(RegExp(r'https?://|www\.'), '');
    if (cleanDomain.isNotEmpty &&
        !config.blockedDomains.contains(cleanDomain)) {
      config.blockedDomains.add(cleanDomain);
      addLog(
          "BLOCK",
          isArabic
              ? "تم حظر النطاق: $cleanDomain"
              : "Blocked domain: $cleanDomain");
      _persistState();
      syncNativeSettings();
      notifyListeners();
    }
  }

  void removeBlockedDomain(String domain) {
    config.blockedDomains.remove(domain);
    addLog(
        "INFO",
        isArabic
            ? "تم رفع الحظر عن النطاق: $domain"
            : "Unblocked domain: $domain");
    _persistState();
    syncNativeSettings();
    notifyListeners();
  }

  void addLog(String level, String message) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    _terminalLogs.insert(0, {"time": timeStr, "level": level, "msg": message});
    if (_terminalLogs.length > 500) _terminalLogs.removeLast();
    notifyListeners();
  }

  void clearLogs() {
    _terminalLogs.clear();
    notifyListeners();
  }

  void _startTempPassWatchdog() {
    _tempPassTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      bool needSync = false;
      final now = DateTime.now();
      for (var app in _apps) {
        if (app.tempAllowUntil != null && now.isAfter(app.tempAllowUntil!)) {
          app.tempAllowUntil = null;
          app.isWifiAllowed = false;
          app.isMobileAllowed = false;
          needSync = true;
          addLog(
              "WARN",
              isArabic
                  ? "⏳ انتهت صلاحية التصريح المؤقت لـ ${app.name} وتم حظره."
                  : "⏳ Temporary pass expired for ${app.name}; app blocked.");
        }
      }
      if (needSync) {
        _persistState();
        syncNativeSettings();
        notifyListeners();
      }
    });
  }

  int _tickCount = 0;
  double _lastNotifiedDown = -1.0;
  double _lastNotifiedUp = -1.0;

  void _startRealTrafficTicker() {
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_statsRequestInFlight) return;
      _statsRequestInFlight = true;
      try {
        if (config.isVpnActive) {
          final stats = await MethodChannelService.getRealTrafficStats();
          if (stats.isNotEmpty) {
            final rawDownBps =
                (stats['downloadBps'] as num?)?.toDouble() ?? 0.0;
            final rawUpBps = (stats['uploadBps'] as num?)?.toDouble() ?? 0.0;
            final rawTotalDown =
                (stats['totalDownloadBytes'] as num?)?.toDouble() ?? 0.0;
            final rawTotalUp =
                (stats['totalUploadBytes'] as num?)?.toDouble() ?? 0.0;

            _currentDownloadSpeed = rawDownBps / 1024.0;
            _currentUploadSpeed = rawUpBps / 1024.0;
            _totalDownloadMb = rawTotalDown / (1024.0 * 1024.0);
            _totalUploadMb = rawTotalUp / (1024.0 * 1024.0);
          }
        }

        // قراءة استهلاك اليوم الحقيقي والسرعة اللحظية من مراقب الشبكة المستقل في الخلفية
        final monitorStats = await MethodChannelService.getMonitorLiveStats();
        if (monitorStats.isNotEmpty) {
          final wifiBytes =
              (monitorStats['todayWifiBytes'] as num?)?.toDouble() ?? 0.0;
          final mobileBytes =
              (monitorStats['todayMobileBytes'] as num?)?.toDouble() ?? 0.0;
          final totalBytes = wifiBytes + mobileBytes;
          if (totalBytes > 0) {
            _todayRealUsageMb = totalBytes / (1024.0 * 1024.0);
          }
          if (!config.isVpnActive) {
            final rawDown =
                (monitorStats['downloadBps'] as num?)?.toDouble() ?? 0.0;
            final rawUp =
                (monitorStats['uploadBps'] as num?)?.toDouble() ?? 0.0;
            _currentDownloadSpeed = rawDown / 1024.0;
            _currentUploadSpeed = rawUp / 1024.0;
          }
        }

        _tickCount++;
        if (_tickCount % 6 == 0 || _tickCount == 1) {
          final appTraffic = await MethodChannelService.getPerAppTraffic();
          if (appTraffic.isNotEmpty) {
            bool anyUpdated = false;
            for (var app in _apps) {
              if (appTraffic.containsKey(app.packageName)) {
                final newMb = appTraffic[app.packageName]!;
                if ((app.totalMb - newMb).abs() > 0.01) {
                  app.totalMb = newMb;
                  anyUpdated = true;
                }
              }
            }
            if (anyUpdated) {
              notifyListeners();
            }
          }
        }

        if (_isHotspotRunning && _tickCount % 2 == 0) {
          await refreshHotspotStatus();
        }
      } catch (_) {
      } finally {
        _statsRequestInFlight = false;
      }

      _downloadHistory.removeAt(0);
      _downloadHistory.add(_currentDownloadSpeed);
      _uploadHistory.removeAt(0);
      _uploadHistory.add(_currentUploadSpeed);

      final speedChanged = (_lastNotifiedDown != _currentDownloadSpeed ||
          _lastNotifiedUp != _currentUploadSpeed);
      if (speedChanged ||
          _currentDownloadSpeed > 0 ||
          _currentUploadSpeed > 0) {
        _lastNotifiedDown = _currentDownloadSpeed;
        _lastNotifiedUp = _currentUploadSpeed;
        notifyListeners();
      }
    });
  }

  void pauseTrafficTicker() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void resumeTrafficTicker() {
    if (_statsTimer == null) {
      _startRealTrafficTicker();
    }
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _tempPassTimer?.cancel();
    super.dispose();
  }
}
