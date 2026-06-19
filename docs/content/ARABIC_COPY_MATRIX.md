# Aarast Arabic Copy Matrix

Date: 2026-06-19
Stage: Content System
Status: Planning document only

## 1. Decision

Arabic copy must be structured by context and persona. Do not scatter important product copy randomly inside widgets during the rebuild.

## 2. Personas

- Groom: masculine direct tone.
- Bride: feminine direct tone.
- Helper: supportive contributor tone.
- Provider: business/service tone.
- Neutral: used before persona selection.

## 3. Copy Rules

- Keep text short.
- Use Yemeni-friendly Arabic without heavy jargon.
- Explain why account/permission is needed.
- Use action-oriented empty states.
- Avoid promising payment, booking confirmation, AI, financing, or provider guarantees.
- Sensitive financial copy must be privacy-aware.

## 4. Matrix

| Context | Groom | Bride | Helper | Provider |
|---|---|---|---|---|
| Welcome | ألف مبروك، خلينا نرتب زفافك خطوة بخطوة. | ألف مبروك، خلينا نرتب زفافكِ خطوة بخطوة. | خلينا نساعد في ترتيب الخطة خطوة بخطوة. | خلينا نجهز ملف خدمتك ونوصلك بطلبات مناسبة. |
| Budget CTA | أضف ميزانيتك التقريبية. | أضيفي ميزانيتكِ التقريبية. | ساعد في ضبط الميزانية. | حدد نطاق أسعار خدماتك. |
| Wedding date | حدد موعد الزواج. | حددي موعد الزفاف. | تابع موعد الخطة. | حدد توفرك للطلبات. |
| Empty tasks | لا توجد مهام بعد. أضف أول مهمة. | لا توجد مهام بعد. أضيفي أول مهمة. | لا توجد مهام مسندة بعد. | لا توجد طلبات متابعة بعد. |
| Add expense | إضافة مصروف | إضافة مصروف | تسجيل مصروف للخطة | غير متاح للمزود |
| Request quote | اطلب عرض سعر | اطلبي عرض سعر | اطلب عرضاً نيابة عن الخطة | راجع طلبات الأسعار |
| Share plan | شارك الخطة مع شخص تثق به. | شاركي الخطة مع شخص تثقين به. | أضف من يساعدك في المتابعة. | غير متاح للمزود |
| Auth gate quote | نحتاج حساباً لإرسال طلبك للمورد. | نحتاج حساباً لإرسال طلبكِ للمورد. | نحتاج حساباً لحفظ الطلب ومتابعته. | سجل الدخول لمتابعة طلباتك. |
| Finance locked | البيانات المالية خاصة وتحتاج صلاحية. | البيانات المالية خاصة وتحتاج صلاحية. | اطلب صلاحية مالية من مالك الخطة. | غير متاح للمزود. |
| Sync pending | التغيير محفوظ على الجهاز وينتظر المزامنة. | التغيير محفوظ على الجهاز وينتظر المزامنة. | التغيير بانتظار المزامنة. | التغيير بانتظار الاتصال. |

## 5. Content Keys Direction

Suggested key pattern:

```text
onboarding.welcome.title
onboarding.persona.groom
authGate.quote.body
money.empty.title
tasks.empty.body
sharing.permission.financeLocked
provider.status.pendingReview
```

## 6. Sensitive Copy Rules

- Do not say "تم الحجز" unless confirmed booking is approved.
- Do not say "ادفع" or "دفعة" as payment processing.
- Use "عرض سعر" not "شراء".
- Use "مورد محفوظ" not "مورد مؤكد" unless plan provider flow exists.
- Use "قيد المراجعة" for provider application.

## 7. Acceptance Criteria

- Personas are defined.
- Copy rules are documented.
- Initial copy matrix is documented.
- Content key direction is documented.
- Sensitive copy rules are documented.
- No app copy/code is changed.

## 8. Risks

- Hardcoded copy will drift across screens.
- Wrong gender/persona tone can feel careless.
- Provider/payment language can imply unsupported commitments.
- Long text can break compact mobile UI.

## 9. Next Implementation Notes

- Next stage: `docs/data/SEEDING_PLAN.md`.
- Future implementation should introduce structured copy constants before broad UI rewrite.

