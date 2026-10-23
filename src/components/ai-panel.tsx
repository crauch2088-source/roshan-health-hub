import { useState } from "react";
import { Bot, CircleAlert, RefreshCw } from "lucide-react";

import { ErrorBox } from "@/components/kit";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useLang } from "@/lib/i18n";
import type { AiResult } from "@/lib/ai/assistant.functions";

/**
 * Shared surface for the four in-app assistants. It only displays what the
 * server function returned — it has no way to write to a record, and the
 * clinician always keeps the last word.
 */
export function AiPanel({
  title,
  hint,
  ctaLabel,
  run,
  disabled,
  children,
  onResult,
}: {
  title: string;
  hint: string;
  ctaLabel: string;
  run: () => Promise<AiResult>;
  disabled?: boolean;
  children?: React.ReactNode;
  onResult?: (result: AiResult) => void;
}) {
  const { lang } = useLang();
  const [result, setResult] = useState<AiResult | null>(null);
  const [running, setRunning] = useState(false);

  const isArabic = lang === "ar";

  const start = async () => {
    setRunning(true);
    setResult(null);
    try {
      const next = await run();
      setResult(next);
      onResult?.(next);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const failed = { text: null, error: message };
      setResult(failed);
      onResult?.(failed);
    } finally {
      setRunning(false);
    }
  };

  return (
    <Card className="border-primary/25 bg-primary/[0.03]">
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-base">
          <span
            aria-hidden
            className="grid size-7 shrink-0 place-items-center rounded-md bg-primary text-primary-foreground"
          >
            <Bot className="size-4" />
          </span>
          {title}
        </CardTitle>
        <p className="text-xs text-muted-foreground">{hint}</p>
      </CardHeader>
      <CardContent className="space-y-3">
        {children}
        <div className="flex items-center justify-between gap-2">
          <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
            <CircleAlert className="size-3.5 shrink-0" />
            {isArabic
              ? "للمراجعة فقط — لا يُحفظ أي شيء تلقائياً"
              : "For review only — nothing is saved"}
          </span>
          <Button
            type="button"
            size="sm"
            variant="outline"
            onClick={() => void start()}
            disabled={disabled || running}
          >
            {running ? (isArabic ? "جارٍ التحضير…" : "Working…") : ctaLabel}
          </Button>
        </div>

        {result?.error ? (
          <div role="alert" className="space-y-2">
            <ErrorBox error={result.error} />
            <Button type="button" size="sm" variant="outline" onClick={() => void start()}>
              <RefreshCw className="size-3.5" />
              {isArabic ? "إعادة المحاولة" : "Try again"}
            </Button>
          </div>
        ) : null}

        {result?.text ? (
          <div
            dir="auto"
            className="max-h-80 overflow-y-auto rounded-lg border border-primary/20 bg-background p-3 text-sm leading-relaxed whitespace-pre-wrap"
          >
            {result.text}
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}
