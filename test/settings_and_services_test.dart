import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:net_speed_controller/core/models/app_info.dart';
import 'package:net_speed_controller/core/models/vpn_config.dart';
import 'package:net_speed_controller/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService Security Profile & Settings Tests', () {
    test('Default security profile is "default"', () async {
      final profile = await StorageService.loadActiveSecurityProfile();
      expect(profile, 'default');
    });

    test('Save and load custom security profile persists accurately', () async {
      await StorageService.saveActiveSecurityProfile('custom');
      final profile = await StorageService.loadActiveSecurityProfile();
      expect(profile, 'custom');
    });

    test('Save and load block_all security profile persists accurately', () async {
      await StorageService.saveActiveSecurityProfile('block_all');
      final profile = await StorageService.loadActiveSecurityProfile();
      expect(profile, 'block_all');
    });

    test('Custom profile app rules save and restore completely', () async {
      final apps = [
        AppInfo(
          packageName: 'com.example.chat',
          name: 'ChatApp',
          uid: 10042,
          isWifiAllowed: false,
          isMobileAllowed: true,
          speedMode: 'custom',
          customSpeedLimitKbps: 128,
        ),
        AppInfo(
          packageName: 'com.example.game',
          name: 'GameApp',
          uid: 10043,
          isWifiAllowed: true,
          isMobileAllowed: false,
          speedMode: 'unlimited',
          customSpeedLimitKbps: 0,
        ),
      ];

      await StorageService.saveCustomProfileSettings(apps, 256, 128);
      final hasCustom = await StorageService.hasSavedCustomProfile();
      expect(hasCustom, isTrue);

      // Mutate apps
      apps[0].isWifiAllowed = true;
      apps[0].speedMode = 'default';
      apps[0].customSpeedLimitKbps = 0;

      // Restore
      final restoredCount = await StorageService.restoreCustomProfileSettings(apps);
      expect(restoredCount, 2);
      expect(apps[0].isWifiAllowed, isFalse);
      expect(apps[0].isMobileAllowed, isTrue);
      expect(apps[0].speedMode, 'custom');
      expect(apps[0].customSpeedLimitKbps, 128);
    });

    test('Hotspot wifi credentials persist correctly', () async {
      await StorageService.saveHotspotWifiCredentials(
        ssid: 'NetGuard-VIP',
        password: 'securePassword123',
      );
      final creds = await StorageService.loadHotspotWifiCredentials();
      expect(creds['ssid'], 'NetGuard-VIP');
      expect(creds['password'], 'securePassword123');
    });

    test('Language preference persistence', () async {
      await StorageService.saveLanguage('en');
      final lang = await StorageService.loadLanguage();
      expect(lang, 'en');

      await StorageService.saveLanguage('ar');
      final langAr = await StorageService.loadLanguage();
      expect(langAr, 'ar');
    });

    test('VpnConfig serialization integrity', () {
      final config = VpnConfig(
        downloadSpeedLimit: 512,
        uploadSpeedLimit: 256,
        presetMode: 'custom',
        globalMode: 'whitelist',
      );
      final json = config.toJson();
      final restored = VpnConfig.fromJson(json);

      expect(restored.downloadSpeedLimit, 512);
      expect(restored.uploadSpeedLimit, 256);
      expect(restored.presetMode, 'custom');
      expect(restored.globalMode, 'whitelist');
    });
  });
}
