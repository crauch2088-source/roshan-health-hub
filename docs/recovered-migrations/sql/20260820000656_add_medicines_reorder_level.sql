ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS reorder_level integer NOT NULL DEFAULT 0;
