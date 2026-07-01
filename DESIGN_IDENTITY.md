# Aarast / أعرست — Gemini Design Identity Guide

> هذا الملف مخصص لـ Gemini لتنفيذ هوية أعرست يدويًا وبوضوح داخل Flutter Mobile.  
> الهدف ليس ترقيع الشاشات، بل تطبيق هوية لونية وبصرية موحدة تشبه المرجع: **Soft Royal Wedding Identity**.

---

## 1. المهمة الأساسية

Gemini، المطلوب منك هو تحويل واجهة أعرست إلى منتج زفاف عربي ناعم وفاخر.

التطبيق يجب أن يبدو:

- عربي RTL أولًا.
- ناعم، فاخر، واضح، ومريح للعين.
- خلفيات عاجية/لؤلؤية.
- كروت بيضاء دافئة بحواف كبيرة.
- خمري ملكي للأزرار والهوية.
- ذهبي شامبين للتفاصيل الفاخرة فقط.
- ألوان دلالية واضحة للخطر/النجاح/التحذير.

الممنوع:

- لا Dark ثقيل.
- لا Neon.
- لا Cyberpunk.
- لا مربعات Material خام.
- لا رمادي ثقيل.
- لا ألوان عشوائية.
- لا تغيير Backend / APIs / Database.
- لا الاعتماد على ملفات Docs أو README قديمة كمصدر تصميم.

---

## 2. اسم الهوية الرسمية

```text
Aarast Soft Royal Wedding Identity
```

معناها:

```text
عاجي ناعم + أبيض دافئ + خمري ملكي + ذهبي شامبين + كروت فاخرة + تجربة عربية هادئة
```

---

## 3. لوحة الألوان الرسمية

### 3.1 الألوان الأساسية

| الدور | الاسم | HEX | الاستخدام |
|---|---:|---:|---|
| خلفية التطبيق الأساسية | Warm Ivory | `#FBF4EA` | خلفية أغلب الشاشات |
| خلفية ثانية ناعمة | Pearl Cream | `#FFF8EF` | أقسام داخلية وخلفيات خفيفة |
| سطح الكروت | Warm White | `#FFFFFF` | الكروت، الفورمات، البوتوم شيت |
| الهوية الرئيسية | Royal Burgundy | `#7A1F2B` | الأزرار، العناوين المهمة، العناصر النشطة |
| خمري عميق | Deep Burgundy | `#4A0F18` | النصوص القوية، الهيدر، السبلاتش |
| ذهبي شامبين | Champagne Gold | `#D8B26E` | تفاصيل فاخرة، حدود، أيقونات مميزة |
| نص رئيسي | Deep Ink | `#23181A` | العناوين والنصوص الأساسية |
| نص ثانوي | Muted Cocoa | `#75666A` | الوصف والنصوص المساعدة |
| حدود ناعمة | Soft Border | `#EADBC9` | حدود الكروت والحقول |

### 3.2 ألوان الحالات الدلالية

| الحالة | الاسم | HEX | القاعدة |
|---|---:|---:|---|
| نجاح / آمن | Safe Green | `#2E7D5B` | مكتمل، مؤكد، ضمن الميزانية |
| خلفية نجاح | Safe Green Soft | `#E8F4EE` | badge أو خلفية خفيفة |
| خطر / متأخر | Danger Red | `#B94A48` | تجاوز، متأخر، حذف، خطأ |
| خلفية خطر | Danger Red Soft | `#FCECEC` | تنبيه خطر خفيف |
| تحذير / قرب الخطر | Warning Gold | `#C9963E` | قرب تجاوز، أولوية، يحتاج انتباه |
| خلفية تحذير | Warning Gold Soft | `#FFF3D8` | badge تحذير أو كرت تنبيه |
| غير نشط | Disabled Gray | `#B9AEAA` | disabled فقط |
| خلفية فارغة | Empty Sand | `#F3E8DA` | empty states |

---

## 4. قواعد استخدام الألوان

### 4.1 قواعد صارمة

```text
الأحمر = خطر فقط.
الأخضر = نجاح أو أمان فقط.
الذهبي = فخامة أو أولوية أو تحذير فقط.
الخمري = هوية التطبيق والأزرار الأساسية.
الرمادي = ثانوي أو غير نشط فقط.
```

لا تستخدم الأحمر أو الأخضر كزخرفة.  
لا تستخدم الذهبي بكثرة حتى لا يصبح رخيصًا.  
لا تستخدم الخلفيات الداكنة إلا في Splash أو لحظة هوية قصيرة جدًا.

---

## 5. التطبيق حسب المكان داخل أعرست

### 5.1 الخلفيات العامة

| المكان | اللون |
|---|---|
| خلفية كل شاشة | `#FAF3E7` |
| تدرج ناعم أعلى الشاشة | `#FFF8EF` إلى `#FAF3E7` |
| خلفية داخل كرت أو فورم | `#FFFFFF` |
| خطوط فاصلة | `#EADBC9` |

### 5.2 الكروت

| العنصر | اللون/الشكل |
|---|---|
| Card background | `#FFFFFF` |
| Card border | `#EADBC9` بدرجة شفافة |
| Card radius | 22 إلى 28 |
| Card shadow | ظل خفيف دافئ، ليس رمادي ثقيل |
| Card title | `#23181A` |
| Card subtitle | `#75666A` |
| Card icon bg | `#FFF3D8` أو `#F3E8DA` |
| Card icon active | `#7A1F2B` أو `#D8B26E` |

### 5.3 الأزرار

| النوع | الخلفية | النص | ملاحظات |
|---|---:|---:|---|
| Primary CTA | `#7A1F2B` | `#FFFFFF` | زر أساسي واحد واضح |
| Primary pressed | `#4A0F18` | `#FFFFFF` | عند الضغط |
| Secondary CTA | `#FFFFFF` | `#7A1F2B` | مع border `#EADBC9` |
| Gold CTA خفيف | `#FFF3D8` | `#7A1F2B` | للأولوية أو اقتراح ذكي |
| Danger CTA | `#B94A48` | `#FFFFFF` | حذف/إلغاء خطير فقط |
| Disabled CTA | `#E6DDD4` | `#B9AEAA` | غير نشط |

### 5.4 حقول الإدخال Forms

| العنصر | اللون |
|---|---|
| Input background | `#FFFFFF` |
| Input border idle | `#EADBC9` |
| Input focused border | `#7A1F2B` |
| Label | `#23181A` |
| Hint | `#9C8D86` |
| Helper text | `#75666A` |
| Error border | `#B94A48` |
| Error background | `#FCECEC` |
| Cursor | `#7A1F2B` |

### 5.5 الفلاتر Chips

| الحالة | الخلفية | النص | الحدود |
|---|---:|---:|---:|
| غير محدد | `#FFFFFF` | `#75666A` | `#EADBC9` |
| محدد | `#7A1F2B` | `#FFFFFF` | `#7A1F2B` |
| تحذير | `#FFF3D8` | `#7A1F2B` | `#D8B26E` |
| خطر | `#FCECEC` | `#B94A48` | `#B94A48` |
| نجاح | `#E8F4EE` | `#2E7D5B` | `#2E7D5B` |

### 5.6 Bottom Sheet

| العنصر | اللون/الشكل |
|---|---|
| Sheet background | `#FFF8EF` أو `#FFFFFF` |
| Top handle | `#EADBC9` |
| Title | `#23181A` |
| Description | `#75666A` |
| Primary action | `#7A1F2B` |
| Danger action | `#B94A48` |
| Radius | أعلى 28 إلى 32 |

### 5.7 Navigation / Bottom Bar

| العنصر | اللون |
|---|---|
| Bottom nav background | `#FFFFFF` مع شفافية خفيفة |
| Active icon | `#7A1F2B` |
| Active label | `#7A1F2B` |
| Inactive icon | `#B9AEAA` |
| Inactive label | `#9C8D86` |
| Active pill/bg | `#F3E8DA` أو `#FFF3D8` |
| FAB background | `#7A1F2B` |
| FAB icon | `#FFFFFF` |
| FAB glow | `#D8B26E` شفاف جدًا |

---

## 6. الألوان حسب الشاشة

### 6.1 Splash / Welcome

| العنصر | اللون |
|---|---|
| Native splash background | `#4A0F18` أو `#7A1F2B` |
| App splash background | تدرج `#4A0F18` إلى `#7A1F2B` |
| شعار أعرست | `#FFFFFF` |
| تفاصيل الشعار | `#D8B26E` |
| Loader | `#D8B26E` |
| Welcome screen background | `#FAF3E7` |
| Welcome cards | `#FFFFFF` |
| Selected path | `#7A1F2B` |

### 6.2 Home / Dashboard

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Plan hero card | تدرج ناعم `#7A1F2B` إلى `#4A0F18` أو كرت أبيض بحد خمري |
| Hero text | `#FFFFFF` إذا الخلفية خمرية، أو `#23181A` إذا أبيض |
| Progress ring | `#D8B26E` + track `#EADBC9` |
| Smart action card | `#FFFFFF` |
| Priority highlight | `#FFF3D8` |
| Money safe | `#2E7D5B` |
| Money danger | `#B94A48` |
| Task warning | `#C9963E` |

### 6.3 Money / Budget

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Main budget card | `#FFFFFF` |
| Budget gauge safe | `#2E7D5B` |
| Budget gauge warning | `#C9963E` |
| Budget gauge danger | `#B94A48` |
| Remaining amount | `#2E7D5B` إذا آمن |
| Spent amount | `#7A1F2B` |
| Debt amount | `#B94A48` أو `#C9963E` حسب الحالة |
| Category cards | `#FFFFFF` + border `#EADBC9` |
| Add expense CTA | `#7A1F2B` |

### 6.4 Tasks

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Today task | `#FFF3D8` badge |
| Late task | `#FCECEC` + `#B94A48` |
| Done task | `#E8F4EE` + `#2E7D5B` |
| Upcoming task | `#FFFFFF` + `#D8B26E` icon |
| Priority badge | `#C9963E` |
| Task card | `#FFFFFF` |
| Checkbox active | `#7A1F2B` أو `#2E7D5B` عند الإنجاز |

### 6.5 Guests

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Confirmed | `#E8F4EE` + `#2E7D5B` |
| Pending | `#FFF3D8` + `#C9963E` |
| Declined | `#FCECEC` + `#B94A48` |
| Guest card | `#FFFFFF` |
| Family/group card accent | `#D8B26E` |
| Add guest CTA | `#7A1F2B` |

### 6.6 Providers

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Search field | `#FFFFFF` |
| Provider card | `#FFFFFF` |
| Provider category badge | `#FFF3D8` + `#7A1F2B` |
| Rating/trust | `#D8B26E` |
| Available | `#2E7D5B` |
| Unavailable/error | `#B94A48` |
| Request quote CTA | `#7A1F2B` |
| Error state card | `#FFFFFF` + icon `#B94A48` + message ناعم |

### 6.7 Plan Center

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Plan hero | `#FFFFFF` أو تدرج خمري ناعم |
| Timeline active | `#7A1F2B` |
| Timeline completed | `#2E7D5B` |
| Timeline warning | `#C9963E` |
| Timeline danger | `#B94A48` |
| Section cards | `#FFFFFF` |
| Next action | `#7A1F2B` |

### 6.8 Sharing / Participants

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Member card | `#FFFFFF` |
| Owner badge | `#7A1F2B` + `#FFFFFF` |
| Participant badge | `#FFF3D8` + `#7A1F2B` |
| Pending invite | `#FFF3D8` + `#C9963E` |
| Accepted | `#E8F4EE` + `#2E7D5B` |
| Auth gate | كرت أبيض + icon خمري |

### 6.9 Notifications

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Notification card | `#FFFFFF` |
| Important notification | `#FFF3D8` + `#C9963E` |
| Error/late notification | `#FCECEC` + `#B94A48` |
| Success notification | `#E8F4EE` + `#2E7D5B` |
| Empty state | `#FFFFFF` + icon `#D8B26E` |

### 6.10 Settings / More / Profile

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Profile summary card | `#FFFFFF` |
| Avatar background | `#FFF3D8` |
| Avatar icon/text | `#7A1F2B` |
| Settings row | `#FFFFFF` |
| Active switch | `#7A1F2B` |
| Logout / danger | `#B94A48` |

### 6.11 All Create/Edit Forms

ينطبق على:

- إنشاء مصروف.
- إنشاء مهمة.
- إنشاء ضيف.
- إنشاء دين.
- إنشاء قسط.
- إنشاء خطة.
- تعديل أي بيانات.

| العنصر | اللون |
|---|---|
| Background | `#FAF3E7` |
| Form card | `#FFFFFF` |
| Section header | `#23181A` |
| Section icon bg | `#FFF3D8` |
| Section icon | `#7A1F2B` |
| Input background | `#FFFFFF` |
| Focus border | `#7A1F2B` |
| Error border | `#B94A48` |
| Submit button | `#7A1F2B` |
| Cancel button | `#FFFFFF` + text `#7A1F2B` |

---

## 12. أسماء Tokens المقترحة في Flutter

```dart
static const Color ivory = Color(0xFFFBF4EA);
static const Color pearl = Color(0xFFFFF8EF);
static const Color surface = Color(0xFFFFFFFF);
static const Color burgundy = Color(0xFF7A1F2B);
static const Color burgundyDark = Color(0xFF4A0F18);
static const Color gold = Color(0xFFD8B26E);
static const Color warning = Color(0xFFC9963E);
static const Color danger = Color(0xFFB94A48);
static const Color dangerSoft = Color(0xFFFCECEC);
static const Color success = Color(0xFF2E7D5B);
static const Color successSoft = Color(0xFFE8F4EE);
static const Color ink = Color(0xFF23181A);
static const Color muted = Color(0xFF75666A);
static const Color border = Color(0xFFEADBC9);
static const Color empty = Color(0xFFF3E8DA);
static const Color disabled = Color(0xFFB9AEAA);
```

---

## 13. المعيار النهائي

بعد تطبيق الهوية، أي شاشة تُفتح في أعرست يجب أن تعطي هذا الانطباع:

```text
هادئة، فاخرة، عربية، واضحة، ناعمة، ومنتظمة.
```
