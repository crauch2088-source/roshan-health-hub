ALTER TABLE public.cashbox_transactions
  ADD COLUMN IF NOT EXISTS is_reversed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS reversal_of uuid,
  ADD COLUMN IF NOT EXISTS reversal_reason text;

CREATE INDEX IF NOT EXISTS idx_cashbox_transactions_reversal_of
  ON public.cashbox_transactions(reversal_of)
  WHERE reversal_of IS NOT NULL;
