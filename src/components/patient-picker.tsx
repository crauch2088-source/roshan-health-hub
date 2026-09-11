import { Link } from "@tanstack/react-router";
import { Check, ChevronsUpDown, UserPlus } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { s, useRows, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { formatDate, money } from "@/lib/medical";
import { patientPickerQuery, useDebounced } from "@/lib/search";
import { supabase } from "@/lib/supabase";
import { cn } from "@/lib/utils";

export type PickedPatient = {
  id: string;
  full_name: string;
  mrn: string;
  phone: string;
};

/**
 * Patient search-and-select combobox. Built on the shared `patientPickerQuery`
 * from lib/search.ts (name / MRN / phone / national ID, MRN-first) so this
 * doesn't become a second, slightly-different patient search implementation.
 * Typing narrows results live (debounced 300ms); arrow keys + Enter + Escape
 * are handled by cmdk's <Command>, matching the keyboard behaviour of the
 * global search dialog elsewhere in the app.
 */
export function PatientPicker({
  value,
  onSelect,
  placeholder,
  autoFocus,
}: {
  value: PickedPatient | null;
  onSelect: (patient: PickedPatient | null) => void;
  placeholder?: string;
  autoFocus?: boolean;
}) {
  const { t } = useLang();
  const [open, setOpen] = useState(Boolean(autoFocus));
  const [term, setTerm] = useState("");
  const debounced = useDebounced(term, 300);

  const results = useRows<Row[]>(
    ["patient-picker", debounced],
    () => patientPickerQuery(debounced),
    { enabled: open },
  );

  const rows = (results.data ?? []) as Row[];
  const searching = term.length > 0 && (results.isFetching || term !== debounced);

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="outline"
          role="combobox"
          aria-expanded={open}
          className="w-full justify-between font-normal"
        >
          {value ? (
            <span className="truncate">
              {value.full_name} — {value.mrn || value.phone || "—"}
            </span>
          ) : (
            <span className="text-muted-foreground">{placeholder ?? t("search_patient_placeholder")}</span>
          )}
          <ChevronsUpDown className="ms-2 size-4 shrink-0 opacity-50" />
        </Button>
      </PopoverTrigger>
      <PopoverContent
        className="w-[var(--radix-popover-trigger-width)] max-w-[min(100vw-2rem,var(--radix-popover-trigger-width))] p-0"
        align="start"
        // Keep the combobox above Dialog overlays (see popover.tsx z-[10050]).
        // Avoid modal focus trap fighting the parent Dialog on mobile keyboards.
        onOpenAutoFocus={(e) => {
          // Let CommandInput take focus without the Dialog stealing it back.
          e.preventDefault();
          const input = (e.currentTarget as HTMLElement).querySelector<HTMLInputElement>(
            "[cmdk-input], input",
          );
          input?.focus();
        }}
      >
        <Command shouldFilter={false}>
          <CommandInput value={term} onValueChange={setTerm} placeholder={t("search_patient_placeholder")} />
          <CommandList>
            {searching ? (
              <div className="py-6 text-center text-sm text-muted-foreground">{t("loading")}</div>
            ) : rows.length === 0 ? (
              <CommandEmpty>
                <div className="flex flex-col items-center gap-2 py-3">
                  <p className="text-sm text-muted-foreground">{t("no_results")}</p>
                  {term.trim().length >= 2 ? (
                    <>
                      <Link
                        to="/patients"
                        className="inline-flex items-center gap-1 text-sm font-medium text-primary hover:underline"
                        onClick={() => setOpen(false)}
                      >
                        <UserPlus className="size-3.5" /> {t("add_new_patient")}
                      </Link>
                      <p className="max-w-[220px] text-center text-xs text-muted-foreground">
                        {t("duplicate_patient_hint")}
                      </p>
                    </>
                  ) : null}
                </div>
              </CommandEmpty>
            ) : (
              <CommandGroup heading={term.trim() ? undefined : t("recent_patients")}>
                {rows.map((p) => (
                  <CommandItem
                    key={s(p, "id")}
                    value={s(p, "id")}
                    onSelect={() => {
                      onSelect({
                        id: s(p, "id"),
                        full_name: s(p, "full_name"),
                        mrn: s(p, "mrn"),
                        phone: s(p, "phone"),
                      });
                      setOpen(false);
                      setTerm("");
                    }}
                  >
                    <Check className={cn("me-2 size-4", value?.id === s(p, "id") ? "opacity-100" : "opacity-0")} />
                    <div className="flex min-w-0 flex-col">
                      <span className="truncate font-medium">{s(p, "full_name")}</span>
                      <span className="truncate text-xs text-muted-foreground" dir="ltr">
                        {s(p, "mrn") || "—"} · {s(p, "phone") || "—"}
                      </span>
                    </div>
                  </CommandItem>
                ))}
              </CommandGroup>
            )}
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  );
}

/**
 * Previous-visits count, last visit date, and outstanding invoice balance
 * for a selected patient — shown under the picker so reception can spot
 * "this patient owes money" or "they were just here yesterday" before
 * confirming the new visit.
 */
export function usePatientSnapshot(patientId: string | null) {
  const visits = useRows<Row[]>(
    ["patient-snapshot-visits", patientId ?? ""],
    () =>
      supabase
        .from("visits")
        .select("visit_date")
        .eq("patient_id", patientId as string)
        .is("deleted_at", null)
        .order("visit_date", { ascending: false })
        .limit(500),
    { enabled: Boolean(patientId) },
  );

  const invoices = useRows<Row[]>(
    ["patient-snapshot-invoices", patientId ?? ""],
    () =>
      supabase
        .from("invoices")
        .select("net_amount, paid_amount")
        .eq("patient_id", patientId as string)
        .is("deleted_at", null)
        .limit(1000),
    { enabled: Boolean(patientId) },
  );

  const visitRows = (visits.data ?? []) as Row[];
  const invoiceRows = (invoices.data ?? []) as Row[];
  const outstanding = invoiceRows.reduce(
    (sum, inv) => sum + (Number(inv["net_amount"]) || 0) - (Number(inv["paid_amount"]) || 0),
    0,
  );

  return {
    isLoading: visits.isLoading || invoices.isLoading,
    visitsCount: visitRows.length,
    lastVisitDate: visitRows[0] ? s(visitRows[0], "visit_date") : null,
    outstandingBalance: outstanding,
  };
}

/** Small inline strip rendered under the picker once a patient is selected. */
export function PatientSnapshotStrip({ patientId, currency }: { patientId: string; currency: string }) {
  const { t } = useLang();
  const snap = usePatientSnapshot(patientId);

  if (snap.isLoading) return null;

  return (
    <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 rounded-md border bg-muted/40 px-3 py-2 text-xs">
      <span>
        <span className="text-muted-foreground">{t("previous_visits")}: </span>
        <span className="font-medium" dir="ltr">
          {snap.visitsCount}
        </span>
      </span>
      <span>
        <span className="text-muted-foreground">{t("last_visit")}: </span>
        <span className="font-medium" dir="ltr">
          {snap.lastVisitDate ? formatDate(snap.lastVisitDate) : "—"}
        </span>
      </span>
      {snap.outstandingBalance > 0 ? (
        <span>
          <span className="text-muted-foreground">{t("outstanding_balance")}: </span>
          <span className="font-semibold text-destructive" dir="ltr">
            {money(snap.outstandingBalance, currency)}
          </span>
        </span>
      ) : null}
    </div>
  );
}
