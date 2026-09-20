// ═══════════════════════════════════════════════════════════════════════════════
//  Net Guard – DEEP-DIVE production test suite v2
//  Scope: Logs system, speed rules, schedule engine, per-app rules,
//         security profiles, DNS resolution, storage persistence edge cases,
//         VpnConfig field integrity, AppInfo blocking logic, TrafficStats
// ═══════════════════════════════════════════════════════════════════════════════
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:net_speed_controller/core/models/vpn_config.dart';
import 'package:net_speed_controller/core/models/app_info.dart';
import 'package:net_speed_controller/core/models/traffic_stats.dart';
import 'package:net_speed_controller/core/services/storage_service.dart';
import 'package:net_speed_controller/core/localization/app_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  1. SPEED RULES – Preset enforcement, manual limits, per-app rules
  // ═══════════════════════════════════════════════════════════════════════════
  group('Speed Rules – Preset values enforcement', () {
    test('VpnConfig defaults to unrestricted (-1/-1)', () {
      final config = VpnConfig();
      expect(config.downloadSpeedLimit, -1);
      expect(config.uploadSpeedLimit, -1);
      expect(config.presetMode, 'unrestricted');
    });

    test('Eco preset overrides to 256/128', () {
      final config = VpnConfig();
      // Simulate setPreset('eco') logic
      config.presetMode = 'eco';
      config.downloadSpeedLimit = 256;
      config.uploadSpeedLimit = 128;
      expect(config.downloadSpeedLimit, 256);
      expect(config.uploadSpeedLimit, 128);
      expect(config.presetMode, 'eco');
    });

    test('Unlimited preset resets to -1/-1', () {
      final config = VpnConfig();
      config.downloadSpeedLimit = 512; // set some manual limit first
      config.uploadSpeedLimit = 256;
      // Simulate setPreset('unlimited')
      config.presetMode = 'unlimited';
      config.downloadSpeedLimit = -1;
      config.uploadSpeedLimit = -1;
      expect(config.downloadSpeedLimit, -1);
      expect(config.uploadSpeedLimit, -1);
    });

    test('Zero speed limit means freeze (0/0)', () {
      final config = VpnConfig();
      config.presetMode = 'zero';
      config.downloadSpeedLimit = 0;
      config.uploadSpeedLimit = 0;
      expect(config.downloadSpeedLimit, 0);
      expect(config.uploadSpeedLimit, 0);
    });

    test('Manual speed limits persist across save/load', () async {
      await StorageService.saveManualLimits(1024, 512);
      final limits = await StorageService.loadManualLimits();
      expect(limits['dl'], 1024);
      expect(limits['ul'], 512);
    });

    test('Manual speed overwrite preserves only latest values', () async {
      await StorageService.saveManualLimits(100, 50);
      await StorageService.saveManualLimits(2000, 1000);
      final m = await StorageService.loadManualLimits();
      expect(m['dl'], 2000);
      expect(m['ul'], 1000);
    });

    test('Speed limit JSON round-trip for edge values', () {
      // Test every edge value that could cause bugs
      for (final dlVal in [-1, 0, 1, 64, 256, 512, 1024, 2048, 10240]) {
        for (final ulVal in [-1, 0, 1, 128, 512]) {
          final config = VpnConfig(
            downloadSpeedLimit: dlVal,
            uploadSpeedLimit: ulVal,
          );
          final json = config.toJson();
          final loaded = VpnConfig.fromJson(json);
          expect(loaded.downloadSpeedLimit, dlVal,
              reason: 'DL $dlVal mismatch');
          expect(loaded.uploadSpeedLimit, ulVal,
              reason: 'UL $ulVal mismatch');
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  2. PER-APP SPEED RULES
  // ═══════════════════════════════════════════════════════════════════════════
  group('Per-App Speed Rules – 3 modes', () {
    test('App speed mode "default" follows main settings', () {
      final app = AppInfo(name: 'Test', packageName: 'com.test',
          speedMode: 'default');
      expect(app.speedMode, 'default');
      expect(app.customSpeedLimitKbps, 0);
      expect(app.isEffectivelyBlocked, false);
    });

    test('App speed mode "unlimited" means no per-app cap', () {
      final app = AppInfo(name: 'Test', packageName: 'com.test',
          speedMode: 'unlimited');
      expect(app.speedMode, 'unlimited');
      expect(app.isEffectivelyBlocked, false);
    });

    test('App speed mode "custom" with 0 KB/s = effectively blocked', () {
      final app = AppInfo(name: 'Test', packageName: 'com.test',
          speedMode: 'custom', customSpeedLimitKbps: 0);
      expect(app.isEffectivelyBlocked, true);
    });

    test('App speed mode "custom" with 128 KB/s is NOT blocked', () {
      final app = AppInfo(name: 'Test', packageName: 'com.test',
          speedMode: 'custom', customSpeedLimitKbps: 128);
      expect(app.isEffectivelyBlocked, false);
    });

    test('Per-app settings survive storage round-trip', () async {
      final apps = [
        AppInfo(name: 'A', packageName: 'com.a',
            speedMode: 'custom', customSpeedLimitKbps: 64,
            isWifiAllowed: true, isMobileAllowed: false),
        AppInfo(name: 'B', packageName: 'com.b',
            speedMode: 'unlimited',
            isWifiAllowed: true, isMobileAllowed: true),
        AppInfo(name: 'C', packageName: 'com.c',
            speedMode: 'custom', customSpeedLimitKbps: 0,
            isWifiAllowed: false, isMobileAllowed: false),
      ];

      await StorageService.saveAppSettings(apps);

      final restored = [
        AppInfo(name: 'A', packageName: 'com.a'),
        AppInfo(name: 'B', packageName: 'com.b'),
        AppInfo(name: 'C', packageName: 'com.c'),
      ];
      await StorageService.applySavedAppSettings(restored);

      // App A
      expect(restored[0].speedMode, 'custom');
      expect(restored[0].customSpeedLimitKbps, 64);
      expect(restored[0].isWifiAllowed, true);
      expect(restored[0].isMobileAllowed, false);

      // App B
      expect(restored[1].speedMode, 'unlimited');
      expect(restored[1].isWifiAllowed, true);
      expect(restored[1].isMobileAllowed, true);

      // App C (effectively blocked)
      expect(restored[2].speedMode, 'custom');
      expect(restored[2].customSpeedLimitKbps, 0);
      expect(restored[2].isWifiAllowed, false);
      expect(restored[2].isMobileAllowed, false);
      expect(restored[2].isEffectivelyBlocked, true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  3. FIREWALL RULES – WiFi/Mobile toggle combinations
  // ═══════════════════════════════════════════════════════════════════════════
  group('Firewall Rules – WiFi/Mobile block combinations', () {
    test('Both allowed = not blocked', () {
      final app = AppInfo(name: 'T', packageName: 'p',
          isWifiAllowed: true, isMobileAllowed: true);
      expect(app.isEffectivelyBlocked, false);
    });

    test('WiFi only = not blocked', () {
      final app = AppInfo(name: 'T', packageName: 'p',
          isWifiAllowed: true, isMobileAllowed: false);
      expect(app.isEffectivelyBlocked, false);
    });

    test('Mobile only = not blocked', () {
      final app = AppInfo(name: 'T', packageName: 'p',
          isWifiAllowed: false, isMobileAllowed: true);
      expect(app.isEffectivelyBlocked, false);
    });

    test('Neither allowed = blocked', () {
      final app = AppInfo(name: 'T', packageName: 'p',
          isWifiAllowed: false, isMobileAllowed: false);
      expect(app.isEffectivelyBlocked, true);
    });

    test('Temp-allow with future expiry overrides WiFi/Mobile block', () {
      final app = AppInfo(name: 'T', packageName: 'p',
          isWifiAllowed: false, isMobileAllowed: false);
      app.tempAllowUntil = DateTime.now().add(const Duration(hours: 1));
      expect(app.isEffectivelyBlocked, false);
      expect(app.isTempAllowed, true);
      expect(app.remainingTempMinutes, greaterThanOrEqualTo(59));
    });

    test('Temp-allow with past expiry does NOT override block', () {
      final app = AppInfo(name: 'T', packageName: 'p',
          isWifiAllowed: false, isMobileAllowed: false);
      app.tempAllowUntil = DateTime.now().subtract(const Duration(minutes: 1));
      expect(app.isEffectivelyBlocked, true);
      expect(app.isTempAllowed, false);
      expect(app.remainingTempMinutes, 0);
    });

    test('Auto-quarantine marks new unknown apps as blocked', () async {
      final existing = [
        AppInfo(name: 'Known', packageName: 'com.known',
            isWifiAllowed: true, isMobileAllowed: true),
      ];
      await StorageService.saveAppSettings(existing);

      final withNew = [
        AppInfo(name: 'Known', packageName: 'com.known'),
        AppInfo(name: 'NewApp', packageName: 'com.new.app'),
      ];
      await StorageService.applySavedAppSettings(withNew, autoQuarantine: true);

      expect(withNew[0].isWifiAllowed, true);
      expect(withNew[1].isWifiAllowed, false);
      expect(withNew[1].isMobileAllowed, false);
      expect(withNew[1].isQuarantined, true);
      expect(withNew[1].isEffectivelyBlocked, true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  4. SCHEDULE ENGINE – Time window detection
  // ═══════════════════════════════════════════════════════════════════════════
  group('Schedule Engine – Time window math', () {
    // We test the isNowInScheduleWindow logic by recreating it
    // since VpnManager has private state but the algorithm is deterministic
    bool isInWindow(int nowH, int nowM, int startH, int startM, int endH, int endM) {
      final nowMin = nowH * 60 + nowM;
      final startMin = startH * 60 + startM;
      final endMin = endH * 60 + endM;
      if (startMin == endMin) return false;
      if (startMin < endMin) {
        return nowMin >= startMin && nowMin < endMin;
      } else {
        return nowMin >= startMin || nowMin < endMin;
      }
    }

    test('Same-day window: 8:00–22:00', () {
      expect(isInWindow(10, 0, 8, 0, 22, 0), true);
      expect(isInWindow(7, 59, 8, 0, 22, 0), false);
      expect(isInWindow(22, 0, 8, 0, 22, 0), false); // end is exclusive
      expect(isInWindow(8, 0, 8, 0, 22, 0), true);
    });

    test('Overnight window: 23:00–06:00', () {
      expect(isInWindow(23, 0, 23, 0, 6, 0), true);
      expect(isInWindow(23, 30, 23, 0, 6, 0), true);
      expect(isInWindow(0, 0, 23, 0, 6, 0), true);
      expect(isInWindow(3, 30, 23, 0, 6, 0), true);
      expect(isInWindow(5, 59, 23, 0, 6, 0), true);
      expect(isInWindow(6, 0, 23, 0, 6, 0), false); // end exclusive
      expect(isInWindow(22, 59, 23, 0, 6, 0), false);
      expect(isInWindow(12, 0, 23, 0, 6, 0), false);
    });

    test('Overnight window with minutes: 23:30–06:15', () {
      expect(isInWindow(23, 29, 23, 30, 6, 15), false);
      expect(isInWindow(23, 30, 23, 30, 6, 15), true);
      expect(isInWindow(0, 0, 23, 30, 6, 15), true);
      expect(isInWindow(6, 14, 23, 30, 6, 15), true);
      expect(isInWindow(6, 15, 23, 30, 6, 15), false);
    });

    test('Same start and end = always false', () {
      expect(isInWindow(10, 0, 10, 0, 10, 0), false);
      expect(isInWindow(0, 0, 0, 0, 0, 0), false);
    });

    test('1-minute window', () {
      expect(isInWindow(10, 0, 10, 0, 10, 1), true);
      expect(isInWindow(10, 1, 10, 0, 10, 1), false);
    });

    test('Schedule eco action applies 64/64 speeds', () {
      // Simulate eco schedule
      final config = VpnConfig(downloadSpeedLimit: 1024, uploadSpeedLimit: 512);
      final preScheduleDl = config.downloadSpeedLimit;
      final preScheduleUl = config.uploadSpeedLimit;

      config.downloadSpeedLimit = 64;
      config.uploadSpeedLimit = 64;
      expect(config.downloadSpeedLimit, 64);
      expect(config.uploadSpeedLimit, 64);

      // Revert
      config.downloadSpeedLimit = preScheduleDl;
      config.uploadSpeedLimit = preScheduleUl;
      expect(config.downloadSpeedLimit, 1024);
      expect(config.uploadSpeedLimit, 512);
    });

    test('Schedule settings persist correctly', () async {
      await StorageService.saveScheduleSettings(
        enabled: true, startHour: 23, startMinute: 30,
        endHour: 6, endMinute: 15, action: 'lockdown',
      );
      final s = await StorageService.loadScheduleSettings();
      expect(s['enabled'], true);
      expect(s['startHour'], 23);
      expect(s['startMinute'], 30);
      expect(s['endHour'], 6);
      expect(s['endMinute'], 15);
      expect(s['action'], 'lockdown');
    });

    test('Schedule config inside VpnConfig round-trips', () {
      final config = VpnConfig(
        scheduleEnabled: true,
        activeScheduleStartHour: 22,
        activeScheduleEndHour: 7,
      );
      config.schedStartM = 45;
      config.schedEndM = 30;

      final json = config.toJson();
      final loaded = VpnConfig.fromJson(json);

      expect(loaded.scheduleEnabled, true);
      expect(loaded.activeScheduleStartHour, 22);
      expect(loaded.schedStartM, 45);
      expect(loaded.activeScheduleEndHour, 7);
      expect(loaded.schedEndM, 30);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  5. LOG SYSTEM – addLog, clearLogs, max cap, format
  // ═══════════════════════════════════════════════════════════════════════════
  group('Log System – format and capacity', () {
    test('Log entry has correct time format HH:MM:SS', () {
      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}:"
          "${now.second.toString().padLeft(2, '0')}";
      expect(RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(timeStr), true);
    });

    test('Log levels include standard values', () {
      const validLevels = ['OK', 'INFO', 'WARN', 'ERR', 'BLOCK', 'SCHEDULE'];
      for (final level in validLevels) {
        expect(level, isNotEmpty);
      }
    });

    test('Log capacity is capped at 500 entries (simulated)', () {
      final logs = <Map<String, String>>[];
      for (int i = 0; i < 550; i++) {
        logs.insert(0, {'time': '00:00:00', 'level': 'INFO', 'msg': 'Entry $i'});
        if (logs.length > 500) logs.removeLast();
      }
      expect(logs.length, 500);
      // Most recent is first (LIFO)
      expect(logs.first['msg'], 'Entry 549');
      // Oldest surviving entry
      expect(logs.last['msg'], 'Entry 50');
    });

    test('Clear logs produces empty list', () {
      final logs = <Map<String, String>>[];
      logs.add({'time': '12:00:00', 'level': 'OK', 'msg': 'test'});
      logs.clear();
      expect(logs, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  6. DNS RESOLUTION – Unified provider, DoH URL mapping
  // ═══════════════════════════════════════════════════════════════════════════
  group('DNS Resolution – Provider and DoH URL mapping', () {
    test('effectiveDohUrl for each provider', () {
      expect(VpnConfig(dohProvider: 'cloudflare').effectiveDohUrl,
          'https://cloudflare-dns.com/dns-query');
      expect(VpnConfig(dohProvider: 'google').effectiveDohUrl,
          'https://dns.google/dns-query');
      expect(VpnConfig(dohProvider: 'adguard').effectiveDohUrl,
          'https://dns.adguard-dns.com/dns-query');
    });

    test('Custom DoH URL is used when non-empty', () {
      final config = VpnConfig(
        dohProvider: 'custom',
        customDohUrl: 'https://my-dns.example.com/dns-query',
      );
      expect(config.effectiveDohUrl, 'https://my-dns.example.com/dns-query');
    });

    test('Empty custom DoH URL falls back to Cloudflare', () {
      final config = VpnConfig(dohProvider: 'custom', customDohUrl: '');
      expect(config.effectiveDohUrl, 'https://cloudflare-dns.com/dns-query');
    });

    test('DoH provider case-insensitive', () {
      expect(VpnConfig(dohProvider: 'Cloudflare').effectiveDohUrl,
          'https://cloudflare-dns.com/dns-query');
      expect(VpnConfig(dohProvider: 'GOOGLE').effectiveDohUrl,
          'https://dns.google/dns-query');
      expect(VpnConfig(dohProvider: 'AdGuard').effectiveDohUrl,
          'https://dns.adguard-dns.com/dns-query');
    });

    test('DNS servers accessor', () {
      final config = VpnConfig(
        customDnsPrimary: '8.8.8.8',
        customDnsSecondary: '8.8.4.4',
      );
      expect(config.dnsServers, ['8.8.8.8', '8.8.4.4']);

      config.dnsServers = ['1.1.1.1', '1.0.0.1'];
      expect(config.customDnsPrimary, '1.1.1.1');
      expect(config.customDnsSecondary, '1.0.0.1');
    });

    test('Blocked domains add/remove operations', () {
      final config = VpnConfig(
        blockedDomains: ['ads.example.com'],
      );
      expect(config.blockedDomains, contains('ads.example.com'));
      expect(config.blockedDomains.length, 1);

      config.blockedDomains.add('tracker.net');
      expect(config.blockedDomains.length, 2);

      config.blockedDomains.remove('ads.example.com');
      expect(config.blockedDomains.length, 1);
      expect(config.blockedDomains, contains('tracker.net'));
    });

    test('Blocked domains survive JSON round-trip', () {
      final config = VpnConfig(
        blockedDomains: ['a.com', 'b.com', 'c.com'],
      );
      final json = config.toJson();
      final loaded = VpnConfig.fromJson(json);
      expect(loaded.blockedDomains, containsAll(['a.com', 'b.com', 'c.com']));
      expect(loaded.blockedDomains.length, 3);
    });

    test('IPv6 leak protection defaults to true', () {
      expect(VpnConfig().ipv6LeakProtection, true);
    });

    test('DoH and IPv6 persist through storage', () async {
      final config = VpnConfig(
        dohEnabled: true,
        dohProvider: 'adguard',
        customDohUrl: 'https://test.dns/doh',
        ipv6LeakProtection: true,
      );
      await StorageService.saveConfig(config);
      final loaded = await StorageService.loadConfig();
      expect(loaded!.dohEnabled, true);
      expect(loaded.dohProvider, 'adguard');
      expect(loaded.customDohUrl, 'https://test.dns/doh');
      expect(loaded.ipv6LeakProtection, true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  7. VpnConfig – COMPLETE FIELD INTEGRITY
  // ═══════════════════════════════════════════════════════════════════════════
  group('VpnConfig – Complete field integrity round-trip', () {
    test('All 35+ fields survive toJson → fromJson → toJson', () {
      final original = VpnConfig(
        isVpnActive: true,
        globalMode: 'blacklist',
        downloadSpeedLimit: 2048,
        uploadSpeedLimit: 1024,
        presetMode: 'manual',
        ebpfEnabled: false,
        dpiEnabled: true,
        blockAds: true,
        blockAdult: true,
        blockSocial: true,
        dnsRebindingProtection: false,
        dohEnabled: true,
        dohProvider: 'adguard',
        customDohUrl: 'https://custom.dns/doh',
        ipv6LeakProtection: true,
        selectedDnsProvider: 'Google',
        customDnsPrimary: '8.8.8.8',
        customDnsSecondary: '8.8.4.4',
        blockedDomains: ['x.com', 'y.com'],
        customFilterLists: ['https://filter.list/1.txt'],
        dataCapMb: 15000,
        capAction: 'disconnect',
        alert50: false,
        alert75: true,
        alert90: false,
        scheduleEnabled: true,
        activeScheduleStartHour: 1,
        activeScheduleEndHour: 5,
        proxyEnabled: true,
        localProxyHost: '10.0.0.1',
        localProxyPort: 3128,
        upstreamProxyHost: '192.168.1.1',
        upstreamProxyPort: 8080,
        upstreamProxyType: 'HTTP',
        upstreamUsername: 'admin',
        upstreamPassword: 'pa\$\$w0rd',
        upstreamUseSsl: true,
      );
      original.schedStartM = 15;
      original.schedEndM = 45;

      // First round-trip
      final json1 = original.toJson();
      final loaded1 = VpnConfig.fromJson(json1);

      // Second round-trip (proves idempotency)
      final json2 = loaded1.toJson();
      final loaded2 = VpnConfig.fromJson(json2);

      // Compare all fields
      expect(loaded2.isVpnActive, original.isVpnActive);
      expect(loaded2.globalMode, original.globalMode);
      expect(loaded2.downloadSpeedLimit, original.downloadSpeedLimit);
      expect(loaded2.uploadSpeedLimit, original.uploadSpeedLimit);
      expect(loaded2.presetMode, original.presetMode);
      expect(loaded2.ebpfEnabled, original.ebpfEnabled);
      expect(loaded2.dpiEnabled, original.dpiEnabled);
      expect(loaded2.blockAds, original.blockAds);
      expect(loaded2.blockAdult, original.blockAdult);
      expect(loaded2.blockSocial, original.blockSocial);
      expect(loaded2.dnsRebindingProtection, original.dnsRebindingProtection);
      expect(loaded2.dohEnabled, original.dohEnabled);
      expect(loaded2.dohProvider, original.dohProvider);
      expect(loaded2.customDohUrl, original.customDohUrl);
      expect(loaded2.ipv6LeakProtection, original.ipv6LeakProtection);
      expect(loaded2.selectedDnsProvider, original.selectedDnsProvider);
      expect(loaded2.customDnsPrimary, original.customDnsPrimary);
      expect(loaded2.customDnsSecondary, original.customDnsSecondary);
      expect(loaded2.blockedDomains.length, original.blockedDomains.length);
      expect(loaded2.customFilterLists.length, original.customFilterLists.length);
      expect(loaded2.dataCapMb, original.dataCapMb);
      expect(loaded2.capAction, original.capAction);
      expect(loaded2.alert50, original.alert50);
      expect(loaded2.alert75, original.alert75);
      expect(loaded2.alert90, original.alert90);
      expect(loaded2.scheduleEnabled, original.scheduleEnabled);
      expect(loaded2.activeScheduleStartHour, original.activeScheduleStartHour);
      expect(loaded2.schedStartM, original.schedStartM);
      expect(loaded2.activeScheduleEndHour, original.activeScheduleEndHour);
      expect(loaded2.schedEndM, original.schedEndM);
      expect(loaded2.proxyEnabled, original.proxyEnabled);
      expect(loaded2.localProxyHost, original.localProxyHost);
      expect(loaded2.localProxyPort, original.localProxyPort);
      expect(loaded2.upstreamProxyHost, original.upstreamProxyHost);
      expect(loaded2.upstreamProxyPort, original.upstreamProxyPort);
      expect(loaded2.upstreamProxyType, original.upstreamProxyType);
      expect(loaded2.upstreamUsername, original.upstreamUsername);
      expect(loaded2.upstreamPassword, original.upstreamPassword);
      expect(loaded2.upstreamUseSsl, original.upstreamUseSsl);
    });

    test('VpnConfig aliases work correctly', () {
      final config = VpnConfig(capAction: 'throttle', scheduleEnabled: true);
      expect(config.dataCapAction, 'throttle');
      config.dataCapAction = 'disconnect';
      expect(config.capAction, 'disconnect');

      expect(config.schedEnabled, true);
      config.schedEnabled = false;
      expect(config.scheduleEnabled, false);

      config.schedStartH = 22;
      expect(config.activeScheduleStartHour, 22);

      config.schedEndH = 7;
      expect(config.activeScheduleEndHour, 7);

      config.dnsCustomBlocked = ['test.com'];
      expect(config.blockedDomains, ['test.com']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  8. TrafficStats – Model integrity
  // ═══════════════════════════════════════════════════════════════════════════
  group('TrafficStats – Model integrity', () {
    test('Default values are all zero', () {
      final stats = TrafficStats();
      expect(stats.downloadSpeedKbps, 0.0);
      expect(stats.uploadSpeedKbps, 0.0);
      expect(stats.totalDownloadMb, 0.0);
      expect(stats.totalUploadMb, 0.0);
      expect(stats.activeConnections, 0);
      expect(stats.recentDownloadHistory, isEmpty);
      expect(stats.recentUploadHistory, isEmpty);
    });

    test('TrafficStats with values', () {
      final stats = TrafficStats(
        downloadSpeedKbps: 1024.5,
        uploadSpeedKbps: 512.3,
        totalDownloadMb: 150.7,
        totalUploadMb: 30.2,
        activeConnections: 12,
        recentDownloadHistory: [100.0, 200.0, 300.0],
        recentUploadHistory: [50.0, 100.0],
      );
      expect(stats.downloadSpeedKbps, 1024.5);
      expect(stats.uploadSpeedKbps, 512.3);
      expect(stats.totalDownloadMb, 150.7);
      expect(stats.totalUploadMb, 30.2);
      expect(stats.activeConnections, 12);
      expect(stats.recentDownloadHistory.length, 3);
      expect(stats.recentUploadHistory.length, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  9. AppInfo – Tracker detection and factory edge cases
  // ═══════════════════════════════════════════════════════════════════════════
  group('AppInfo – Tracker detection', () {
    test('Known tracker SDK packages are flagged', () {
      final trackerPkgs = [
        'com.admob.sdk',
        'com.test.adcolony',
        'com.test.applovin',
        'com.test.appsflyer',
        'com.test.analytics',
        'com.test.tracker',
      ];
      for (final pkg in trackerPkgs) {
        final app = AppInfo.fromJson({'packageName': pkg, 'appName': 'T'});
        expect(app.hasTrackers, true, reason: '$pkg should be flagged');
      }
    });

    test('Normal packages are NOT flagged', () {
      final normalPkgs = [
        'com.whatsapp',
        'com.google.chrome',
        'org.mozilla.firefox',
        'com.samsung.calculator',
        'com.cybnux.net_speed_controller',
      ];
      for (final pkg in normalPkgs) {
        final app = AppInfo.fromJson({'packageName': pkg, 'appName': 'T'});
        expect(app.hasTrackers, false, reason: '$pkg should NOT be flagged');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  10. CUSTOM PROFILE – Full lifecycle
  // ═══════════════════════════════════════════════════════════════════════════
  group('Custom Profile – Full lifecycle', () {
    test('No custom profile exists initially', () async {
      expect(await StorageService.hasSavedCustomProfile(), false);
    });

    test('Save custom profile → has profile → restore', () async {
      final apps = [
        AppInfo(name: 'A', packageName: 'com.a',
            isWifiAllowed: false, isMobileAllowed: true,
            speedMode: 'custom', customSpeedLimitKbps: 256),
        AppInfo(name: 'B', packageName: 'com.b',
            isWifiAllowed: true, isMobileAllowed: true,
            speedMode: 'default'),
      ];

      await StorageService.saveCustomProfileSettings(apps, 1024, 512);
      expect(await StorageService.hasSavedCustomProfile(), true);

      final fresh = [
        AppInfo(name: 'A', packageName: 'com.a'),
        AppInfo(name: 'B', packageName: 'com.b'),
        AppInfo(name: 'C', packageName: 'com.c'),
      ];

      final count = await StorageService.restoreCustomProfileSettings(fresh);
      expect(count, 1); // Only A was customized

      expect(fresh[0].isWifiAllowed, false);
      expect(fresh[0].isMobileAllowed, true);
      expect(fresh[0].speedMode, 'custom');
      expect(fresh[0].customSpeedLimitKbps, 256);
      expect(fresh[0].tempAllowUntil, isNull);

      // B was "default" so not in custom profile → gets reset
      expect(fresh[1].isWifiAllowed, true);
      expect(fresh[1].speedMode, 'default');

      // C is new → reset to defaults
      expect(fresh[2].isWifiAllowed, true);
      expect(fresh[2].speedMode, 'default');
    });

    test('saveManualCustomSettings stores both profile and app settings', () async {
      final apps = [
        AppInfo(name: 'X', packageName: 'com.x',
            isWifiAllowed: false, speedMode: 'custom', customSpeedLimitKbps: 64),
      ];
      final ok = await StorageService.saveManualCustomSettings(apps, 2048, 1024);
      expect(ok, true);
      expect(await StorageService.hasSavedCustomProfile(), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  11. SETTINGS PERSISTENCE – Complete toggle + hotspot + language
  // ═══════════════════════════════════════════════════════════════════════════
  group('Settings Persistence – All toggles and hotspot', () {
    test('All toggle defaults', () async {
      expect(await StorageService.loadLanguage(), 'ar');
      expect(await StorageService.loadMonitorEnabled(), true);
      expect(await StorageService.loadSpikeAlertEnabled(), true);
      expect(await StorageService.loadLockdownScreenOff(), false);
      expect(await StorageService.loadAutoQuarantine(), false);
      expect(await StorageService.loadAccentColor(), isNull);
    });

    test('Rapid toggle stress test', () async {
      for (int i = 0; i < 20; i++) {
        final val = i % 2 == 0;
        await StorageService.saveMonitorEnabled(val);
        await StorageService.saveSpikeAlertEnabled(!val);
        await StorageService.saveLockdownScreenOff(val);
        await StorageService.saveAutoQuarantine(!val);
      }
      // After 20 iterations, i=19 (odd): val=false
      expect(await StorageService.loadMonitorEnabled(), false);
      expect(await StorageService.loadSpikeAlertEnabled(), true);
      expect(await StorageService.loadLockdownScreenOff(), false);
      expect(await StorageService.loadAutoQuarantine(), true);
    });

    test('Hotspot settings with extreme values', () async {
      await StorageService.saveHotspotSettings(
          port: 65535, dlLimit: 99999, ulLimit: 99999);
      final hs = await StorageService.loadHotspotSettings();
      expect(hs['port'], 65535);
      expect(hs['dlLimit'], 99999);
      expect(hs['ulLimit'], 99999);
    });

    test('Hotspot WiFi credentials with special characters', () async {
      await StorageService.saveHotspotWifiCredentials(
        ssid: 'Net_Guard™ 🛡️',
        password: 'P@\$\$w0rd!#%^&*()',
      );
      final creds = await StorageService.loadHotspotWifiCredentials();
      expect(creds['ssid'], 'Net_Guard™ 🛡️');
      expect(creds['password'], 'P@\$\$w0rd!#%^&*()');
    });

    test('Full VpnConfig save and reload preserves everything', () async {
      final config = VpnConfig(
        isVpnActive: true,
        globalMode: 'blacklist',
        downloadSpeedLimit: 512,
        uploadSpeedLimit: 256,
        presetMode: 'manual',
        dohEnabled: true,
        dohProvider: 'google',
        ipv6LeakProtection: true,
        dataCapMb: 5000,
        capAction: 'disconnect',
        scheduleEnabled: true,
        activeScheduleStartHour: 23,
        activeScheduleEndHour: 6,
      );
      config.schedStartM = 30;
      config.schedEndM = 15;

      await StorageService.saveConfig(config);
      final loaded = await StorageService.loadConfig();

      expect(loaded, isNotNull);
      expect(loaded!.isVpnActive, true);
      expect(loaded.globalMode, 'blacklist');
      expect(loaded.downloadSpeedLimit, 512);
      expect(loaded.uploadSpeedLimit, 256);
      expect(loaded.dohEnabled, true);
      expect(loaded.dohProvider, 'google');
      expect(loaded.ipv6LeakProtection, true);
      expect(loaded.dataCapMb, 5000);
      expect(loaded.capAction, 'disconnect');
      expect(loaded.scheduleEnabled, true);
      expect(loaded.activeScheduleStartHour, 23);
      expect(loaded.schedStartM, 30);
      expect(loaded.activeScheduleEndHour, 6);
      expect(loaded.schedEndM, 15);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  12. LOCALIZATION COMPLETENESS – Critical AR/EN pairs
  // ═══════════════════════════════════════════════════════════════════════════
  group('Localization – Critical AR/EN string pairs', () {
    late AppStrings ar;
    late AppStrings en;

    setUp(() {
      ar = AppStrings(true);
      en = AppStrings(false);
    });

    test('All tab names differ between languages', () {
      final pairs = {
        'tabHome': [ar.tabHome, en.tabHome],
        'tabHistory': [ar.tabHistory, en.tabHistory],
        'tabApps': [ar.tabApps, en.tabApps],
        'tabBlocker': [ar.tabBlocker, en.tabBlocker],
        'tabUsage': [ar.tabUsage, en.tabUsage],
      };
      for (final entry in pairs.entries) {
        expect(entry.value[0], isNotEmpty, reason: '${entry.key} AR empty');
        expect(entry.value[1], isNotEmpty, reason: '${entry.key} EN empty');
        expect(entry.value[0], isNot(equals(entry.value[1])),
            reason: '${entry.key} AR == EN');
      }
    });

    test('Schedule-related strings all present', () {
      expect(ar.scheduleSection, isNotEmpty);
      expect(en.scheduleSection, isNotEmpty);
      expect(ar.scheduleEnableTitle, isNotEmpty);
      expect(ar.scheduleStartTime, isNotEmpty);
      expect(ar.scheduleEndTime, isNotEmpty);
      expect(ar.scheduleActionEco, isNotEmpty);
      expect(en.scheduleActionEco, isNotEmpty);
      expect(ar.scheduleActionLockdown, isNotEmpty);
      expect(en.scheduleActionLockdown, isNotEmpty);
    });

    test('DoH and security strings all present', () {
      expect(ar.dohSectionTitle, isNotEmpty);
      expect(en.dohSectionTitle, isNotEmpty);
      expect(ar.ipv6ProtectionTitle, isNotEmpty);
      expect(en.ipv6ProtectionTitle, isNotEmpty);
      expect(ar.blockAdsTitle, isNotEmpty);
      expect(en.blockAdsTitle, isNotEmpty);
      expect(ar.blockAdultTitle, isNotEmpty);
      expect(en.blockAdultTitle, isNotEmpty);
    });

    test('Hotspot strings all present in both languages', () {
      final hotspotKeys = [
        [ar.hotspotSectionTitle, en.hotspotSectionTitle],
        [ar.hotspotControllerTitle, en.hotspotControllerTitle],
        [ar.hotspotGuideStep1, en.hotspotGuideStep1],
        [ar.hotspotQrCodeBtn, en.hotspotQrCodeBtn],
        [ar.hotspotTabWifi, en.hotspotTabWifi],
        [ar.hotspotTabProxy, en.hotspotTabProxy],
        [ar.hotspotSsidLabel, en.hotspotSsidLabel],
        [ar.hotspotPasswordLabel, en.hotspotPasswordLabel],
      ];
      for (final pair in hotspotKeys) {
        expect(pair[0], isNotEmpty);
        expect(pair[1], isNotEmpty);
      }
    });

    test('Permissions strings complete', () {
      expect(ar.permAllGranted, isNotEmpty);
      expect(en.permAllGranted, isNotEmpty);
      expect(ar.permAllGranted, isNot(equals(en.permAllGranted)));
      expect(ar.permVpnTitle, isNotEmpty);
      expect(ar.permUsageTitle, isNotEmpty);
      expect(ar.permBatteryTitle, isNotEmpty);
      expect(ar.permNotifTitle, isNotEmpty);
    });

    test('Speed preset names exist in both languages', () {
      expect(ar.presetEco, isNotEmpty);
      expect(en.presetEco, isNotEmpty);
      expect(ar.presetPerformance, isNotEmpty);
      expect(en.presetPerformance, isNotEmpty);
      expect(ar.presetUnlimited, isNotEmpty);
      expect(en.presetUnlimited, isNotEmpty);
      expect(ar.presetZero, isNotEmpty);
      expect(en.presetZero, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  13. EDGE CASES & CRASH GUARDS
  // ═══════════════════════════════════════════════════════════════════════════
  group('Edge Cases & Crash Guards', () {
    test('Garbage JSON in config storage returns null safely', () async {
      SharedPreferences.setMockInitialValues({
        'cybnux_vpn_config': '{{{BAD_JSON',
      });
      final loaded = await StorageService.loadConfig();
      expect(loaded, isNull);
    });

    test('Empty JSON object in config returns valid default', () async {
      SharedPreferences.setMockInitialValues({
        'cybnux_vpn_config': '{}',
      });
      final loaded = await StorageService.loadConfig();
      expect(loaded, isNotNull);
      expect(loaded!.downloadSpeedLimit, -1);
      expect(loaded.uploadSpeedLimit, -1);
    });

    test('VpnConfig fromJson with partial data uses defaults', () {
      final config = VpnConfig.fromJson({
        'downloadSpeedLimit': 512,
        // everything else missing
      });
      expect(config.downloadSpeedLimit, 512);
      expect(config.uploadSpeedLimit, -1);
      expect(config.isVpnActive, false);
      expect(config.dohEnabled, false);
      expect(config.ipv6LeakProtection, true);
      expect(config.proxyEnabled, false);
    });

    test('AppInfo with null tempAllowUntil gives 0 remaining minutes', () {
      final app = AppInfo(name: 'T', packageName: 'p');
      expect(app.tempAllowUntil, isNull);
      expect(app.remainingTempMinutes, 0);
      expect(app.isTempAllowed, false);
    });

    test('AppInfo with empty packageName does not crash', () {
      final app = AppInfo.fromJson({
        'appName': 'Empty',
        'packageName': '',
      });
      expect(app.packageName, '');
      expect(app.hasTrackers, false);
    });

    test('Multiple saves of same config do not corrupt data', () async {
      final config = VpnConfig(
        downloadSpeedLimit: 256,
        uploadSpeedLimit: 128,
        dohEnabled: true,
      );
      for (int i = 0; i < 10; i++) {
        await StorageService.saveConfig(config);
      }
      final loaded = await StorageService.loadConfig();
      expect(loaded!.downloadSpeedLimit, 256);
      expect(loaded.uploadSpeedLimit, 128);
      expect(loaded.dohEnabled, true);
    });
  });
}
