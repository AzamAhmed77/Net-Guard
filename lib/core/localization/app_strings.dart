import 'package:flutter/material.dart';

class AppStrings {
  final bool isAr;
  AppStrings(this.isAr);

  static AppStrings of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AppStrings(locale.languageCode == 'ar');
  }

  // App General
  String get appName => 'Net Guard';
  String get appSubtitle => isAr ? 'حارس وسرعة الشبكة' : 'Network Guardian & Speed';
  String get on => 'ON';
  String get off => 'OFF';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get save => isAr ? 'حفظ' : 'Save';
  String get ok => isAr ? 'حسناً' : 'OK';
  String get close => isAr ? 'إغلاق' : 'Close';
  String get search => isAr ? 'بحث...' : 'Search...';
  String get unlimited => isAr ? 'غير محدود (∞)' : 'Unlimited (∞)';

  // Modern Bottom Tabs
  String get tabHome => isAr ? 'الرئيسية' : 'Home';
  String get tabHistory => isAr ? 'السجل' : 'History';
  String get tabApps => isAr ? 'التطبيقات' : 'Apps';
  String get tabBlocker => isAr ? 'الحماية' : 'Blocker';
  String get tabUsage => isAr ? 'الاستهلاك' : 'Usage';

  // Legacy Tab aliases
  String get tabDashboard => tabHome;
  String get tabFirewall => tabApps;
  String get tabAnalytics => tabHistory;
  String get tabSecurity => tabBlocker;

  // Home Screen Telemetry
  String get currentSpeed => isAr ? 'السرعة الحالية' : 'Current';
  String get averageSpeed => isAr ? 'المعدل' : 'Average';
  String get maximumSpeed => isAr ? 'السرعة القصوى' : 'Maximum';
  String get liveDownload => isAr ? 'تنزيل' : 'Download';
  String get liveUpload => isAr ? 'رفع' : 'Upload';
  String get totalDownload => isAr ? 'إجمالي التنزيل' : 'Total Download';
  String get totalUpload => isAr ? 'إجمالي الرفع' : 'Total Upload';
  String get activeConnections => isAr ? 'الاتصالات' : 'Connections';
  String get connectionStatus => isAr ? 'حالة الحماية والاتصال' : 'Protection & Connection';
  String get vpnActive => isAr ? 'الحماية والتحكم نشط 🟢' : 'Protection Active 🟢';
  String get vpnInactive => isAr ? 'الحماية متوقفة (مراقبة فقط) ⚪' : 'Monitoring Only ⚪';

  // Speed Control & Presets
  String get speedControl => isAr ? 'التحكم بالسرعة' : 'Speed Control';
  String get speedPresets => isAr ? 'أوضاع السرعة الجاهزة' : 'Speed Presets';
  String get presetDefault => isAr ? 'عادي' : 'Default';
  String get presetZero => isAr ? 'كتم (0K)' : 'Mute';
  String get presetEco => isAr ? 'توفير' : 'Saver';
  String get presetBalanced => isAr ? 'عادي' : 'Default';
  String get presetPerformance => isAr ? 'ألعاب' : 'Gaming';
  String get presetUnlimited => isAr ? 'مفتوح' : 'Unlimited';
  String get manualSpeedLimit => isAr ? 'تحديد السرعة يدوياً' : 'Speed Limit';
  String get speedLimitLabel => isAr ? 'الحد الأقصى للسرعة:' : 'Speed Limit:';
  String get downloadLimitLabel => isAr ? 'تنزيل:' : 'Download:';
  String get uploadLimitLabel => isAr ? 'رفع:' : 'Upload:';
  String get noLimitsInfinite => isAr ? 'بدون حدود (∞)' : 'Unlimited (∞)';
  String get saveCustomSettings => isAr ? '💾 حفظ الإعدادات المخصصة' : '💾 Save Custom Settings';
  String get customSettingsSaved => isAr ? 'تم حفظ إعداداتك المخصصة بنجاح' : 'Custom settings saved successfully';
  String get customProfileTitle => isAr ? 'إعدادات الوضع المخصص' : 'Custom Profile Settings';
  String get customProfileCardTitle => isAr ? 'تكوين الوضع المخصص للتطبيقات' : 'Custom Apps Profile';
  String get customProfileDesc => isAr
      ? 'احفظ تكوين التطبيقات الحالي (الحظر، السماح، والسرعات الفردية لكل تطبيق) كوضع مخصص دائم يُمكنك استعادته بضغطة زر واحدة من زر [مخصص] في شاشة التطبيقات.'
      : 'Save current apps configuration (blocked, allowed, and individual speeds) as a permanent custom profile you can restore with one tap from [Custom] in Apps screen.';
  String get saveCustomProfileBtn => isAr ? '💾 حفظ إعدادات الوضع المخصص' : '💾 Save Custom Profile Settings';
  String get customProfileSaved => isAr ? 'تم حفظ تكوين الوضع المخصص بنجاح' : 'Custom profile configuration saved successfully';
  String get customProfileRestored => isAr ? 'تم استعادة وتطبيق إعدادات الوضع المخصص' : 'Custom profile applied successfully';
  String get noCustomProfileSaved => isAr ? 'لم يتم حفظ وضع مخصص بعد. قم بتخصيص التطبيقات أولاً ثم احفظها من الإعدادات.' : 'No custom profile saved yet. Customize apps first and save from Settings.';

  // Trends Section
  String get trendsTitle => isAr ? 'الاتجاهات والنشاط' : 'Trends';
  String get last15Hours => isAr ? 'آخر 15 ساعة' : 'Last 15 Hours';
  String get peakSpeed => isAr ? 'ذروة السرعة' : 'Peak Speed';
  String get hourlyAvg => isAr ? 'معدل الساعة' : 'Hourly Avg';

  // Apps Screen
  String get totalToday => isAr ? 'إجمالي اليوم' : 'Total Today';
  String get filterWifiMobile => isAr ? 'تصفية: واي فاي + بيانات' : 'Filters: Wi-Fi + Mobile data';
  String get searchApps => isAr ? 'بحث في التطبيقات...' : 'Search apps...';
  String get searchAppHint => isAr ? 'بحث عن تطبيق أو حزمة...' : 'Search apps or packages...';
  String get batchMode => isAr ? 'تحديد جماعي' : 'Batch Select';
  String get selectAll => isAr ? 'تحديد الكل' : 'Select All';
  String get deselectAll => isAr ? 'إلغاء التحديد' : 'Deselect All';
  String get allowSelected => isAr ? 'سماح للمحدد' : 'Allow Selected';
  String get blockSelected => isAr ? 'حظر المحدد' : 'Block Selected';
  String get filterAll => isAr ? 'الكل' : 'All';
  String get filterBlocked => isAr ? 'محجوب' : 'Blocked';
  String get filterAllowed => isAr ? 'مسموح' : 'Allowed';
  String get filterCustom => isAr ? 'مخصص' : 'Custom';
  String get wifiTooltip => isAr ? 'واي فاي' : 'WiFi';
  String get mobileTooltip => isAr ? 'بيانات الهاتف' : 'Mobile Data';
  String get allowed => isAr ? 'مسموح' : 'Allowed';
  String get blocked => isAr ? 'محجوب' : 'Blocked';
  String get tempPass => isAr ? 'تصريح مؤقت' : 'Temp Pass';
  String get tempPassDuration => isAr ? 'مدة التصريح المؤقت:' : 'Temporary Pass Duration:';
  String get minutes15 => isAr ? '15 دقيقة' : '15 Minutes';
  String get minutes30 => isAr ? '30 دقيقة' : '30 Minutes';
  String get hour1 => isAr ? 'ساعة واحدة' : '1 Hour';
  String get appDetails => isAr ? 'تفاصيل التطبيق' : 'App Details';
  String get appsConsumption => isAr ? 'استهلاك التطبيقات' : 'App Consumption';
  String get activeAppsCount => isAr ? 'تطبيق نشط' : 'active apps';
  String get noAppsUsageFound => isAr ? 'لا يوجد استهلاك مسجل للتطبيقات.' : 'No application usage recorded.';

  // Blocker & Firewall Screen
  String get blockerTitle => isAr ? 'الحماية والجدار الناري' : 'Blocker';
  String get blockerActive => isAr ? 'الحماية نشطة ومفعلة' : 'Blocker is Active';
  String get blockerInactive => isAr ? 'الحماية متوقفة حالياً' : 'Blocker is Inactive';
  String get blockerActiveSub => isAr ? 'كافة اتصالات التطبيقات تحت السيطرة والفلترة' : 'All traffic filtered and protected';
  String get blockerInactiveSub => isAr ? 'تحكم في التطبيقات والمواقع التي تتصل بالإنترنت' : 'Control which apps can use your internet';
  String get startBlocker => isAr ? 'تشغيل الحماية ⚡' : 'Start Blocker ⚡';
  String get stopBlocker => isAr ? 'إيقاف الحماية' : 'Stop Blocker';
  String get defaultAction => isAr ? 'السياسة الافتراضية' : 'Default Action';
  String get allowAll => isAr ? 'السماح للكل' : 'Allow All';
  String get blockAll => isAr ? 'حظر الكل' : 'BLOCK ALL';
  String get blockAllDesc => isAr ? 'حظر جميع التطبيقات تلقائياً، والاستثناء يدوي' : 'Block all apps by default, whitelist manually';
  String get enableSchedule => isAr ? 'جدولة حظر الإنترنت' : 'Schedule Internet Block';
  String get scheduleDesc => isAr ? 'قطع الإنترنت تلقائياً خلال الفترة المحددة أدناه' : 'Automatically block internet during the period below';
  String get fromHour => isAr ? 'بداية الحظر' : 'Block From';
  String get toHour => isAr ? 'نهاية الحظر' : 'Block Until';
  String get autoQuarantine => isAr ? 'عزل التطبيقات الجديدة تلقائياً' : 'Auto-Quarantine New Apps';
  String get autoQuarantineDesc => isAr ? 'حظر أي تطبيق جديد يتم تثبيته فوراً' : 'Immediately block newly installed apps';
  String get lockdownScreenOff => isAr ? 'حظر عند قفل الشاشة' : 'Lockdown on Screen Off';
  String get lockdownScreenOffDesc => isAr ? 'قطع الإنترنت عند إغلاق الشاشة لتوفير البطارية' : 'Cut traffic on screen off to save battery';
  String get securityProfiles => isAr ? 'الأوضاع الأمنية السريعة' : 'Quick Security Profiles';
  String get profileCustom => isAr ? 'مخصص' : 'Custom';
  String get profileUltraSaver => isAr ? 'توفير فائق' : 'Ultra Saver';
  String get profileFocus => isAr ? 'وضع التركيز' : 'Focus Mode';
  String get profileGaming => isAr ? 'وضع الألعاب' : 'Gaming Mode';

  // Smart DNS Filters
  String get dnsFiltersTitle => isAr ? 'فلاتر DNS الذكية' : 'DNS & Security Filters';
  String get blockAdsTitle => isAr ? 'حظر الإعلانات والتعقب' : 'Ad & Tracker Blocking';
  String get blockAdsDesc => isAr ? 'تصفية الإعلانات وبرمجيات التتبع تلقائياً' : 'Auto-block ads and tracking scripts';
  String get blockAdultTitle => isAr ? 'الحماية العائلية' : 'Family Protection';
  String get blockAdultDesc => isAr ? 'حظر المواقع الإباحية والمحتوى الضار' : 'Block adult and harmful content';
  String get blockSocialTitle => isAr ? 'وضع التركيز' : 'Focus Mode';
  String get blockSocialDesc => isAr ? 'حظر شبكات التواصل لزيادة الإنتاجية' : 'Block social media to boost focus';
  String get customBlocklistTitle => isAr ? 'قائمة الحظر المخصصة' : 'Custom Domain Blocklist';
  String get blockDomainHint => isAr ? 'مثال: example.com' : 'e.g. example.com';
  String get blockBtn => isAr ? 'حظر' : 'Block';
  String get dnsProviderTitle => isAr ? 'مزود خادم DNS المشفر' : 'Encrypted DNS Provider';

  // History & Plan Quota Screen
  String get historyTitle => isAr ? 'السجل وباقة البيانات' : 'History';
  String get last7Days => isAr ? 'آخر 7 أيام' : 'Last 7 Days';
  String get last30Days => isAr ? 'آخر 30 يوماً' : 'Last 30 Days';
  String get thisMonth => isAr ? 'هذا الشهر' : 'This Month';
  String get dailyUsageHistory => isAr ? 'سجل الاستهلاك اليومي' : 'Daily Usage History';
  String get dataPlanTitle => isAr ? 'استهلاك باقة البيانات' : 'Data Plan Quota';
  String get planRenewalIn => isAr ? 'تجديد الباقة في' : 'Renews in';
  String get days => isAr ? 'يوم' : 'days';
  String get planLimit => isAr ? 'الحد' : 'Limit';
  String get planRemaining => isAr ? 'متبقي' : 'Remaining';
  String get planUsed => isAr ? 'مستهلك' : 'Used';
  String get planSizeLabel => isAr ? 'حجم الباقة الشهرية' : 'Monthly Plan Size';
  String get actionOnLimit => isAr ? 'الإجراء عند تجاوز الحد' : 'Action on Limit Exceeded';
  String get actionThrottle => isAr ? 'تقييد السرعة (Throttle)' : 'Throttle Speed';
  String get actionDisconnect => isAr ? 'قطع الاتصال (Disconnect)' : 'Disconnect';

  // Settings Screen
  String get settingsTitle => isAr ? 'الإعدادات' : 'Settings';
  String get themeSection => isAr ? 'المظهر' : 'THEME';
  String get themeLabel => isAr ? 'الوضع' : 'Theme';
  String get themeDark => isAr ? 'داكن (Dark)' : 'Dark';
  String get accentColor => isAr ? 'لون التمييز' : 'Accent Color';
  String get monitorProtectionSection => isAr ? 'المراقبة والحماية' : 'MONITOR & PROTECTION';
  String get bgMonitor => isAr ? 'مراقب السرعة في الخلفية' : 'Background Speed Monitor';
  String get bgMonitorDesc => isAr ? 'إشعار حي بشريط الإشعارات بدون الحاجة للـ VPN' : 'Live status bar notification without VPN';
  String get dataSpike => isAr ? 'كاشف النزيف السري للبيانات' : 'Data Spike Detector';
  String get dataSpikeDesc => isAr ? 'تنبيه فوري عند استهلاك غير متوقع للبيانات' : 'Instant alert on unexpected data spikes';
  String get generalSection => isAr ? 'عام' : 'GENERAL';
  String get languageLabel => isAr ? 'اللغة' : 'Language';
  String get planCycle => isAr ? 'دورة باقة البيانات' : 'Data Plan Cycle';
  String get cycleStarts1st => isAr ? 'تبدأ في 1 من كل شهر' : 'Starts on 1st of month';
  String get aboutVersion => isAr ? 'عن التطبيق والإصدار' : 'About & Version';

  String get allowAllDesc => isAr ? 'السماح لجميع التطبيقات تلقائياً بالوصول للإنترنت' : 'Allow all apps by default';
  String get downloadSpeedLimit => isAr ? 'حد سرعة التنزيل' : 'Download Speed Limit';
  String get uploadSpeedLimit => isAr ? 'حد سرعة الرفع' : 'Upload Speed Limit';
  String get tapToTypeSpeed => isAr ? 'اضغط للكتابة بالكيبورد' : 'Tap to enter value';
  String get enterSpeedKbps => isAr ? 'أدخل السرعة بالكيلوبايت/ثانية (KB/s):' : 'Enter speed in KB/s:';
  String get setSpeed => isAr ? 'تعيين' : 'Set';

  // History Tab & Filters
  String get allNetworks => isAr ? 'كل الشبكات' : 'All Network';
  String get wifiOnly => isAr ? 'واي فاي فقط' : 'WiFi Only';
  String get mobileOnly => isAr ? 'بيانات الهاتف فقط' : 'Mobile Only';
  String get mobileDataShort => isAr ? 'بيانات الهاتف' : 'Mobile';
  String get filterTitle => isAr ? 'فلترة' : 'Filter';
  String get filters => isAr ? 'الفلاتر' : 'Filters';
  String get selectSession => isAr ? 'تحديد الفترة' : 'Select session';
  String get today => isAr ? 'اليوم' : 'Today';
  String get yesterday => isAr ? 'أمس' : 'Yesterday';
  String get thisWeek => isAr ? 'هذا الأسبوع' : 'This Week';
  String get lastMonth => isAr ? 'الشهر الماضي' : 'Last month';
  String get thisYear => isAr ? 'هذا العام' : 'This year';
  String get allTime => isAr ? 'كل الأوقات' : 'All time';
  String get addCustom => isAr ? 'إضافة فترة مخصصة' : 'Add Custom';
  String get customPeriod => isAr ? 'فترة مخصصة' : 'Custom Period';
  String get networkType => isAr ? 'نوع الشبكة' : 'Network Type';
  String get mobileData => isAr ? 'بيانات الهاتف' : 'Mobile data';
  String get wiFi => isAr ? 'واي فاي' : 'Wi-Fi';
  String get applyFilters => isAr ? 'تطبيق الفلاتر' : 'Apply Filters';
  String get reset => isAr ? 'إعادة تعيين' : 'Reset';
  String get delete => isAr ? 'حذف' : 'Delete';
  String get appUsage => isAr ? 'استهلاك التطبيقات' : 'App Usage Breakdown';
  String get hourlyAverage => hourlyAvg;

  // Event Logs & Diagnostics
  String get liveEventLogs => isAr ? 'سجل الأحداث المباشر' : 'Live Event Logs';
  String get noLogsYet => isAr ? 'لا توجد أحداث جديدة.' : 'No new events.';
  String get clearLogs => isAr ? 'مسح السجل' : 'Clear Logs';
  String get exportLogs => isAr ? 'تصدير السجل' : 'Export Logs';
  String get logsCopied => isAr ? 'تم نسخ السجلات إلى الحافظة بنجاح' : 'Logs copied to clipboard successfully';
  String get systemPermissions => isAr ? 'صلاحيات وأذونات النظام' : 'System Permissions';
  String get diagnostics => isAr ? 'تشخيص وإصلاح الأعطال' : 'Service Self-Healing Diagnostics';

  // ── Permissions Modal ──
  String get permissionsTitle => isAr ? 'صلاحيات وأذونات النظام' : 'System Permissions';
  String get permissionsSubtitle => isAr ? 'تكامل عالي الأداء مع نظام أندرويد' : 'High-performance Android integration';
  String get permAllGranted => isAr
      ? 'جميع الصلاحيات ممنوحة! التطبيق يعمل بأعلى كفاءة وسجلات حقيقية 100%.'
      : 'All permissions granted! App running at full efficiency with real logs.';
  String get permNotGranted => isAr
      ? 'امنح الصلاحيات التالية لتفعيل السجل الحقيقي من الجوال والعمل بالخلفية.'
      : 'Grant the following permissions to enable real usage logs and background operation.';
  String get permUsageTitle => isAr ? 'الوصول لبيانات الاستخدام (Usage Stats)' : 'Usage Data Access (Usage Stats)';
  String get permUsageDesc => isAr
      ? 'لقراءة استهلاك الإنترنت الحقيقي والدقيق لكل تطبيق من نظام أندرويد مباشرة (NetworkStatsManager).'
      : 'Read real per-app internet usage directly from Android (NetworkStatsManager).';
  String get permUsageAction => isAr ? 'تفعيل السجل الحقيقي' : 'Enable Real Logs';
  String get permBatteryTitle => isAr ? 'استثناء تحسين البطارية (Background Work)' : 'Battery Optimization Exemption';
  String get permBatteryDesc => isAr
      ? 'لمنع أندرويد من إيقاف الخدمة في الخلفية وضمان ثبات السرعات وحظر التطبيقات.'
      : 'Prevent Android from stopping background services to ensure stable speed control.';
  String get permBatteryAction => isAr ? 'استثناء البطارية' : 'Exempt Battery';
  String get permNotifTitle => isAr ? 'إشعارات الخدمة المباشرة (Notifications)' : 'Live Service Notifications';
  String get permNotifDesc => isAr
      ? 'لعرض عداد سرعة النت اللحظي وحالة الحماية في شريط الإشعارات بدون انقطاع.'
      : 'Display live speed meter and protection status in the notification bar.';
  String get permNotifAction => isAr ? 'تفعيل الإشعارات' : 'Enable Notifications';
  String get permVpnTitle => isAr ? 'ترخيص خدمة الشبكة (VPN Permission)' : 'Network Service License (VPN)';
  String get permVpnDesc => isAr
      ? 'مطلوب للتحكم في سرعة التطبيقات وحظر الإعلانات وفلترة DNS.'
      : 'Required for app speed control, ad blocking, and DNS filtering.';
  String get permVpnAction => isAr ? 'مُفعّل بالنظام' : 'Enabled by System';
  String get permGranted => isAr ? 'ممنوح ✓' : 'Granted ✓';
  String get permRequired => isAr ? 'مطلوب' : 'Required';
  String get permRefreshStatus => isAr ? 'تحديث الحالة' : 'Refresh Status';
  String get permDone => isAr ? 'تم' : 'Done';
  String get permRestrictedHelpTitle => isAr
      ? 'إذا كان الإذن رمادياً أو معطلاً (أندرويد 13 فما فوق):'
      : 'If the permission is greyed out (Android 13+):';
  String get permRestrictedHelpBody => isAr
      ? 'لحمايتك، يُقيد أندرويد أذونات التطبيقات المرسلة خارج المتجر تلقائياً.\nالحل: افتح معلومات التطبيق بالزر أدناه ⬅️ اضغط الثلاث نقاط (⋮) أعلى الشاشة ⬅️ اختر "السماح بالإعدادات المقيدة" (Allow restricted settings).'
      : 'Android restricts permissions for sideloaded apps.\nFix: Open app info below ⬅️ Tap the 3-dot menu (⋮) ⬅️ Choose "Allow restricted settings".';
  String get permOpenAppInfo => isAr ? '⚙️ فتح معلومات التطبيق لفك القيد' : '⚙️ Open App Info to remove restriction';

  // ── About Modal ──
  String get aboutTitle => isAr ? 'حول Net Guard والأمان' : 'About Net Guard & Security';
  String get aboutFrameworkVersion => 'Net Guard Framework v1.0';
  String get aboutFrameworkDesc => isAr ? 'حارس الشبكة والتحكم الذكي بحركة المرور' : 'Network Guardian & Intelligent Traffic Controller';
  String get revoke => isAr ? 'إلغاء' : 'Revoke';
  String minRemaining(int minutes) => isAr ? 'متبقي $minutes دقيقة' : '$minutes min remaining';
  String get aboutBody => isAr
      ? 'نظام بيئي سيبراني محلي يعتمد على مبادئ الثقة الصفرية (Zero-Trust) ومعالجة الحزم على مستوى النواة (Kernel-Level) دون الحاجة لأي خوادم خارجية لحماية الخصوصية المطلقة 100%.'
      : 'A local cybersecurity ecosystem built on Zero-Trust principles and Kernel-Level packet processing, requiring no external servers for 100% absolute privacy protection.';
  String get aboutCopyright => isAr ? '© 2025 Net Guard Security. جميع الحقوق محفوظة.' : '© 2025 Net Guard Security. All rights reserved.';

  // ── Expert Settings Modal ──
  String get expertSettingsTitle => isAr ? 'الإعدادات المتقدمة' : 'Expert Settings';
  String get ebpfTitle => isAr ? 'وحدة تسريع النواة eBPF Kernel' : 'eBPF Kernel Acceleration';
  String get ebpfDesc => isAr ? 'فلترة الحزم وتقييد السرعة داخل Kernel Space لتوفير البطارية' : 'Kernel-level packet filtering & throttling to save battery';
  String get dpiTitle => isAr ? 'تحليل الحزم العميق (DPI Inspection)' : 'Deep Packet Inspection (DPI)';
  String get dpiDesc => isAr ? 'تحليل أنواع حركة المرور وتطبيق قواعد جودة الخدمة QoS' : 'Analyze traffic protocols and apply QoS rules';
  String get dnsRebindingTitle => isAr ? 'حماية DNS Rebinding Protection' : 'DNS Rebinding Protection';
  String get dnsRebindingDesc => isAr ? 'منع البرمجيات الخبيثة من استغلال الشبكات المحلية' : 'Prevent malicious scripts from attacking local networks';

  // ── Hotspot Speed Controller ──
  String get hotspotSectionTitle => isAr ? 'بث نقطة الاتصال (Hotspot)' : 'Hotspot Tethering';
  String get hotspotControllerTitle => isAr ? 'متحكم سرعة بث نقطة الاتصال' : 'Hotspot Speed Controller';
  String get hotspotControllerDesc => isAr
      ? 'تقييد سرعة الأجهزة المتصلة ببث هاتفك ومراقبة استهلاكها اللحظي'
      : 'Throttle tethered devices speed and monitor live hotspot data usage';
  String get hotspotStatusActive => isAr ? 'متحكم البث قيد التشغيل 🟢' : 'Hotspot Controller Active 🟢';
  String get hotspotStatusStopped => isAr ? 'متحكم البث متوقف ⚪' : 'Hotspot Controller Stopped ⚪';
  String get hotspotProxySettings => isAr ? 'بيانات البروكسي للأجهزة المتصلة' : 'Proxy Settings for Connected Devices';
  String get hotspotIpLabel => isAr ? 'عنوان IP (المضيف):' : 'Host IP:';
  String get hotspotPortLabel => isAr ? 'المنفذ (Port):' : 'Port:';
  String get hotspotSpeedLimits => isAr ? 'تحديد السرعة للأجهزة المتصلة' : 'Tethered Speed Limits';
  String get hotspotConnectedClients => isAr ? 'الأجهزة المتصلة حالياً:' : 'Active Connected Devices:';
  String get hotspotDataConsumed => isAr ? 'بيانات البث المستهلكة:' : 'Hotspot Data Consumed:';
  String get hotspotSetupGuide => isAr ? 'طريقة ربط الأجهزة بالبث المقيد' : 'Quick Setup Guide';
  String get hotspotSetupAndroid => isAr ? 'أندرويد (Android)' : 'Android';
  String get hotspotSetupIos => isAr ? 'آيفون / آيباد (iOS)' : 'iPhone / iPad';
  String get hotspotSetupPc => isAr ? 'كمبيوتر (Windows / Mac)' : 'PC (Windows / Mac)';
  String get hotspotCopySuccess => isAr ? 'تم نسخ بيانات الاتصال إلى الحافظة' : 'Connection details copied to clipboard';
}

