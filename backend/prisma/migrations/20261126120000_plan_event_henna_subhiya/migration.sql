-- Q-58 (أ, D127): a bride wrote her henna night and «الصبحية» by hand as
-- «مناسبة ثانية». They are kinds of their own, suggested in her plan: the
-- henna night before her party, «الصبحية» after the wedding. Additive; no
-- row uses them in this migration (a new enum value is usable only after
-- its transaction commits). Like every kind but CUSTOM, each is once per
-- plan (the partial unique index "PlanEvent_one_per_type" covers them).

-- AlterEnum
ALTER TYPE "PlanEventType" ADD VALUE 'HENNA' BEFORE 'CUSTOM';
ALTER TYPE "PlanEventType" ADD VALUE 'SUBHIYA' BEFORE 'CUSTOM';
