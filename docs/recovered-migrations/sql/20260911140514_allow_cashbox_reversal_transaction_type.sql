ALTER TABLE public.cashbox_transactions
DROP CONSTRAINT IF EXISTS cashbox_transactions_transaction_type_check;

ALTER TABLE public.cashbox_transactions
ADD CONSTRAINT cashbox_transactions_transaction_type_check
CHECK (
  transaction_type = ANY (
    ARRAY[
      'customer_payment'::text,
      'expense'::text,
      'supplier_payment'::text,
      'deposit'::text,
      'withdrawal'::text,
      'adjustment'::text,
      'reversal'::text
    ]
  )
);
