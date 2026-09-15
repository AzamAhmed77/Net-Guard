import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/localization/app_strings.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/services/method_channel_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/themes/app_colors.dart';

void showHotspotQrDialog(BuildContext context, AppStrings strings) {
  showDialog(
    context: context,
    builder: (ctx) => _HotspotQrDialog(strings: strings),
  );
}

class _HotspotQrDialog extends StatefulWidget {
  final AppStrings strings;
  const _HotspotQrDialog({required this.strings});

  @override
  State<_HotspotQrDialog> createState() => _HotspotQrDialogState();
}

class _HotspotQrDialogState extends State<_HotspotQrDialog> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _obscurePassword = true;
  bool _isOpenNetwork = false;
  int _activeTab = 0; // 0 = Wi-Fi Connect QR, 1 = Speed Controller PAC/Proxy

  late TextEditingController _ssidController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _ssidController = TextEditingController();
    _passwordController = TextEditingController();
    _loadHotspotInfo();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadHotspotInfo() async {
    final creds = await StorageService.loadHotspotWifiCredentials();
    String ssid = creds['ssid'] ?? '';
    String password = creds['password'] ?? '';

    if (ssid.isEmpty) {
      ssid = await MethodChannelService.getDeviceHotspotName();
    }

    if (mounted) {
      setState(() {
        _ssidController.text = ssid;
        _passwordController.text = password;
        _isOpenNetwork = password.isEmpty && creds.containsKey('isOpen') && creds['isOpen'] == 'true';
        _isLoading = false;
      });
    }
  }

  String _escapeWifi(String val) {
    return val
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll(':', r'\:')
        .replaceAll('"', r'\"');
  }

  String _getWifiQrData() {
    final ssid = _ssidController.text.trim().isEmpty ? 'NetGuard Hotspot' : _ssidController.text.trim();
    final password = _passwordController.text.trim();

    if (_isOpenNetwork || password.isEmpty) {
      return 'WIFI:T:nopass;S:${_escapeWifi(ssid)};;';
    }
    return 'WIFI:T:WPA;S:${_escapeWifi(ssid)};P:${_escapeWifi(password)};;';
  }

  Future<void> _saveCredentials() async {
    final ssid = _ssidController.text.trim();
    final password = _isOpenNetwork ? '' : _passwordController.text.trim();
    await StorageService.saveHotspotWifiCredentials(
      ssid: ssid,
      password: password,
    );
    if (!mounted) return;
    setState(() {
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.strings.hotspotCredentialsSaved),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.strings.isAr ? 'تم نسخ $label بنجاح' : 'Copied $label to clipboard',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final isAr = strings.isAr;
    final vpn = Provider.of<VpnManager>(context);

    final hotspotIp = vpn.hotspotIp.isNotEmpty ? vpn.hotspotIp : '192.168.43.1';
    final hotspotPort = vpn.hotspotPort > 0 ? vpn.hotspotPort : 8282;
    final pacUrl = 'http://$hotspotIp:$hotspotPort/pac';
    final speedLimitText = vpn.hotspotDownloadLimitKbps > 0
        ? '${vpn.hotspotDownloadLimitKbps} KB/s'
        : (isAr ? 'غير محدود' : 'Unlimited');

    return AlertDialog(
      backgroundColor: AppColors.surfaceCardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'متحكم سرعة نقطة الاتصال' : 'Hotspot Speed Controller',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Tab bar switcher
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.bgDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isAr ? '1. اتصال الواي فاي' : '1. Wi-Fi Connect',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 0 ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? AppColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isAr ? '2. تفعيل تحديد السرعة' : '2. Speed Limiter',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 1 ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: _isLoading
          ? SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          : SingleChildScrollView(
              child: _activeTab == 0
                  ? _buildWifiConnectTab(strings, isAr)
                  : _buildSpeedControllerTab(isAr, hotspotIp, hotspotPort, pacUrl, speedLimitText),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            strings.close,
            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildWifiConnectTab(AppStrings strings, bool isAr) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.hotspotWifiQrSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: QrImageView(
            data: _getWifiQrData(),
            version: QrVersions.auto,
            size: 180.0,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F172A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Network info preview card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi, color: AppColors.accent, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        strings.hotspotSsidLabel,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _ssidController.text.isEmpty ? 'NetGuard Hotspot' : _ssidController.text,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copyToClipboard(_ssidController.text, strings.hotspotSsidLabel),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: AppColors.borderDark, height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: AppColors.accent, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        strings.hotspotPasswordLabel,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  _isOpenNetwork || _passwordController.text.isEmpty
                      ? Text(
                          isAr ? 'مفتوحة (بدون كلمة سر)' : 'Open (No password)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        )
                      : Row(
                          children: [
                            Text(
                              _obscurePassword ? '••••••••' : _passwordController.text,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: 15,
                                color: AppColors.textSecondary,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _copyToClipboard(_passwordController.text, strings.hotspotPasswordLabel),
                            ),
                          ],
                        ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Toggle Edit Mode Button
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _isEditing = !_isEditing),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isEditing ? Icons.expand_less : Icons.edit_rounded,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  _isEditing ? (isAr ? 'إخفاء التعديل' : 'Hide Edit') : strings.hotspotEditCredentials,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Inline Edit Form
        if (_isEditing) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgDark.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.hotspotSsidLabel,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _ssidController,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'My Hotspot',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    filled: true,
                    fillColor: AppColors.surfaceCardDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.hotspotPasswordLabel,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _isOpenNetwork,
                          activeColor: AppColors.accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) {
                            setState(() {
                              _isOpenNetwork = val ?? false;
                            });
                          },
                        ),
                        Text(
                          strings.hotspotNoPassword,
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_isOpenNetwork) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: isAr ? 'أدخل كلمة مرور البث' : 'Enter Hotspot Password',
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      filled: true,
                      fillColor: AppColors.surfaceCardDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.accent),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 15),
                    label: Text(
                      strings.hotspotSaveCredentials,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _saveCredentials,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSpeedControllerTab(
    bool isAr,
    String hotspotIp,
    int hotspotPort,
    String pacUrl,
    String speedLimitText,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status & active speed badge
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.speed_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr
                      ? 'السرعة المحددة للبث: $speedLimitText'
                      : 'Hotspot Speed Limit: $speedLimitText',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Text(
          isAr
              ? 'لتطبيق تحديد السرعة على أجهزة أصدقائك المتصلة:'
              : 'To enforce speed limit on connected devices:',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isAr
              ? 'في جوال صديقك، بعد الاتصال بنقطة البث:\n1. افتح إعدادات شبكة الواي فاي ← متقدم (Advanced).\n2. في خيار "البروكسي" اختر "تلقائي / Auto (PAC)" والصق الرابط أدناه:'
              : 'On your friend\'s device after connecting to Wi-Fi:\n1. Open Wi-Fi settings → Advanced.\n2. In "Proxy", select "Auto-config (PAC)" and paste the URL below:',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 10),

        // 1-Tap PAC Copy Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'رابط البروكسي التلقائي (PAC):' : 'Auto Proxy (PAC) URL:',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pacUrl,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text(
                  isAr ? 'نسخ' : 'Copy',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _copyToClipboard(pacUrl, isAr ? 'رابط PAC التلقائي' : 'PAC URL'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Manual Proxy Alternative
        Text(
          isAr ? 'أو عبر البروكسي اليدوي (Manual Proxy):' : 'Or via Manual Proxy:',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'المضيف (Host): $hotspotIp' : 'Host: $hotspotIp',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    isAr ? 'المنفذ (Port): $hotspotPort' : 'Port: $hotspotPort',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceCardDark,
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text(
                  isAr ? 'نسخ المضيف' : 'Copy IP',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _copyToClipboard(hotspotIp, isAr ? 'عنوان IP' : 'Host IP'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
