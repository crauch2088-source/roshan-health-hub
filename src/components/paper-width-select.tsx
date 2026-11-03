import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { PaperWidth } from "@/lib/document-print";

export function PaperWidthSelect({
  value,
  onChange,
  lang,
}: {
  value: PaperWidth;
  onChange: (value: PaperWidth) => void;
  lang: "ar" | "en";
}) {
  return (
    <div className="no-print flex items-center gap-2">
      <label className="whitespace-nowrap text-xs text-muted-foreground">
        {lang === "ar" ? "حجم الورق" : "Paper size"}
      </label>
      <Select value={value} onValueChange={(next) => onChange(next as PaperWidth)}>
        <SelectTrigger className="h-8 w-[104px]" aria-label={lang === "ar" ? "حجم الورق" : "Paper size"}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="a4">A4</SelectItem>
          <SelectItem value="58mm">58 mm</SelectItem>
          <SelectItem value="80mm">80 mm</SelectItem>
        </SelectContent>
      </Select>
    </div>
  );
}
