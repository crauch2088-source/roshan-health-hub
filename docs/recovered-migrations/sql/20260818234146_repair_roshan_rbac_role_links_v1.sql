UPDATE public.users u
SET role_id = r.id
FROM public.roles old_r
JOIN public.roles r ON r.code = CASE
  WHEN old_r.name = 'Reception' THEN 'receptionist'
  WHEN old_r.name = 'GP' THEN 'doctor'
  WHEN old_r.name = 'Pharmacist' THEN 'pharmacist'
  WHEN old_r.name = 'Lab Assistant' THEN 'lab_tech'
END
WHERE u.role_id = old_r.id
  AND old_r.name IN ('Reception','GP','Pharmacist','Lab Assistant');

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r CROSS JOIN public.permissions p
WHERE r.code = 'doctor'
  AND p.code IN ('dashboard.read','appointments.read','appointments.update','patients.create','patients.read','patients.update','visits.create','visits.read','visits.update','emr.create','emr.read','emr.update','emr.delete','followups.create','followups.read','followups.update','lab.create','lab.read','procedures.create','procedures.read','certificates.create','certificates.read','certificates.update','queue.read','queue.update')
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r CROSS JOIN public.permissions p
WHERE r.code = 'receptionist'
  AND p.code IN ('dashboard.read','appointments.create','appointments.read','appointments.update','appointments.delete','patients.create','patients.read','patients.update','visits.create','visits.read','queue.create','queue.read','queue.update','billing.create','billing.read','billing.update','payments.create','payments.read')
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r CROSS JOIN public.permissions p
WHERE r.code = 'lab_tech'
  AND p.code IN ('dashboard.read','patients.read','lab.create','lab.read','lab.update','queue.read')
ON CONFLICT DO NOTHING;

-- Preserve the existing pharmacist permission set and add prescription access only if those permission codes exist.
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r CROSS JOIN public.permissions p
WHERE r.code = 'pharmacist'
  AND p.code IN ('prescriptions.read','prescriptions.create')
ON CONFLICT DO NOTHING;
