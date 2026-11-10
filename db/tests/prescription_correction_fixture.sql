-- Synthetic PostgreSQL 17 fixture for the prescription correction workflow.
-- Disposable CI only; no hosted project is touched.
BEGIN;

INSERT INTO public.branches (id, branch_code, branch_name, name, code, active, is_active)
VALUES
 ('92000000-0000-0000-0000-000000000001','CORR-A','Correction Branch A','Correction Branch A','CORR-A',true,true),
 ('92000000-0000-0000-0000-000000000002','CORR-B','Correction Branch B','Correction Branch B','CORR-B',true,true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.roles (name, code)
SELECT v.name, v.code
FROM (VALUES
 ('Doctor','doctor'),
 ('Pharmacist','pharmacist'),
 ('Admin','admin'),
 ('Super Admin','super_admin')
) AS v(name,code)
WHERE NOT EXISTS (SELECT 1 FROM public.roles r WHERE r.code=v.code);

INSERT INTO public.permissions (code,name,module,action)
SELECT v.code,v.name,v.module,v.action
FROM (VALUES
 ('emr.create','EMR create','emr','create'),
 ('emr.read','EMR read','emr','read'),
 ('emr.update','EMR update','emr','update'),
 ('visits.read','Visits read','visits','read'),
 ('visits.update','Visits update','visits','update'),
 ('pharmacy.create','Pharmacy create','pharmacy','create'),
 ('pharmacy.read','Pharmacy read','pharmacy','read'),
 ('pharmacy.update','Pharmacy update','pharmacy','update')
) AS v(code,name,module,action)
WHERE NOT EXISTS (SELECT 1 FROM public.permissions p WHERE p.code=v.code);

INSERT INTO public.role_permissions (role_id,permission_id)
SELECT r.id,p.id
FROM public.roles r
JOIN public.permissions p ON
  (r.code='doctor' AND p.code IN ('emr.create','emr.read','emr.update','visits.read','visits.update'))
  OR (r.code='pharmacist' AND p.code IN ('pharmacy.create','pharmacy.read','pharmacy.update'))
  OR (r.code='admin' AND p.code IN ('emr.create','emr.read','emr.update','visits.read','visits.update','pharmacy.create','pharmacy.read','pharmacy.update'))
WHERE NOT EXISTS (
  SELECT 1 FROM public.role_permissions rp
  WHERE rp.role_id=r.id AND rp.permission_id=p.id
);

INSERT INTO auth.users (id) VALUES
 ('90000000-0000-0000-0000-000000000001'),
 ('90000000-0000-0000-0000-000000000002'),
 ('90000000-0000-0000-0000-000000000003'),
 ('90000000-0000-0000-0000-000000000004'),
 ('90000000-0000-0000-0000-000000000005'),
 ('90000000-0000-0000-0000-000000000006'),
 ('90000000-0000-0000-0000-000000000007')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.users (id,branch_id,role_id,full_name,auth_user_id,active)
SELECT v.id,v.branch_id,r.id,v.full_name,v.auth_user_id,true
FROM (VALUES
 ('91000000-0000-0000-0000-000000000001'::uuid,'92000000-0000-0000-0000-000000000001'::uuid,'doctor','Responsible Doctor A','90000000-0000-0000-0000-000000000001'::uuid),
 ('91000000-0000-0000-0000-000000000002'::uuid,'92000000-0000-0000-0000-000000000001'::uuid,'doctor','Unrelated Doctor A','90000000-0000-0000-0000-000000000002'::uuid),
 ('91000000-0000-0000-0000-000000000003'::uuid,'92000000-0000-0000-0000-000000000002'::uuid,'doctor','Doctor B','90000000-0000-0000-0000-000000000003'::uuid),
 ('91000000-0000-0000-0000-000000000004'::uuid,'92000000-0000-0000-0000-000000000001'::uuid,'pharmacist','Pharmacist A','90000000-0000-0000-0000-000000000004'::uuid),
 ('91000000-0000-0000-0000-000000000005'::uuid,'92000000-0000-0000-0000-000000000002'::uuid,'pharmacist','Pharmacist B','90000000-0000-0000-0000-000000000005'::uuid),
 ('91000000-0000-0000-0000-000000000006'::uuid,'92000000-0000-0000-0000-000000000001'::uuid,'admin','Admin A','90000000-0000-0000-0000-000000000006'::uuid),
 ('91000000-0000-0000-0000-000000000007'::uuid,'92000000-0000-0000-0000-000000000001'::uuid,'super_admin','Super Admin A','90000000-0000-0000-0000-000000000007'::uuid)
) AS v(id,branch_id,role_code,full_name,auth_user_id)
JOIN public.roles r ON r.code=v.role_code
WHERE NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id=v.id);

INSERT INTO public.patients (id,branch_id,full_name,gender)
VALUES
 ('93000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','Correction Patient A','male'),
 ('93000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000002','Correction Patient B','female')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.visits (id,branch_id,patient_id,doctor_id,status)
VALUES
 ('94000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001','waiting'),
 ('94000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000002','93000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000003','waiting')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.medicines (id,generic_name,name,brand_name,strength,dosage_form,selling_price,cost_price,active,is_active,stock_quantity)
VALUES
 ('95000000-0000-0000-0000-000000000001','Amoxicillin','Amoxicillin 500 mg','Amox','500 mg','Capsule',12.50,8.00,true,true,100),
 ('95000000-0000-0000-0000-000000000002','Paracetamol','Paracetamol 500 mg','Para','500 mg','Tablet',5.00,3.00,true,true,100),
 ('95000000-0000-0000-0000-000000000003','Inactive Medicine','Inactive Medicine','Inactive','10 mg','Tablet',1.00,0.50,false,false,10)
ON CONFLICT (id) DO NOTHING;

COMMIT;
