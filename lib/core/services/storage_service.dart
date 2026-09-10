import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';
import '../models/app_info.dart';

class StorageService {
  static const String _keyConfig = 'cybnux_vpn_config';
  static const String _keyAppSettings = 'cybnux_app_settings';
  static const String _keyCustomProfileAppSettings = 'cybnux_custom_profile_app_settings';
  static const String _keyCustomDownloadLimit = 'cybnux_custom_dl_limit';
  static const String _keyCustomUploadLimit = 'cybnux_custom_ul_limit';
  static const String _keyLastManualDl = 'cybnux_last_manual_dl';
  static const String _keyLastManualUl = 'cybnux_last_manual_ul';
  static const String _keyMonitorEnabled = 'cybnux_monitor_enabled';
  static const String _keySpikeAlert = 'cybnux_spike_alert';
  static const String _keyLockdownScreenOff = 'cybnux_lockdown_screen_off';
  static const String _keyAutoQuarantine = 'cybnux_auto_quarantine';

  static Future<void> saveMonitorEnabled(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyMonitorEnabled, val);
    } catch (_) {}
  }

  static Future<bool> loadMonitorEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyMonitorEnabled) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveSpikeAlertEnabled(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySpikeAlert, val);
    } catch (_) {}
  }

  static Future<bool> loadSpikeAlertEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keySpikeAlert) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveLockdownScreenOff(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLockdownScreenOff, val);
    } catch (_) {}
  }

  static Future<bool> loadLockdownScreenOff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyLockdownScreenOff) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveAutoQuarantine(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoQuarantine, val);
    } catch (_) {}
  }

  static Future<bool> loadAutoQuarantine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAutoQuarantine) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveManualLimits(int dl, int ul) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastManualDl, dl);
      await prefs.setInt(_keyLastManualUl, ul);
    } catch (_) {}
  }

  static Future<Map<String, int>> loadManualLimits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dl = prefs.getInt(_keyLastManualDl) ?? -1;
      final ul = prefs.getInt(_keyLastManualUl) ?? -1;
      return {'dl': dl, 'ul': ul};
    } catch (_) {
      return {'dl': -1, 'ul': -1};
    }
  }

  static Future<void> saveConfig(VpnConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(config.toJson());
      await prefs.setString(_keyConfig, jsonStr);
    } catch (e) {
      debugPrint('[StorageService] saveConfig error: $e');
    }
  }

  static Future<VpnConfig?> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyConfig);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> map = json.decode(jsonStr);
        return VpnConfig.fromJson(map);
      }
    } catch (e) {
      debugPrint('[StorageService] loadConfig error: $e');
    }
    return null;
  }

  static Future<void> saveAppSettings(List<AppInfo> apps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> appData = {};
      for (var app in apps) {
        appData[app.packageName] = {
          'wifi': app.isWifiAllowed,
          'mobile': app.isMobileAllowed,
          'speedMode': app.speedMode,
          'customSpeed': app.customSpeedLimitKbps,
          'isQuarantined': app.isQuarantined,
          'tempUntil': app.tempAllowUntil?.toIso8601String(),
        };
      }
      await prefs.setString(_keyAppSettings, json.encode(appData));
    } catch (e) {
      debugPrint('[StorageService] saveAppSettings error: $e');
    }
  }

  static Future<void> applySavedAppSettings(List<AppInfo> apps, {bool autoQuarantine = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyAppSettings);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final Map<String, dynamic> appData = json.decode(jsonStr);
        final now = DateTime.now();
        for (var app in apps) {
          if (appData.containsKey(app.packageName)) {
            final data = appData[app.packageName] as Map<String, dynamic>;
            app.speedMode = data['speedMode'] ?? 'default';
            app.customSpeedLimitKbps = data['customSpeed'] ?? 0;
            app.isQuarantined = data['isQuarantined'] ?? false;
            
            final tempUntilStr = data['tempUntil'];
            if (tempUntilStr != null) {
              final parsed = DateTime.tryParse(tempUntilStr);
              if (parsed != null && parsed.isAfter(now)) {
                app.tempAllowUntil = parsed;
                app.isWifiAllowed = true;
                app.isMobileAllowed = true;
              } else {
                app.tempAllowUntil = null;
                app.isWifiAllowed = false;
                app.isMobileAllowed = false;
              }
            } else {
              app.tempAllowUntil = null;
              app.isWifiAllowed = data['wifi'] ?? true;
              app.isMobileAllowed = data['mobile'] ?? true;
            }
          } else if (autoQuarantine) {
            app.isWifiAllowed = false;
            app.isMobileAllowed = false;
            app.isQuarantined = true;
            app.tempAllowUntil = null;
          }
        }
      }
    } catch (e) {
      debugPrint('[StorageService] applySavedAppSettings error: $e');
    }
  }

  static Future<void> saveCustomProfileSettings(
      List<AppInfo> apps, int dlLimit, int ulLimit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> appData = {};
      for (var app in apps) {
        final isCustomized = !app.isWifiAllowed ||
            !app.isMobileAllowed ||
            app.speedMode != 'default' ||
            app.customSpeedLimitKbps > 0;
        if (isCustomized) {
          appData[app.packageName] = {
            'wifi': app.isWifiAllowed,
            'mobile': app.isMobileAllowed,
            'speedMode': app.speedMode,
            'customSpeed': app.customSpeedLimitKbps,
          };
        }
      }
      await prefs.setString(_keyCustomProfileAppSettings, json.encode(appData));
      await prefs.setInt(_keyCustomDownloadLimit, dlLimit);
      await prefs.setInt(_keyCustomUploadLimit, ulLimit);
      await prefs.setBool('cybnux_has_custom_profile', true);
    } catch (e) {
      debugPrint('[StorageService] saveCustomProfileSettings error: $e');
    }
  }

  static Future<bool> hasSavedCustomProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('cybnux_has_custom_profile') ??
          (prefs.containsKey(_keyCustomProfileAppSettings) &&
              (prefs.getString(_keyCustomProfileAppSettings)?.isNotEmpty ?? false));
    } catch (_) {
      return false;
    }
  }

  static Future<bool> saveManualCustomSettings(
      List<AppInfo> apps, int dlLimit, int ulLimit) async {
    await saveCustomProfileSettings(apps, dlLimit, ulLimit);
    await saveAppSettings(apps);
    return true;
  }

  static Future<int> restoreCustomProfileSettings(List<AppInfo> apps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyCustomProfileAppSettings);
      if (jsonStr != null) {
        final Map<String, dynamic> appData =
            jsonStr.isNotEmpty ? json.decode(jsonStr) : {};
        int modifiedCount = 0;
        for (var app in apps) {
          if (appData.containsKey(app.packageName)) {
            final data = appData[app.packageName] as Map<String, dynamic>;
            app.isWifiAllowed = data['wifi'] ?? true;
            app.isMobileAllowed = data['mobile'] ?? true;
            app.speedMode = data['speedMode'] ?? 'default';
            app.customSpeedLimitKbps = data['customSpeed'] ?? 0;
            app.tempAllowUntil = null;
            modifiedCount++;
          } else {
            app.isWifiAllowed = true;
            app.isMobileAllowed = true;
            app.speedMode = 'default';
            app.customSpeedLimitKbps = 0;
            app.tempAllowUntil = null;
          }
        }
        await saveAppSettings(apps);
        return modifiedCount;
      }
    } catch (e) {
      debugPrint('[StorageService] restoreCustomProfileSettings error: $e');
    }
    return -1;
  }

  static const String _keyLanguage = 'cybnux_app_language';
  static const String _keyAccentColor = 'cybnux_accent_color';

  static Future<void> saveLanguage(String langCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, langCode);
    } catch (_) {}
  }

  static Future<String> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLanguage) ?? 'ar';
    } catch (_) {
      return 'ar';
    }
  }

  static Future<void> saveAccentColor(int colorVal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyAccentColor, colorVal);
    } catch (_) {}
  }

  static Future<int?> loadAccentColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyAccentColor);
    } catch (_) {
      return null;
    }
  }

  static const String _keyHotspotPort = 'cybnux_hotspot_port';
  static const String _keyHotspotDlLimit = 'cybnux_hotspot_dl_limit';
  static const String _keyHotspotUlLimit = 'cybnux_hotspot_ul_limit';

  static Future<void> saveHotspotSettings({
    required int port,
    required int dlLimit,
    required int ulLimit,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyHotspotPort, port);
      await prefs.setInt(_keyHotspotDlLimit, dlLimit);
      await prefs.setInt(_keyHotspotUlLimit, ulLimit);
    } catch (_) {}
  }

  static Future<Map<String, int>> loadHotspotSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'port': prefs.getInt(_keyHotspotPort) ?? 8282,
        'dlLimit': prefs.getInt(_keyHotspotDlLimit) ?? -1,
        'ulLimit': prefs.getInt(_keyHotspotUlLimit) ?? -1,
      };
    } catch (_) {
      return {'port': 8282, 'dlLimit': -1, 'ulLimit': -1};
    }
  }

  static const String _keyScheduleEnabled = 'cybnux_schedule_enabled';
  static const String _keyScheduleStartH = 'cybnux_schedule_start_h';
  static const String _keyScheduleStartM = 'cybnux_schedule_start_m';
  static const String _keyScheduleEndH = 'cybnux_schedule_end_h';
  static const String _keyScheduleEndM = 'cybnux_schedule_end_m';
  static const String _keyScheduleAction = 'cybnux_schedule_action';

  static Future<void> saveScheduleSettings({
    required bool enabled,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required String action,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyScheduleEnabled, enabled);
      await prefs.setInt(_keyScheduleStartH, startHour);
      await prefs.setInt(_keyScheduleStartM, startMinute);
      await prefs.setInt(_keyScheduleEndH, endHour);
      await prefs.setInt(_keyScheduleEndM, endMinute);
      await prefs.setString(_keyScheduleAction, action);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> loadScheduleSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'enabled': prefs.getBool(_keyScheduleEnabled) ?? false,
        'startHour': prefs.getInt(_keyScheduleStartH) ?? 0,
        'startMinute': prefs.getInt(_keyScheduleStartM) ?? 0,
        'endHour': prefs.getInt(_keyScheduleEndH) ?? 6,
        'endMinute': prefs.getInt(_keyScheduleEndM) ?? 0,
        'action': prefs.getString(_keyScheduleAction) ?? 'eco',
      };
    } catch (_) {
      return {
        'enabled': false,
        'startHour': 0,
        'startMinute': 0,
        'endHour': 6,
        'endMinute': 0,
        'action': 'eco',
      };
    }
  }
}

