import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MethodChannelService {
  static const MethodChannel _channel =
      MethodChannel('com.cybnux.netspeed/controller');

  static Future<bool> startVpn({
    int downloadLimit = 0,
    int uploadLimit = 0,
    List<String> allowedApps = const [],
    List<String> blockedWifiApps = const [],
    List<String> blockedDataApps = const [],
    bool blockAllFirewall = false,
    List<String> allowedFirewallApps = const [],
    bool dnsAdBlock = false,
    bool dnsAdultBlock = false,
    bool dnsSocialBlock = false,
    List<String> dnsCustomBlocked = const [],
    List<String> dnsServers = const [],
    int dataCapBytes = 0,
    String dataCapAction = 'throttle',
    bool schedEnabled = false,
    int schedStartH = 0,
    int schedStartM = 0,
    int schedEndH = 0,
    int schedEndM = 0,
    String appSpeedConfigs = '',
    bool lockdownScreenOff = false,
    bool ebpfEnabled = true,
    bool dpiEnabled = true,
    bool dnsRebindingProtection = true,
  }) async {
    try {
      final bool success = await _channel.invokeMethod('startVpn', {
        'downloadLimit': downloadLimit,
        'uploadLimit': uploadLimit,
        'allowedApps': allowedApps,
        'blockedWifiApps': blockedWifiApps,
        'blockedDataApps': blockedDataApps,
        'blockAllFirewall': blockAllFirewall,
        'allowedFirewallApps': allowedFirewallApps,
        'dnsAdBlock': dnsAdBlock,
        'dnsAdultBlock': dnsAdultBlock,
        'dnsSocialBlock': dnsSocialBlock,
        'dnsCustomBlocked': dnsCustomBlocked,
        'dnsServers': dnsServers,
        'dataCapBytes': dataCapBytes,
        'dataCapAction': dataCapAction,
        'schedEnabled': schedEnabled,
        'schedStartH': schedStartH,
        'schedStartM': schedStartM,
        'schedEndH': schedEndH,
        'schedEndM': schedEndM,
        'appSpeedConfigs': appSpeedConfigs,
        'lockdownScreenOff': lockdownScreenOff,
        'ebpfEnabled': ebpfEnabled,
        'dpiEnabled': dpiEnabled,
        'dnsRebindingProtection': dnsRebindingProtection,
      });
      return success;
    } on PlatformException catch (e) {
      debugPrint("VPN start failed: '${e.message}'.");
      return false;
    } catch (e) {
      debugPrint("VPN start failed: '$e'.");
      return false;
    }
  }

  static Future<bool> stopVpn() async {
    try {
      final bool success = await _channel.invokeMethod('stopVpn');
      return success;
    } on PlatformException catch (e) {
      debugPrint("VPN stop failed: '${e.message}'.");
      return false;
    } catch (e) {
      debugPrint("VPN stop failed: '$e'.");
      return false;
    }
  }

  static Future<bool> isVpnRunning() async {
    try {
      final bool running = await _channel.invokeMethod('isVpnRunning');
      return running;
    } on PlatformException {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getRealTrafficStats() async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('getStats');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
      return {};
    } on PlatformException {
      return {};
    }
  }

  static Future<Map<String, double>> getPerAppTraffic() async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('getPerAppTraffic');
      if (res != null) {
        return res.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {};
    } on PlatformException {
      return {};
    }
  }

  static Future<Map<String, dynamic>> getRealPeriodData(String period) async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('getRealPeriodData', {'period': period});
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
      return {};
    } on PlatformException {
      return {};
    }
  }

  static Future<List<dynamic>> getInstalledApps() async {
    try {
      final List<dynamic>? res =
          await _channel.invokeMethod('getInstalledApps');
      return res ?? [];
    } on PlatformException {
      return [];
    }
  }

  static Future<List<dynamic>> getNativeEventLogs() async {
    try {
      final List<dynamic>? res =
          await _channel.invokeMethod('getNativeEventLogs');
      return res ?? [];
    } on PlatformException {
      return [];
    }
  }

  static Future<void> updateSettings({
    int downloadLimit = 0,
    int uploadLimit = 0,
    List<String> allowedApps = const [],
    List<String> blockedWifiApps = const [],
    List<String> blockedDataApps = const [],
    bool blockAllFirewall = false,
    List<String> allowedFirewallApps = const [],
    bool dnsAdBlock = false,
    bool dnsAdultBlock = false,
    bool dnsSocialBlock = false,
    List<String> dnsCustomBlocked = const [],
    List<String> dnsServers = const [],
    int dataCapBytes = 0,
    String dataCapAction = 'throttle',
    bool schedEnabled = false,
    int schedStartH = 0,
    int schedStartM = 0,
    int schedEndH = 0,
    int schedEndM = 0,
    String appSpeedConfigs = '',
    bool lockdownScreenOff = false,
    bool ebpfEnabled = true,
    bool dpiEnabled = true,
    bool dnsRebindingProtection = true,
  }) async {
    try {
      await _channel.invokeMethod('updateSettings', {
        'downloadLimit': downloadLimit,
        'uploadLimit': uploadLimit,
        'allowedApps': allowedApps,
        'blockedWifiApps': blockedWifiApps,
        'blockedDataApps': blockedDataApps,
        'blockAllFirewall': blockAllFirewall,
        'allowedFirewallApps': allowedFirewallApps,
        'dnsAdBlock': dnsAdBlock,
        'dnsAdultBlock': dnsAdultBlock,
        'dnsSocialBlock': dnsSocialBlock,
        'dnsCustomBlocked': dnsCustomBlocked,
        'dnsServers': dnsServers,
        'dataCapBytes': dataCapBytes,
        'dataCapAction': dataCapAction,
        'schedEnabled': schedEnabled,
        'schedStartH': schedStartH,
        'schedStartM': schedStartM,
        'schedEndH': schedEndH,
        'schedEndM': schedEndM,
        'appSpeedConfigs': appSpeedConfigs,
        'lockdownScreenOff': lockdownScreenOff,
        'ebpfEnabled': ebpfEnabled,
        'dpiEnabled': dpiEnabled,
        'dnsRebindingProtection': dnsRebindingProtection,
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to update settings: '${e.message}'.");
    }
  }

  static Future<Map<String, bool>> checkPermissionsStatus() async {
    try {
      final res = await _channel.invokeMethod('checkPermissionsStatus');
      if (res is Map) {
        return res.map((k, v) => MapEntry(k.toString(), v == true));
      }
    } catch (_) {}
    return {
      'usageStats': false,
      'batteryOptimization': false,
      'notification': false,
      'vpn': false,
    };
  }

  static Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } catch (_) {}
  }

  static Future<void> requestBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimization');
    } catch (_) {}
  }

  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  static Future<void> setAutoQuarantine(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoQuarantine', {'enabled': enabled});
    } catch (_) {}
  }

  static Function(bool isRunning)? onVpnStateChanged;
  static Function()? onVpnToggledFromNotification;

  static void initializeChannelCallbacks() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVpnStateChanged') {
        final bool isRunning = call.arguments == true;
        onVpnStateChanged?.call(isRunning);
      } else if (call.method == 'onToggleVpnFromNotification') {
        final isRunning = await isVpnRunning();
        onVpnStateChanged?.call(isRunning);
      }
    });
  }

  static Future<bool> startMonitorService() async {
    try {
      final res = await _channel.invokeMethod('startMonitorService');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopMonitorService() async {
    try {
      final res = await _channel.invokeMethod('stopMonitorService');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isMonitorRunning() async {
    try {
      final res = await _channel.invokeMethod('isMonitorRunning');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getMonitorLiveStats() async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('getMonitorLiveStats');
      if (res != null) return Map<String, dynamic>.from(res);
    } catch (_) {}
    return {};
  }

  static Future<void> setSpikeAlertEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSpikeAlertEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<bool> isSpikeAlertEnabled() async {
    try {
      final res = await _channel.invokeMethod('isSpikeAlertEnabled');
      return res == true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setAppLanguage(String language) async {
    try {
      await _channel.invokeMethod('setAppLanguage', {'language': language});
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getPerAppTrafficByNetwork({
    String session = 'today',
    int? startTime,
    int? endTime,
  }) async {
    try {
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod(
        'getPerAppTrafficByNetwork',
        {
          'session': session,
          'startTime': startTime,
          'endTime': endTime,
        },
      );
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {};
  }

  // ── Hotspot Proxy Server ──
  static Future<bool> startHotspotProxy({
    int port = 8282,
    int downloadLimit = -1,
    int uploadLimit = -1,
  }) async {
    try {
      final res = await _channel.invokeMethod('startHotspotProxy', {
        'port': port,
        'downloadLimit': downloadLimit,
        'uploadLimit': uploadLimit,
      });
      return res == true;
    } catch (e) {
      debugPrint('Error starting hotspot proxy: $e');
      return false;
    }
  }

  static Future<bool> stopHotspotProxy() async {
    try {
      final res = await _channel.invokeMethod('stopHotspotProxy');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> updateHotspotRates({
    required int downloadLimit,
    required int uploadLimit,
  }) async {
    try {
      await _channel.invokeMethod('updateHotspotRates', {
        'downloadLimit': downloadLimit,
        'uploadLimit': uploadLimit,
      });
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getHotspotProxyStatus() async {
    try {
      final Map<dynamic, dynamic>? res =
          await _channel.invokeMethod('getHotspotProxyStatus');
      if (res != null) return Map<String, dynamic>.from(res);
    } catch (_) {}
    return {};
  }

  static Future<String> getHotspotIp() async {
    try {
      final String? ip = await _channel.invokeMethod('getHotspotIp');
      return ip ?? '192.168.43.1';
    } catch (_) {
      return '192.168.43.1';
    }
  }

  static Future<String> getDeviceHotspotName() async {
    try {
      final String? name = await _channel.invokeMethod('getDeviceHotspotName');
      return (name != null && name.trim().isNotEmpty) ? name.trim() : 'NetGuard Hotspot';
    } catch (_) {
      return 'NetGuard Hotspot';
    }
  }
}

