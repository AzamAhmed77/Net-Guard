import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/localization/app_strings.dart';
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
  int _selectedTab = 0; // 0 = Wi-Fi Connect QR, 1 = Proxy Settings QR
  bool _isLoading = true;
  bool _isEditing = false;
  bool _obscurePassword = true;
  bool _isOpenNetwork = false;

  late TextEditingController _ssidController;
  late TextEditingController _passwordController;
  String _proxyHostPort = '192.168.43.1:8282';

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
      // Auto-detect phone's native hotspot / device name
      ssid = await MethodChannelService.getDeviceHotspotName();
    }

    final ip = await MethodChannelService.getHotspotIp();
    if (mounted) {
      setState(() {
        _ssidController.text = ssid;
        _passwordController.text = password;
        _isOpenNetwork = password.isEmpty && creds.containsKey('isOpen') && creds['isOpen'] == 'true';
        _proxyHostPort = '$ip:8282';
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

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final isAr = strings.isAr;

    return AlertDialog(
      backgroundColor: AppColors.surfaceCardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _selectedTab == 0 ? Icons.wifi_find_rounded : Icons.qr_code_2_rounded,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.hotspotQrDialogTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Tab Switcher (Segmented Control) ──
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _selectedTab = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? AppColors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  strings.hotspotTabWifi,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTab == 0 ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _selectedTab = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1 ? AppColors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  strings.hotspotTabProxy,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTab == 1 ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (_selectedTab == 0) ...[
                    // ════════════════════════════════════════
                    // TAB 0: WI-FI DIRECT CONNECT QR
                    // ════════════════════════════════════════
                    Text(
                      strings.hotspotWifiQrSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
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
                        size: 190.0,
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
                    const SizedBox(height: 14),

                    // Network info preview card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                  Icon(Icons.wifi, color: AppColors.accent, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.hotspotSsidLabel,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              Text(
                                _ssidController.text.isEmpty ? 'NetGuard Hotspot' : _ssidController.text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: AppColors.borderDark, height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lock_outline_rounded, color: AppColors.accent, size: 16),
                                  const SizedBox(width: 8),
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
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Text(
                                          _obscurePassword ? '••••••••' : _passwordController.text,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                            size: 16,
                                            color: AppColors.textSecondary,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Toggle Edit Mode Button
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _isEditing = !_isEditing),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isEditing ? Icons.expand_less : Icons.edit_rounded,
                              size: 15,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isEditing ? (isAr ? 'إخفاء التعديل' : 'Hide Edit') : strings.hotspotEditCredentials,
                              style: TextStyle(
                                fontSize: 12,
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
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
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
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _ssidController,
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'OnePlus 7 Pro',
                                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  strings.hotspotPasswordLabel,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
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
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: isAr ? 'أدخل كلمة مرور البث' : 'Enter Hotspot Password',
                                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                label: Text(
                                  strings.hotspotSaveCredentials,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: _saveCredentials,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    // ════════════════════════════════════════
                    // TAB 1: PROXY SETTINGS QR
                    // ════════════════════════════════════════
                    Text(
                      strings.hotspotQrDialogSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
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
                        data: _proxyHostPort,
                        version: QrVersions.auto,
                        size: 190.0,
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
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.router_rounded, color: AppColors.accent, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _proxyHostPort,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _proxyHostPort));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(strings.hotspotCopySuccess),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: [
                                  const Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAr ? 'نسخ' : 'Copy',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strings.hotspotProxyGuideTip,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.35,
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
}
