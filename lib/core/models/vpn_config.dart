class VpnConfig {
  bool isVpnActive;
  String globalMode; // 'blacklist' or 'whitelist'
  int downloadSpeedLimit; // KB/s (-1 = unlimited, 0 = 0 KB/s frozen, >0 = throttled)
  int uploadSpeedLimit;   // KB/s (-1 = unlimited, 0 = 0 KB/s frozen, >0 = throttled)
  String presetMode;      // 'eco', 'balanced', 'performance', 'unrestricted', 'zero', 'manual'
  
  // DPI & Kernel
  bool ebpfEnabled;
  bool dpiEnabled;

  // DNS Filters & DoH (DNS-over-HTTPS)
  bool blockAds;
  bool blockAdult;
  bool blockSocial;
  bool dnsRebindingProtection;
  bool dohEnabled;
  String dohProvider; // 'cloudflare', 'adguard', 'google', 'custom'
  String customDohUrl;
  bool ipv6LeakProtection;
  String selectedDnsProvider; // 'Cloudflare', 'Google', 'Quad9', 'AdGuard', 'Custom'
  String customDnsPrimary;
  String customDnsSecondary;
  List<String> blockedDomains;
  List<String> customFilterLists;

  // Data Cap
  int dataCapMb; // Limit in MB
  String capAction; // 'throttle', 'disconnect', 'notify'
  String get dataCapAction => capAction;
  set dataCapAction(String val) => capAction = val;

  bool alert50;
  bool alert75;
  bool alert90;
  bool scheduleEnabled;
  bool get schedEnabled => scheduleEnabled;
  set schedEnabled(bool val) => scheduleEnabled = val;

  int activeScheduleStartHour;
  int get schedStartH => activeScheduleStartHour;
  set schedStartH(int val) => activeScheduleStartHour = val;

  int schedStartM = 0;

  int activeScheduleEndHour;
  int get schedEndH => activeScheduleEndHour;
  set schedEndH(int val) => activeScheduleEndHour = val;

  int schedEndM = 0;

  List<String> get dnsCustomBlocked => blockedDomains;
  set dnsCustomBlocked(List<String> val) => blockedDomains = val;

  List<String> get dnsServers => [customDnsPrimary, customDnsSecondary];
  set dnsServers(List<String> val) {
    if (val.isNotEmpty) customDnsPrimary = val[0];
    if (val.length > 1) customDnsSecondary = val[1];
  }

  // SOCKS5 Proxy & Upstream
  bool proxyEnabled;
  String localProxyHost;
  int localProxyPort;
  String upstreamProxyHost;
  int upstreamProxyPort;
  String upstreamProxyType; // 'SOCKS5', 'HTTP'
  String upstreamUsername;
  String upstreamPassword;
  bool upstreamUseSsl;

  VpnConfig({
    this.isVpnActive = false,
    this.globalMode = 'whitelist',
    this.downloadSpeedLimit = -1, // -1 = Unlimited
    this.uploadSpeedLimit = -1,   // -1 = Unlimited
    this.presetMode = 'unrestricted',
    this.ebpfEnabled = true,
    this.dpiEnabled = true,
    this.blockAds = true,
    this.blockAdult = true,
    this.blockSocial = false,
    this.dnsRebindingProtection = true,
    this.dohEnabled = false,
    this.dohProvider = 'cloudflare',
    this.customDohUrl = '',
    this.ipv6LeakProtection = true,
    this.selectedDnsProvider = 'Cloudflare',
    this.customDnsPrimary = '1.1.1.1',
    this.customDnsSecondary = '1.0.0.1',
    List<String>? blockedDomains,
    List<String>? customFilterLists,
    this.dataCapMb = 5000,
    this.capAction = 'throttle',
    this.alert50 = true,
    this.alert75 = true,
    this.alert90 = true,
    this.scheduleEnabled = false,
    this.activeScheduleStartHour = 8,
    this.activeScheduleEndHour = 22,
    this.proxyEnabled = false,
    this.localProxyHost = '127.0.0.1',
    this.localProxyPort = 1080,
    this.upstreamProxyHost = '127.0.0.1',
    this.upstreamProxyPort = 1080,
    this.upstreamProxyType = 'SOCKS5',
    this.upstreamUsername = '',
    this.upstreamPassword = '',
    this.upstreamUseSsl = false,
  })  : blockedDomains = blockedDomains ?? ['doubleclick.net', 'analytics.google.com', 'tracking.ad-server.com'],
        customFilterLists = customFilterLists ?? ['https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt'];

  String get effectiveDohUrl {
    switch (dohProvider.toLowerCase()) {
      case 'adguard':
        return 'https://dns.adguard-dns.com/dns-query';
      case 'google':
        return 'https://dns.google/dns-query';
      case 'custom':
        return customDohUrl.isNotEmpty ? customDohUrl : 'https://cloudflare-dns.com/dns-query';
      case 'cloudflare':
      default:
        return 'https://cloudflare-dns.com/dns-query';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'isVpnActive': isVpnActive,
      'globalMode': globalMode,
      'downloadSpeedLimit': downloadSpeedLimit,
      'uploadSpeedLimit': uploadSpeedLimit,
      'presetMode': presetMode,
      'ebpfEnabled': ebpfEnabled,
      'dpiEnabled': dpiEnabled,
      'blockAds': blockAds,
      'blockAdult': blockAdult,
      'blockSocial': blockSocial,
      'dnsRebindingProtection': dnsRebindingProtection,
      'dohEnabled': dohEnabled,
      'dohProvider': dohProvider,
      'customDohUrl': customDohUrl,
      'ipv6LeakProtection': ipv6LeakProtection,
      'selectedDnsProvider': selectedDnsProvider,
      'customDnsPrimary': customDnsPrimary,
      'customDnsSecondary': customDnsSecondary,
      'blockedDomains': blockedDomains,
      'customFilterLists': customFilterLists,
      'dataCapMb': dataCapMb,
      'capAction': capAction,
      'alert50': alert50,
      'alert75': alert75,
      'alert90': alert90,
      'scheduleEnabled': scheduleEnabled,
      'activeScheduleStartHour': activeScheduleStartHour,
      'schedStartM': schedStartM,
      'activeScheduleEndHour': activeScheduleEndHour,
      'schedEndM': schedEndM,
      'proxyEnabled': proxyEnabled,
      'localProxyHost': localProxyHost,
      'localProxyPort': localProxyPort,
      'upstreamProxyHost': upstreamProxyHost,
      'upstreamProxyPort': upstreamProxyPort,
      'upstreamProxyType': upstreamProxyType,
      'upstreamUsername': upstreamUsername,
      'upstreamPassword': upstreamPassword,
      'upstreamUseSsl': upstreamUseSsl,
    };
  }

  factory VpnConfig.fromJson(Map<String, dynamic> json) {
    final cfg = VpnConfig(
      isVpnActive: json['isVpnActive'] ?? false,
      globalMode: json['globalMode'] ?? 'whitelist',
      downloadSpeedLimit: json['downloadSpeedLimit'] ?? -1,
      uploadSpeedLimit: json['uploadSpeedLimit'] ?? -1,
      presetMode: json['presetMode'] ?? 'unrestricted',
      ebpfEnabled: json['ebpfEnabled'] ?? true,
      dpiEnabled: json['dpiEnabled'] ?? true,
      blockAds: json['blockAds'] ?? true,
      blockAdult: json['blockAdult'] ?? true,
      blockSocial: json['blockSocial'] ?? false,
      dnsRebindingProtection: json['dnsRebindingProtection'] ?? true,
      dohEnabled: json['dohEnabled'] ?? false,
      dohProvider: json['dohProvider'] ?? 'cloudflare',
      customDohUrl: json['customDohUrl'] ?? '',
      ipv6LeakProtection: json['ipv6LeakProtection'] ?? true,
      selectedDnsProvider: json['selectedDnsProvider'] ?? 'Cloudflare',
      customDnsPrimary: json['customDnsPrimary'] ?? '1.1.1.1',
      customDnsSecondary: json['customDnsSecondary'] ?? '1.0.0.1',
      blockedDomains: List<String>.from(json['blockedDomains'] ?? []),
      customFilterLists: List<String>.from(json['customFilterLists'] ?? []),
      dataCapMb: json['dataCapMb'] ?? 5000,
      capAction: json['capAction'] ?? 'throttle',
      alert50: json['alert50'] ?? true,
      alert75: json['alert75'] ?? true,
      alert90: json['alert90'] ?? true,
      scheduleEnabled: json['scheduleEnabled'] ?? false,
      activeScheduleStartHour: json['activeScheduleStartHour'] ?? 8,
      activeScheduleEndHour: json['activeScheduleEndHour'] ?? 22,
      proxyEnabled: json['proxyEnabled'] ?? false,
      localProxyHost: json['localProxyHost'] ?? '127.0.0.1',
      localProxyPort: json['localProxyPort'] ?? 1080,
      upstreamProxyHost: json['upstreamProxyHost'] ?? '127.0.0.1',
      upstreamProxyPort: json['upstreamProxyPort'] ?? 1080,
      upstreamProxyType: json['upstreamProxyType'] ?? 'SOCKS5',
      upstreamUsername: json['upstreamUsername'] ?? '',
      upstreamPassword: json['upstreamPassword'] ?? '',
      upstreamUseSsl: json['upstreamUseSsl'] ?? false,
    );
    cfg.schedStartM = json['schedStartM'] ?? 0;
    cfg.schedEndM = json['schedEndM'] ?? 0;
    return cfg;
  }
}
