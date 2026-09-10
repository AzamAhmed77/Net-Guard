# سياسة الخصوصية لتطبيق Net Guard (Privacy Policy)

**تاريخ آخر تحديث:** 11 سبتمبر 2026

تلتزم شركة / مطور **Net Guard** بحماية خصوصية وأمان مستخدميها بأعلى المعايير العالمية. توضح هذه السياسة كيف يتعامل تطبيق Net Guard مع بياناتك، وتؤكد التزامنا الصارم بمبدأ **"الخصوصية أولاً" (Privacy-First)** وعدم جمع أو مشاركة أي بيانات شخصية أو بيانات تصفح.

---

### 1. ما هي البيانات التي نجمعها؟
**نحن لا نجمع أي بيانات شخصية إطلاقاً.**
- لا نطلب تسجيل الدخول أو إنشاء حساب (لا بريد إلكتروني، لا رقم هاتف، ولا اسم).
- لا نجمع، ولا نخزن، ولا نشارك أي سجلات تصفح (No Logs Policy).
- لا نقوم بجمع أو تسجيل عناوين IP التي تتصل بها، أو أسماء المواقع أو التطبيقات التي تستخدمها.

---

### 2. كيف يعمل إذن خدمة الشبكة الافتراضية (VpnService)؟
يستخدم تطبيق Net Guard واجهة أندرويد الرسمية `android.net.VpnService` للوظائف الأساسية التالية فقط:
1. **تحديد السرعة (Speed Throttling):** ضبط استهلاك سرعة التحميل والرفع للتطبيقات للحد من استنزاف الباقة.
2. **الجدار الناري (Firewall):** منع تطبيقات يحددها المستخدم من الوصول إلى شبكة الواي فاي أو بيانات الهاتف.
3. **تشفير استعلامات DNS (DoH) ودرع تسريب IPv6:** حماية تصفح المستخدم من التجسس وتوجيه استعلامات الـ DNS عبر قنوات مشفرة آمنة.
4. **حجب الإعلانات والمحتوى الضار:** تصفية العناوين محلياً على هاتفك.

> **إعلان هام لسياسة Google Play:**
> تعمل خدمة الـ VPN في تطبيق Net Guard كـ **"نفق محلي داخل جهازك فقط" (Local On-Device Loopback)**. جميع حزم البيانات يتم فحصها وفلترتها محلياً داخل معالج هاتفك، **ولا يتم توجيه أو بيع أو إرسال أي حركة بيانات (Traffic) إلى أي خوادم خارجية تابعة لنا**.

---

### 3. إحصائيات استهلاك البيانات (Data Usage Stats)
يقرأ التطبيق إحصائيات استهلاك البيانات للتطبيقات عبر واجهة النظام الرسمية `NetworkStatsManager` لعرض حجم الميجابايت المستهلكة اليوم والشهر داخل واجهة التطبيق فقط. هذه الإحصائيات تظل محفوظة محلياً في ذاكرة هاتفك ولا يتم إرسالها إلى أي خادم خارجي.

---

### 4. الإعلانات والجهات الخارجية
تطبيق Net Guard خالٍ تماماً من حزم التتبع الإعلاني الخارجية (Third-party Trackers)، ولا يشارك أي بيانات مع شركات الإعلانات.

---

### 5. أمان البيانات (Data Security)
نظراً لأن جميع العمليات تتم محلياً 100% داخل نظام هاتفك المشفر، فإن بياناتك محمية بطبيعتها بأعلى مستويات حماية نظام أندرويد المعمول بها.

---

### 6. التواصل والدعم
إذا كانت لديك أي استفسارات أو أسئلة حول سياسة الخصوصية، يمكنك التواصل معنا عبر:
- **البريد الإلكتروني للدعم:** AzamAhemdAli2@gmail.com
- **الموقع / المستودع:** https://github.com/AzamAhmed77/Net-Guard

---
---

# Privacy Policy for Net Guard

**Last Updated:** September 11, 2026

**Net Guard** is committed to protecting your privacy with the highest security standards. This Privacy Policy explains how our application operates and affirms our strict **Privacy-First** architecture.

---

### 1. Information We Collect
**We do NOT collect, transmit, or store any personal data.**
- No account registration is required (no email, name, or phone number).
- We maintain a strict **No-Logs Policy**: we never track, inspect, or log your browsing history, visited websites, or application network traffic.

---

### 2. Use of Android VpnService
Net Guard utilizes Android’s standard `android.net.VpnService` strictly for on-device network management:
1. **Per-App Speed Throttling:** Regulating upload/download speeds to prevent bandwidth exhaustion.
2. **On-Device Firewall:** Allowing or restricting specific apps from accessing Wi-Fi or Mobile Data as selected by the user.
3. **Encrypted DNS (DoH) & IPv6 Leak Protection:** Securing DNS queries against eavesdropping and preventing IPv6 bypass leaks.
4. **Ad & Tracker Blocking:** Filtering blacklisted hostnames locally on your device.

> **Google Play VpnService Compliance Disclosure:**
> The VPN tunnel operates exclusively as a **local loopback on the user's device**. All packet inspection, rate-limiting, and firewall filtering are executed entirely on-device. **We do not route, tunnel, or sell any of your network traffic to remote proxy servers.**

---

### 3. Data Usage Statistics
Net Guard queries Android’s `NetworkStatsManager` API to display live and daily data consumption in the notification bar and in-app charts. This data remains solely stored on your local device storage.

---

### 4. Contact Us
For any inquiries regarding this policy, please reach out at:
- **Support Email:** AzamAhemdAli2@gmail.com
- **GitHub Repository:** https://github.com/AzamAhmed77/Net-Guard
