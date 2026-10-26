-- Scale seed: clones Mohammed's whole wedding (owner, three members, plan,
-- money, guests, tasks, notifications, contributor history) N times.
-- Every id that belongs to the cloned set gets the suffix _s<n>; references
-- to rows outside the set (providers, cities, catalogs) stay as they are.
\set ON_ERROR_STOP on
set synchronous_commit = off;

drop table if exists _src;
create temp table _src (tbl text, id text);
insert into _src select 'User', id from "User" where id in
  ('demo_user_groom','demo_user_helperSaleh','demo_user_viewerFather','demo_user_bride');
insert into _src select 'WeddingPlan', id from "WeddingPlan" where id = 'demo_plan_groom';
insert into _src select t, id from (
  select 'SharedMember' t, id from "SharedMember" where "weddingPlanId"='demo_plan_groom'
  union all select 'BudgetCategory', id from "BudgetCategory" where "weddingPlanId"='demo_plan_groom'
  union all select 'WeddingCost', id from "WeddingCost" where "weddingPlanId"='demo_plan_groom'
  union all select 'FundingSource', id from "FundingSource" where "weddingPlanId"='demo_plan_groom'
  union all select 'GuestGroup', id from "GuestGroup" where "weddingPlanId"='demo_plan_groom'
  union all select 'Guest', id from "Guest" where "weddingPlanId"='demo_plan_groom'
  union all select 'WeddingTask', id from "WeddingTask" where "weddingPlanId"='demo_plan_groom'
  union all select 'Notification', id from "Notification" where "userId" in ('demo_user_groom','demo_user_helperSaleh','demo_user_viewerFather')
  union all select 'ContributorHistoryScope', id from "ContributorHistoryScope" where "weddingPlanId"='demo_plan_groom'
) x;
insert into _src select 'CostPayment', id from "CostPayment" where "weddingCostId" in (select id from _src where tbl='WeddingCost');
insert into _src select 'PaymentSchedule', id from "PaymentSchedule" where "weddingCostId" in (select id from _src where tbl='WeddingCost');
insert into _src select 'LoanRepayment', id from "LoanRepayment" where "fundingSourceId" in (select id from _src where tbl='FundingSource');
insert into _src select 'WeddingTaskChecklistItem', id from "WeddingTaskChecklistItem" where "taskId" in (select id from _src where tbl='WeddingTask');
insert into _src select 'ContributorTenure', id from "ContributorTenure" where "historyScopeId" in (select id from _src where tbl='ContributorHistoryScope');
insert into _src select 'ContributionEvent', id from "ContributionEvent" where "historyScopeId" in (select id from _src where tbl='ContributorHistoryScope');
create index on _src(id);
create index on _src(tbl);
analyze _src;
select tbl, count(*) from _src group by 1 order by 1;

create or replace function pg_temp.clone(tbl text, n_from int, n_to int) returns void language plpgsql as $$
declare cols text; exprs text; r record;
begin
  cols := ''; exprs := '';
  for r in select column_name, data_type, udt_name from information_schema.columns
           where table_schema='public' and table_name=tbl order by ordinal_position loop
    cols := cols || format('%I,', r.column_name);
    if r.column_name = 'id' then
      exprs := exprs || 's.id || ''_s'' || n,';
    elsif tbl = 'User' and r.column_name = 'phone' then
      exprs := exprs || '''+9677'' || right(s.phone, 1) || lpad(n::text, 7, ''0''),';
    elsif r.data_type = 'character' and r.column_name in ('rsvpTokenHash','dedupeKey','eventFingerprint') then
      exprs := exprs || format('case when s.%1$I is null then null else md5(s.%1$I || n) || md5(n || s.%1$I) end,', r.column_name);
    elsif r.column_name in ('rsvpTokenHash','dedupeKey','storageKey','eventFingerprint') then
      exprs := exprs || format('case when s.%1$I is null then null else s.%1$I || ''_s'' || n end,', r.column_name);
    elsif tbl = 'WeddingCost' and r.column_name = 'quoteOfferId' then
      exprs := exprs || 'null,';
    elsif r.data_type = 'text' then
      exprs := exprs || format('case when s.%1$I in (select id from _src) then s.%1$I || ''_s'' || n else s.%1$I end,', r.column_name);
    else
      exprs := exprs || format('s.%I,', r.column_name);
    end if;
  end loop;
  execute format('insert into %I (%s) select %s from %I s cross join generate_series(%s,%s) n where s.id in (select id from _src where tbl=%L)',
    tbl, rtrim(cols, ','), rtrim(exprs, ','), tbl, n_from, n_to, tbl);
end $$;

-- The owner's active plan points at the plan; insert users without it first.
set session_replication_role = replica;
select pg_temp.clone(t, :A, :B) from unnest(array['User','WeddingPlan',
  'SharedMember','BudgetCategory','FundingSource','GuestGroup','WeddingCost',
  'PaymentSchedule','CostPayment','LoanRepayment','Guest','WeddingTask',
  'WeddingTaskChecklistItem','Notification','ContributorHistoryScope',
  'ContributorTenure','ContributionEvent']) with ordinality u(t, o) order by o;
set session_replication_role = origin;
analyze;
select relname, n_live_tup from pg_stat_user_tables order by 2 desc limit 15;
