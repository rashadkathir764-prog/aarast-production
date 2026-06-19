# Aarast Data Seeding Plan

Date: 2026-06-19
Stage: Data Seeding
Status: Planning document only

## 1. Decision

Aarast needs curated Yemen-first seed data before onboarding, provider matching, budget presets, and task templates can feel useful.

This document does not create seed scripts or modify database data.

## 2. Seed Groups

Required groups:

- Yemen governorates.
- Main cities/districts.
- Initial neighborhoods gradually.
- Provider categories.
- Budget categories.
- Onboarding priorities.
- Task templates.
- Empty state messages.
- Notification templates.
- Provider status copy.

## 3. Location Seeds

Start with:

- صنعاء.
- عدن.
- تعز.
- الحديدة.
- إب.
- ذمار.
- حضرموت / المكلا.
- مأرب.
- إب/يريم and other high-signal districts later.

Rules:

- Keep Arabic names primary.
- English names optional.
- Use stable slugs/keys if needed.
- Do not require map coordinates in first seed.

## 4. Budget Category Seeds

Initial categories:

- القاعة.
- المطعم / العشاء.
- التصوير.
- الكوشة.
- الفستان.
- البدلة.
- الذهب.
- الحناء.
- الزفة.
- الدعوات.
- النقل.
- الضيافة.
- شهر العسل.
- تجهيز البيت.
- الطوارئ.

## 5. Provider Category Seeds

Initial provider categories:

- قاعات.
- مطاعم وضيافة.
- تصوير.
- كوش وأزهار.
- فساتين.
- بدلات.
- ذهب.
- حناء.
- زفات.
- دعوات.
- نقل.
- تجهيز بيت.

## 6. Onboarding Priority Seeds

- الميزانية والمصاريف.
- الديون والأقساط.
- المهام والمواعيد.
- الضيوف.
- الموردين القريبين.
- مشاركة الخطة مع العائلة.

## 7. Notification Template Seeds

- task_due_today.
- task_overdue.
- installment_due.
- installment_overdue.
- budget_exceeded.
- quote_received.
- member_joined.
- permission_changed.
- sync_failed.

## 8. Seed Quality Rules

- Seeds should be reviewable Markdown/JSON before DB load.
- Avoid fake provider data in production.
- Demo providers must be clearly demo/local-only.
- Never seed payment/deposit/loan/financing behavior.
- Seeds must support Arabic copy matrix.

## 9. Acceptance Criteria

- Required seed groups are listed.
- Initial location, budget, provider category, priority, and notification templates are documented.
- Seed quality rules are documented.
- No seed scripts, database writes, or migrations are created.

## 10. Risks

- Weak location seeds make provider matching feel random.
- Fake provider data can look like real marketplace launch.
- Poor category seeds create confusing budget setup.

## 11. Next Implementation Notes

- Next stage: `docs/data/TASK_TEMPLATES.md`.
- Future seed implementation must include QA data source review.

