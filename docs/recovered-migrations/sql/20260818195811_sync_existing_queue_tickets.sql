update public.queue_tickets q
set queue_number = 'Q' || v.queue_number::text,
    visit_date = v.queue_date,
    patient_id = v.patient_id,
    department_id = v.department_id
from public.visits v
where q.visit_id = v.id
  and v.deleted_at is null
  and v.queue_number is not null;
