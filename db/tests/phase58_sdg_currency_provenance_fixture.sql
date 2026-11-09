-- Synthetic PostgreSQL 17 fixture for Phase 58. Never run against Supabase.
CREATE SCHEMA private;

CREATE TABLE public.invoices (id uuid PRIMARY KEY, note text);
CREATE TABLE public.payments (id uuid PRIMARY KEY, note text);
CREATE TABLE public.cashbox_transactions (id uuid PRIMARY KEY, note text);
CREATE TABLE public.expenses (id uuid PRIMARY KEY, note text);
CREATE TABLE public.supplier_bills (id uuid PRIMARY KEY, note text);
CREATE TABLE public.supplier_payments (id uuid PRIMARY KEY, note text);
CREATE TABLE public.pharmacy_inventory (id uuid PRIMARY KEY, note text);

-- Seed pre-migration legacy rows. The migration must preserve their unknown provenance.
INSERT INTO public.invoices (id, note) VALUES ('58000000-0000-0000-0000-000000000001', 'legacy');
INSERT INTO public.payments (id, note) VALUES ('58000000-0000-0000-0000-000000000002', 'legacy');
INSERT INTO public.cashbox_transactions (id, note) VALUES ('58000000-0000-0000-0000-000000000003', 'legacy');
INSERT INTO public.expenses (id, note) VALUES ('58000000-0000-0000-0000-000000000004', 'legacy');
INSERT INTO public.supplier_bills (id, note) VALUES ('58000000-0000-0000-0000-000000000005', 'legacy');
INSERT INTO public.supplier_payments (id, note) VALUES ('58000000-0000-0000-0000-000000000006', 'legacy');
INSERT INTO public.pharmacy_inventory (id, note) VALUES ('58000000-0000-0000-0000-000000000007', 'legacy');
