-- Phase 21B: run only after the atomic-RPC patient registration UI is deployed and smoke-tested.
-- Keep this separate from Phase 21A so existing registration remains available during rollout.
REVOKE INSERT ON TABLE public.patients FROM authenticated;
REVOKE ALL ON FUNCTION public.next_mrn() FROM PUBLIC, anon, authenticated;
