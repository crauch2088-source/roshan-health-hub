CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA auth;
CREATE SCHEMA private;

CREATE TABLE public.users (
  id uuid PRIMARY KEY,
  auth_user_id uuid NOT NULL,
  branch_id uuid NOT NULL,
  active boolean NOT NULL DEFAULT true
);
CREATE TABLE public.invoices (
  id uuid PRIMARY KEY,
  branch_id uuid NOT NULL
);
CREATE TABLE public.invoice_items (
  id uuid PRIMARY KEY,
  invoice_id uuid NOT NULL,
  description text NOT NULL
);

CREATE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $function$
  SELECT NULLIF(current_setting('test.auth_uid', true), '')::uuid
$function$;

CREATE FUNCTION public.app_has_perm(p_permission text)
RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT position('|' || p_permission || '|' IN
    '|' || COALESCE(current_setting('test.permissions', true), '') || '|') > 0
$function$;

CREATE FUNCTION private.app_has_branch_access(_branch_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_user_id = auth.uid()
      AND u.active
      AND u.branch_id = _branch_id
  )
$function$;

CREATE FUNCTION private.app_has_invoice_branch(_invoice_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.invoices i
    WHERE i.id = _invoice_id
      AND private.app_has_branch_access(i.branch_id)
  )
$function$;

GRANT EXECUTE ON FUNCTION private.app_has_branch_access(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.app_has_invoice_branch(uuid) TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.invoices, public.invoice_items TO authenticated;

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY invoices_select ON public.invoices FOR SELECT TO authenticated
  USING ((SELECT public.app_has_perm('billing.read')) AND (SELECT private.app_has_branch_access(invoices.branch_id)));
CREATE POLICY invoice_items_select ON public.invoice_items FOR SELECT TO authenticated
  USING ((SELECT public.app_has_perm('billing.read')) OR (SELECT public.app_has_perm('billing.view')));
CREATE POLICY invoice_items_insert ON public.invoice_items FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.app_has_perm('billing.create')));
CREATE POLICY invoice_items_update ON public.invoice_items FOR UPDATE TO authenticated
  USING ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')))
  WITH CHECK ((SELECT public.app_has_perm('billing.update')) OR (SELECT public.app_has_perm('billing.edit')));
CREATE POLICY invoice_items_delete ON public.invoice_items FOR DELETE TO authenticated
  USING ((SELECT public.app_has_perm('billing.delete')));

INSERT INTO public.users(id, auth_user_id, branch_id, active) VALUES
 ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001',true);
INSERT INTO public.invoices(id,branch_id) VALUES
 ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001'),
 ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002');
INSERT INTO public.invoice_items(id,invoice_id,description) VALUES
 ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','branch A item'),
 ('40000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000002','branch B item');

SELECT set_config('test.auth_uid','10000000-0000-0000-0000-000000000002',false);
SELECT set_config('test.permissions','billing.read|billing.view|billing.create|billing.update|billing.edit|billing.delete',false);
