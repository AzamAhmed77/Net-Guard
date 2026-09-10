# 🛡️ Net Guard — حارس الإنترنت ومتحكم السرعة الذكي
### Advanced Network Traffic Controller, Firewall & Data Saver for Android

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.x-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white)](https://kotlinlang.org)
[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![Release](https://img.shields.io/badge/Download_APK-v1.0.0-success?style=for-the-badge&logo=android)](https://github.com/AzamAhmed77/Net-Guard/releases/tag/v1.0.0)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

> 📥 **[اضغط هنا لتحميل أحدث نسخة جاهزة للتثبيت فوراً (NetGuard v1.0.0 APK)](https://github.com/AzamAhmed77/Net-Guard/raw/main/NetGuard_Release.apk)** 🚀

---

## 🌐 الفهرس | Table of Contents
- [🇸🇦 الشرح باللغة العربية](#-الشرح-باللغة-العربية)
  - [1. نبذة عن التطبيق](#1-نبذة-عن-التطبيق)
  - [2. المميزات الرئيسية بالتفصيل](#2-المميزات-الرئيسية-بالتفصيل)
  - [3. طريقة استخدام متحكم سرعة بث نقطة الاتصال](#3-طريقة-استخدام-متحكم-سرعة-بث-نقطة-الاتصال-hotspot)
  - [4. المعمارية التقنية](#4-المعمارية-التقنية)
  - [5. طريقة التثبيت والبناء](#5-طريقة-التثبيت-والبناء)
  - [6. الأذونات المطلوبة](#6-الأذونات-المطلوبة-وسبب-طلبها)
  - [7. حقوق الملكية والترخيص](#7-حقوق-الملكية-والترخيص)
- [🇬🇧 English Documentation](#-english-documentation)
  - [1. Overview](#1-overview)
  - [2. Comprehensive Key Features](#2-comprehensive-key-features)
  - [3. Hotspot Speed Controller Setup Guide](#3-hotspot-speed-controller-setup-guide)
  - [4. Technical Architecture](#4-technical-architecture)
  - [5. How to Build & Install](#5-how-to-build--install)
  - [6. Required Android Permissions](#6-required-android-permissions)
  - [7. Copyright & License](#7-copyright--license)

---

# 🇸🇦 الشرح باللغة العربية

## 1. نبذة عن التطبيق
**Net Guard (حارس الإنترنت)** هو تطبيق متكامل وقوي لنظام أندرويد مصمم للتحكم الكامل في حركة البيانات والإنترنت داخل هاتفك. يجمع التطبيق بين **جدار حماية ذكي (Firewall)**، **محدد سرعة فائق الدقة (Bandwidth Throttler)**، **متحكم سرعة بث نقطة الاتصال (Hotspot Speed Controller)**، و**نظام مراقبة استهلاك الباقة الشهرية**، كل ذلك بدون الحاجة إلى صلاحيات الروت (**No Root Required**) وبأعلى معايير الحفاظ على شحن البطارية.

---

## 2. المميزات الرئيسية بالتفصيل

### 🛡️ جدار حماية ذكي لكل تطبيق (Per-App Firewall)
- **حظر شامل أو مخصص:** إمكانية قطع الإنترنت تماماً أو السماح به لتطبيقات محددة بنقرة واحدة.
- **فصل شبكة الواي فاي عن شريحة البيانات:** تحكم مستقل في وصول كل تطبيق لشبكة Wi-Fi أو بيانات الهاتف (Mobile Data).
- **العزل التلقائي للتطبيقات الجديدة (Auto Quarantine):** وضع أي تطبيق يتم تثبيته حديثاً في الحجر الصحي فوراً لمنعه من استنزاف الرصيد في الخلفية قبل موافقتك.
- **حظر الإنترنت عند قفل الشاشة (Lockdown on Screen Off):** قطع الاتصال عن التطبيقات غير الضرورية بمجرد إغلاق الشاشة لتوفير البطارية ومنع التحديثات المباغتة.

### ⚡ تحكم دقيق ومتقدم في سرعة الإنترنت (Bandwidth Throttling)
- تحديد السرعة القصوى للتحميل (Download) والرفع (Upload) على مستوى الهاتف أو لكل تطبيق على حدة.
- أوضاع سرعة سريعة جاهزة:
  - **وضع التوفير (Eco Mode):** سرعة محددة مثالية للرسائل النصية والدردشة مع أقل استهلاك للباقة.
  - **الوضع العادي (Normal Mode):** تصفح متوازن بدون استهلاك مفرط.
  - **الوضع المفتوح (Unlimited):** سرعة الشبكة القصوى عند الحاجة.
- محرك خنق حركة البيانات المعتمد على خوارزمية **Token-Bucket** الرياضية لضمان تدفق سلس للبيانات دون تقطيع الاتصال.

### 📡 متحكم سرعة بث نقطة الاتصال (Hotspot Speed Controller)
- **تقييد سرعة الأجهزة المتصلة:** حماية باقة هاتفك عند مشاركة الإنترنت مع الآخرين.
- **خيارات سرعة متعددة تشمل:**
  - **`64 KB/s` (توفير فائق):** كافٍ لرسائل الواتساب والتصفح الخفيف جداً ويمنع الفيديوهات الثقيلة تماماً.
  - `128 KB/s` - `256 KB/s` - `512 KB/s` - `1 MB/s` - `2 MB/s` - `مفتوح (∞)`.
- **خادم وسيط محلي متطور (High-Performance Local Proxy Server):** يعمل على المنفذ `8282` ويعمل بشكل مستقل تماماً عن حماية الهاتف الخاصة بـ VPN.

### 🔔 شريط إشعارات حي ذكي ومتكيف (Adaptive Live Notification)
- يعرض سرعة التحميل والرفع اللحظية واستهلاك اليوم لشبكة الواي فاي والبيانات.
- **تكيف تلقائي للألوان:**
  - نصوص سوداء واضحة (`#111111`) عالية التباين في **الوضع الفاتح (النهاري)**.
  - نصوص بيضاء ناصعة (`#FFFFFF`) في **الوضع المظلم (الليلي)**.
- تصميم مضغوط وأنيق خالي من الفراغات والأسهم الزائدة مع زر مدمج سريع لتشغيل أو إيقاف الحماية (`⚡ تشغيل` / `🛑 إيقاف`).

### 🔒 خوادم DNS مشفرة وحماية عائلية (Encrypted DNS & Content Filtering)
- دعم خوادم DNS الآمنة والموثوقة عالمياً:
  - **Cloudflare DNS (`1.1.1.1`):** أسرع استجابة مع تشفير وحماية الخصوصية.
  - **AdGuard DNS (`94.140.14.14`):** حجب تلقائي للإعلانات والتعقب والمواقع الخبيثة.
  - **Google Public DNS (`8.8.8.8`):** موثوقية واستقرار فائق.
- إمكانية تفعيل **الحماية العائلية (Family Shield)** لحظر المحتوى غير المناسب والمواقع الضارة.

### 📊 إدارة باقة البيانات الشهرية والتنبيهات (Data Plan & Spike Monitor)
- تتبع حجم الاستهلاك من الباقة الشهرية وتحديد يوم تجديد الباقة مع عداد تنازلي للمتبقي.
- إجراءات ذكية تلقائية عند نفاد أو تجاوز حد الباقة (تقييد السرعة أو فصل النت).
- **كاشف النزيف السري للبيانات (Data Spike Alert):** ينبهك فوراً إذا بدأ أي تطبيق باستهلاك غير طبيعي ومفاجئ للبيانات في الخلفية.

### 🔋 كفاءة قصوى للبطارية ودعم وضع السكون (Battery Optimization)
- صُممت الخدمات الخلفية لتدخل في وضع السكون العميق (**Deep Sleep**) فور إغلاق الشاشة.
- استخدام مؤقتات غير متزامنة خفيفة جداً تمنع ارتفاع حرارة المعالج أو استنزاف البطارية.

---

## 3. طريقة استخدام متحكم سرعة بث نقطة الاتصال (Hotspot)
1. شغّل **نقطة اتصال الهواتف المحمولة (Hotspot)** من إعدادات هاتفك.
2. من داخل تطبيق Net Guard، اذهب للإعدادات وفعّل **«متحكم سرعة بث نقطة الاتصال»**، ثم اختر السرعة المطلوبة (مثلاً: `64 KB/s`).
3. في الجهاز المتصل (هاتف آخر أو لابتوب):
   - ادخل إلى إعدادات Wi-Fi > خيارات متقدمة > الوكيل (Proxy) > يدوي (Manual).
   - اسم مضيف الوكيل: `192.168.43.1`
   - المنفذ: `8282`
   - اضغط حفظ. سيعمل الإنترنت في الجهاز المتصل بالسرعة المحددة بالضبط!

---

## 4. المعمارية التقنية
```
┌─────────────────────────────────────────────────────────────┐
│                 Flutter Presentation Layer                  │
│       (Provider State Management + Modern Matte Theme)      │
│  - DashboardTab         - FirewallTab        - Settings     │
│  - UsageHistoryTab      - DnsSecurityTab     - HotspotModal │
└──────────────────────────────┬──────────────────────────────┘
                               │ MethodChannel Bridge
┌──────────────────────────────▼──────────────────────────────┐
│                    Android Native Engine                    │
│                      (Kotlin Coroutines)                    │
│  ┌─────────────────────────┐   ┌──────────────────────────┐ │
│  │     MyVpnService        │   │  NetworkMonitorService   │ │
│  │ (VPN Tunnel & Firewall) │   │ (Speed & Live Notif)     │ │
│  └─────────────────────────┘   └──────────────────────────┘ │
│  ┌─────────────────────────┐   ┌──────────────────────────┐ │
│  │   HotspotProxyServer    │   │      PackageReceiver     │ │
│  │ (Rate-Limited Tethering)│   │ (Auto Quarantine Engine) │ │
│  └─────────────────────────┘   └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. طريقة التثبيت والبناء
```bash
# 1. تنزيل الحزم
flutter pub get

# 2. فحص الكود
flutter analyze

# 3. بناء نسخة APK مخصصة للمعالجات
flutter build apk --split-per-abi

# 4. التثبيت على الهاتف عبر ADB
adb install -r -d build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 6. الأذونات المطلوبة وسبب طلبها

| الإذن | السبب والغرض |
| :--- | :--- |
| `BIND_VPN_SERVICE` | إنشاء نفق VPN محلي لتصفية وتحديد سرعة حزم البيانات دون خروجها من جهازك. |
| `PACKAGE_USAGE_STATS` | قراءة استهلاك كل تطبيق للبيانات لعرض الإحصائيات الدقيقة للمستخدم. |
| `POST_NOTIFICATIONS` | إظهار عداد السرعة الحي والاستهلاك في شريط الإشعارات بنظام أندرويد 13+. |
| `FOREGROUND_SERVICE` | استمرار المراقبة اللحظية للشبكة وحماية الباقة في الخلفية دون أن يغلقها النظام. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | ضمان استقرار خدمة جدار الحماية وعدم قتلها بواسطة موفر البطارية. |

---

## 7. حقوق الملكية والترخيص
**جميع الحقوق محفوظة © 2026 تطبيق Net Guard (حارس الإنترنت).**  
هذا التطبيق وكوده المصدري محمي بموجب قوانين الملكية الفكرية وحقوق النشر والتأليف. يُحظر تماماً نسخ أو توزيع أو تعديل أو إعادة بيع الكود لأي أغراض تجارية دون إذن كتابي وصريح مسبق من المطور. راجع ملف [LICENSE](LICENSE) للتفاصيل القانونية الكاملة.

---
---

# 🇬🇧 English Documentation

## 1. Overview
**Net Guard** is an advanced, production-grade network traffic management and security utility for Android. Built with a modern hybrid architecture (Flutter UI + Native Kotlin Engine), it combines a **Per-App Firewall**, a **Token-Bucket Bandwidth Throttler**, an independent **Hotspot Speed Controller**, and a **Monthly Data Plan Manager** — all without requiring root permissions (**No Root Required**) while maintaining zero battery drain.

---

## 2. Comprehensive Key Features

### 🛡️ Per-App Intelligent Firewall
- **Block or Whitelist:** Completely cut off or allow internet access for individual apps with a single tap.
- **Granular Wi-Fi vs. Mobile Data Control:** Manage network access independently for Wi-Fi and Cellular Data for every installed application.
- **Auto Quarantine Engine:** Newly installed apps are automatically quarantined to prevent covert background data consumption until explicitly approved.
- **Lockdown on Screen Off:** Automatically disables network connectivity for non-essential apps when the screen turns off, saving battery and preventing stealth updates.

### ⚡ Precise Bandwidth Throttling
- Configure exact Download and Upload speed limits globally or per application.
- Quick Presets:
  - **Eco Mode:** Ultra-bandwidth conservation mode, ideal for messaging and light communication.
  - **Normal Mode:** Balanced speed profile for smooth browsing without data exhaustion.
  - **Unlimited Mode:** Full network speed on demand.
- Powered by a mathematically accurate **Token-Bucket Rate Limiter** ensuring smooth transmission without connection drops.

### 📡 Hotspot / Tethering Speed Controller
- **Throttle Connected Devices:** Prevent connected phones, laptops, and tablets from draining your mobile data package.
- **Configurable Speed Limit Presets:**
  - **`64 KB/s` (Ultra Eco):** Perfect for WhatsApp text messaging and essential connectivity while strictly blocking heavy video streaming.
  - `128 KB/s` - `256 KB/s` - `512 KB/s` - `1 MB/s` - `2 MB/s` - `Unlimited (∞)`.
- **High-Performance Local Proxy Server:** Runs locally on port `8282` and functions completely independently from the device's VPN protection.

### 🔔 Smart Adaptive Live Notification
- Real-time download/upload speed meter and daily Wi-Fi & Mobile data usage counters.
- **System-Adaptive Day/Night Colors:**
  - Sharp, high-contrast black text (`#111111`) in **Light Mode**.
  - Crisp, pure white text (`#FFFFFF`) in **Dark Mode**.
- Clean, compact single-row design with no unnecessary expand chevrons or redundant buttons, featuring a fast inline toggle (`⚡ Start` / `🛑 Stop`).

### 🔒 Encrypted DNS & Content Filtering
- Built-in secure DNS providers:
  - **Cloudflare DNS (`1.1.1.1`):** Ultra-low latency encrypted resolution.
  - **AdGuard DNS (`94.140.14.14`):** Automatic ad-blocking, tracking protection, and malicious domain filtering.
  - **Google Public DNS (`8.8.8.8`):** High reliability and uptime.
- **Family Protection Shield:** One-tap filtering of adult, phishing, and malware domains.

### 📊 Monthly Data Quota & Spike Detection
- Set monthly data package limits with real-time remaining quotas and renewal countdown timers.
- Automatic limit enforcement: choose to throttle speed or disconnect upon quota expiration.
- **Data Spike Detector:** Immediate alerts if an app triggers an unexpected sudden data drain in the background.

### 🔋 Battery Optimization & Deep Sleep Support
- Background services automatically enter low-power sleep state when the screen is turned off.
- Non-polling asynchronous event hooks eliminate CPU thermal throttling and battery drain.

---

## 3. Hotspot Speed Controller Setup Guide
1. Enable **Mobile Hotspot** in your Android device system settings.
2. Open Net Guard Settings, toggle on **"Hotspot Speed Controller"**, and choose your target speed limit (e.g., `64 KB/s`).
3. On the connected device (guest phone or PC):
   - Go to Wi-Fi Settings > Advanced > Proxy > **Manual**.
   - Proxy Hostname: `192.168.43.1`
   - Proxy Port: `8282`
   - Save. The connected device will instantly browse at the throttled speed limit.

---

## 4. Technical Architecture
- **UI Layer:** Flutter with Provider state management and refined dark/light glassmorphic widgets.
- **Bridge:** Optimized binary MethodChannel passing raw primitives and pre-compressed Base64 assets.
- **VPN Core:** Native Kotlin `VpnService` with custom MTU tuning and packet filtering rules.
- **Speed Monitor:** `NetworkMonitorService` with `TrafficStats` and `NetworkStatsManager` daily usage tracking.
- **Hotspot Engine:** `HotspotProxyServer` with non-blocking socket pools and token-bucket rate limiting.

---

## 5. How to Build & Install
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run static analysis
flutter analyze

# 3. Build release APKs (split by ABI)
flutter build apk --split-per-abi

# 4. Install onto connected Android device
adb install -r -d build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 6. Required Android Permissions

| Permission | Purpose |
| :--- | :--- |
| `BIND_VPN_SERVICE` | Creates a local on-device VPN loopback to inspect, route, and throttle packets without remote servers. |
| `PACKAGE_USAGE_STATS` | Queries exact per-app daily data consumption statistics from Android kernel. |
| `POST_NOTIFICATIONS` | Displays the live persistent network speed indicator on Android 13+. |
| `FOREGROUND_SERVICE` | Guarantees continuous background traffic monitoring without OS task killer interruption. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Prevents aggressive OEM battery managers from freezing the firewall. |

---

## 7. Copyright & License
**Copyright © 2026 Net Guard. All Rights Reserved.**  
This software, including its source code, architecture, and design assets, is proprietary and confidential. Unauthorized copying, modification, reverse engineering, redistribution, or commercial use without prior written consent from the author is strictly prohibited. See [LICENSE](LICENSE) for full legal terms.
