import { LogOut } from "lucide-react";

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useAuth } from "@/lib/auth";
import { useLang } from "@/lib/i18n";

/** Phone/tablet account control. On desktop the rail footer carries identity and sign-out. */
export function AccountMenu({ onSignOut }: { onSignOut: () => void }) {
  const { user } = useAuth();
  const { t, lang } = useLang();
  const initial = (user?.full_name ?? "").trim().charAt(0).toUpperCase() || "•";

  return (
    <DropdownMenu dir={lang === "ar" ? "rtl" : "ltr"}>
      <DropdownMenuTrigger asChild>
        <button
          type="button"
          aria-label={t("account")}
          className="flex size-9 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary outline-none transition-colors hover:bg-primary/15 focus-visible:ring-2 focus-visible:ring-ring lg:hidden"
        >
          {initial}
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-56">
        <DropdownMenuLabel className="space-y-0.5">
          <p className="truncate text-sm font-semibold">{user?.full_name ?? "—"}</p>
          <p className="truncate text-xs font-normal text-muted-foreground">
            {user?.role_name ?? ""}
          </p>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem onSelect={onSignOut} className="min-h-10 gap-2">
          <LogOut className="size-4" aria-hidden /> {t("sign_out")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
