import { createFileRoute } from "@tanstack/react-router";
import { Plus } from "lucide-react";
import { useState } from "react";

import { Empty, ErrorBox, Field, Loading, PageHeader } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useAuth } from "@/lib/auth";
import { b, rel, s, useRows, useSave, type Row } from "@/lib/db";
import { useLang } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

import { createStaffUser } from "./-users.server";

export const Route = createFileRoute("/_authenticated/users")({
  head: () => ({
    meta: [
      { title: "Users — ROSHAN Medical Center" },
      { name: "description", content: "Staff accounts, roles and access management." },
      { property: "og:title", content: "Users — ROSHAN Medical Center" },
      { property: "og:description", content: "Staff accounts, roles and access management." },
    ],
  }),
  component: UsersPage,
});

function UsersPage() {
  const { t, lang } = useLang();
  const { can } = useAuth();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ full_name: "", email: "", password: "", phone: "", role_id: "" });

  const list = useRows(["users"], () =>
    supabase
      .from("users")
      .select("id, full_name, email, phone, active, auth_user_id, roles(id, code, name, name_ar)")
      .is("deleted_at", null)
      .order("created_at", { ascending: false }),
  );
  const roles = useRows(["roles"], () => supabase.from("roles").select("id, code, name, name_ar"));

  const create = useSave(
    async () => {
      // Creating a staff account runs on the server (service_role key) so
      // that it never replaces the current admin's own browser session —
      // `supabase.auth.signUp` on the client does exactly that, which was
      // the previous (broken) behavior here.
      const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
      const accessToken = sessionData.session?.access_token;
      if (sessionError || !accessToken) {
        throw new Error("Your session has expired. Please sign in again.");
      }

      await createStaffUser({
        data: {
          accessToken,
          full_name: form.full_name,
          email: form.email,
          password: form.password,
          phone: form.phone,
          role_id: form.role_id,
        },
      });
      return null;
    },
    {
      invalidate: [["users"]],
      successMessage: t("user_created"),
      onDone: () => {
        setOpen(false);
        setForm({ full_name: "", email: "", password: "", phone: "", role_id: "" });
      },
    },
  );

  const toggle = useSave<{ id: string; active: boolean }>(
    async ({ id, active }) => {
      const { error } = await supabase.from("users").update({ active }).eq("id", id);
      if (error) throw new Error(error.message);
      return null;
    },
    { invalidate: [["users"]] },
  );

  const rows = (list.data ?? []) as Row[];
  if (list.isLoading) return <Loading />;

  return (
    <div>
      <PageHeader title={t("users")} subtitle={t("staff_accounts")}>
        {can("users.create") ? (
          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4" /> {t("add")}
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>{t("users")}</DialogTitle>
              </DialogHeader>
              <div className="grid gap-4">
                <Field label={`${t("full_name")} *`}>
                  <Input value={form.full_name} onChange={(e) => setForm({ ...form, full_name: e.target.value })} />
                </Field>
                <Field label={`${t("email")} *`}>
                  <Input type="email" dir="ltr" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
                </Field>
                <Field label={`${t("password")} * (min. 8 characters)`}>
                  <Input
                    type="password"
                    dir="ltr"
                    minLength={8}
                    value={form.password}
                    onChange={(e) => setForm({ ...form, password: e.target.value })}
                  />
                </Field>
                <Field label={t("phone")}>
                  <Input dir="ltr" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
                </Field>
                <Field label={`${t("role")} *`}>
                  <Select value={form.role_id} onValueChange={(v) => setForm({ ...form, role_id: v })}>
                    <SelectTrigger>
                      <SelectValue placeholder={t("role")} />
                    </SelectTrigger>
                    <SelectContent>
                      {((roles.data ?? []) as Row[]).map((r) => (
                        <SelectItem key={s(r, "id")} value={s(r, "id")}>
                          {lang === "ar" ? s(r, "name_ar") || s(r, "name") : s(r, "name")}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
              </div>
              <DialogFooter>
                <Button variant="outline" onClick={() => setOpen(false)}>
                  {t("cancel")}
                </Button>
                <Button
                  disabled={
                    !form.full_name ||
                    !form.email ||
                    form.password.length < 8 ||
                    !form.role_id ||
                    create.isPending
                  }
                  onClick={() => create.mutate(undefined as never)}
                >
                  {create.isPending ? t("saving") : t("save")}
                </Button>
              </DialogFooter>
            </DialogContent>
          </Dialog>
        ) : null}
      </PageHeader>

      <ErrorBox error={list.error} />

      <Card>
        <CardContent className="p-0">
          {rows.length === 0 ? (
            <Empty />
          ) : (
            <Table density="compact">
              <TableHeader>
                <TableRow>
                  <TableHead>{t("full_name")}</TableHead>
                  <TableHead>{t("email")}</TableHead>
                  <TableHead>{t("phone")}</TableHead>
                  <TableHead>{t("role")}</TableHead>
                  <TableHead className="no-print">{t("active")}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((u) => (
                  <TableRow key={s(u, "id")}>
                    <TableCell className="font-medium">{s(u, "full_name")}</TableCell>
                    <TableCell dir="ltr">{s(u, "email")}</TableCell>
                    <TableCell dir="ltr">{s(u, "phone") || "—"}</TableCell>
                    <TableCell>
                      {lang === "ar"
                        ? s(rel(u, "roles"), "name_ar") || s(rel(u, "roles"), "name")
                        : s(rel(u, "roles"), "name")}
                    </TableCell>
                    <TableCell className="no-print">
                      <Switch
                        checked={b(u, "active")}
                        disabled={!can("users.update")}
                        onCheckedChange={(v) => toggle.mutate({ id: s(u, "id"), active: v })}
                      />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}