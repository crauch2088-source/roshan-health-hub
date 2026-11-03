-- Read-only audit aggregate. Set psql variables before running:
--   \set from_ts '2026-10-01 00:00:00+00'
--   \set to_ts   '2026-11-01 00:00:00+00'
--   \set branch_id ''  -- empty means all branches; otherwise a UUID
--
-- Counts only. Never expose audit_logs.old_data/new_data in routine dashboards.
-- Branch-filtered output excludes rows without an explicit branch_id snapshot.

WITH params AS (
  SELECT :'from_ts'::timestamptz AS from_ts,
         :'to_ts'::timestamptz AS to_ts,
         NULLIF(:'branch_id','')::uuid AS branch_id
),
scoped AS (
  SELECT a.created_at,a.table_name,a.action,a.user_id,a.record_id,
    COALESCE(NULLIF(a.new_data->>'branch_id','')::uuid,
             NULLIF(a.old_data->>'branch_id','')::uuid) AS event_branch_id
  FROM public.audit_logs a CROSS JOIN params p
  WHERE a.created_at>=p.from_ts AND a.created_at<p.to_ts
    AND (p.branch_id IS NULL OR COALESCE(
      NULLIF(a.new_data->>'branch_id','')::uuid,
      NULLIF(a.old_data->>'branch_id','')::uuid
    )=p.branch_id)
)
SELECT date_trunc('day',s.created_at)::date AS audit_day,
       s.table_name,s.action,s.user_id,
       count(*) AS event_count,
       count(DISTINCT s.record_id) AS distinct_records
FROM scoped s
GROUP BY date_trunc('day',s.created_at)::date,s.table_name,s.action,s.user_id
ORDER BY audit_day DESC,s.table_name,s.action,s.user_id;
