DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'followups_created_by_fkey') THEN
    ALTER TABLE public.followups ADD CONSTRAINT followups_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'followups_updated_by_fkey') THEN
    ALTER TABLE public.followups ADD CONSTRAINT followups_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'medical_certificates_patient_id_fkey') THEN
    ALTER TABLE public.medical_certificates ADD CONSTRAINT medical_certificates_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'medical_certificates_doctor_id_fkey') THEN
    ALTER TABLE public.medical_certificates ADD CONSTRAINT medical_certificates_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES public.users(id);
  END IF;
END $$;
NOTIFY pgrst, 'reload schema';
