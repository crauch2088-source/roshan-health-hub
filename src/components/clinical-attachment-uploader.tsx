import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  buildClinicalStoragePath,
  createClinicalSignedUrl,
  uploadClinicalFile,
  validateClinicalFileMetadata,
  type ClinicalStorageBucket,
} from "@/lib/storage";

const enabled = import.meta.env["VITE_ROSHAN_STORAGE_DIRECT_UPLOAD_ENABLED"] === "true";

export function ClinicalAttachmentUploader({
  branchId,
  entityId,
  bucket,
  canUpload,
  lang = "en",
}: {
  branchId: string;
  entityId: string;
  bucket: ClinicalStorageBucket;
  canUpload: boolean;
  lang?: "ar" | "en";
}) {
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [signedUrl, setSignedUrl] = useState("");

  const arabic = lang === "ar";
  const chooseFile = (candidate: File | null) => {
    setFile(null);
    setSignedUrl("");
    setMessage("");
    setError("");
    if (!candidate) return;
    try {
      validateClinicalFileMetadata(candidate, bucket);
      setFile(candidate);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Invalid clinical file.");
    }
  };

  const upload = async () => {
    if (!file || !canUpload || !enabled || busy) return;
    setBusy(true);
    setError("");
    setMessage("");
    setSignedUrl("");
    try {
      const safeName = file.name.replace(/[^A-Za-z0-9._-]/g, "-");
      const path = buildClinicalStoragePath({
        branchId,
        bucket,
        entityId,
        filename: Date.now() + "-" + safeName,
      });
      const result = await uploadClinicalFile(bucket, path, file);
      const url = await createClinicalSignedUrl(bucket, result.path, 300);
      setSignedUrl(url);
      setMessage(arabic ? "تم رفع المرفق بنجاح." : "Attachment uploaded successfully.");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Clinical attachment upload failed.");
    } finally {
      setBusy(false);
    }
  };

  if (!enabled) {
    return (
      <p className="text-xs text-muted-foreground" role="status">
        {arabic
          ? "رفع الملفات الخاص معطل؛ يمكنك استخدام الطباعة المحلية كالمعتاد."
          : "Private uploads are disabled; local printing remains available."}
      </p>
    );
  }
  if (!canUpload) return null;

  return (
    <section
      className="mt-2 space-y-2 rounded-md border p-3"
      aria-label={arabic ? "مرفقات سريرية" : "Clinical attachments"}
    >
      <label className="block text-sm font-medium">
        {arabic ? "إرفاق تقرير PDF أو صورة" : "Attach PDF report or image"}
        <input
          className="mt-1 block w-full text-sm"
          type="file"
          accept="application/pdf,image/png,image/jpeg"
          onChange={(event) => chooseFile(event.currentTarget.files?.[0] ?? null)}
          disabled={busy}
        />
      </label>
      {file && (
        <p className="text-xs text-muted-foreground">
          {file.name} · {(file.size / 1024 / 1024).toFixed(2)} MB
        </p>
      )}
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
      {message && (
        <p role="status" className="text-sm text-emerald-700">
          {message}
        </p>
      )}
      <div className="flex flex-wrap gap-2">
        <Button type="button" size="sm" onClick={() => void upload()} disabled={!file || busy}>
          {busy
            ? arabic
              ? "جارٍ الرفع..."
              : "Uploading…"
            : arabic
              ? "رفع المرفق"
              : "Upload attachment"}
        </Button>
        {signedUrl && (
          <Button
            type="button"
            size="sm"
            variant="outline"
            onClick={() => window.open(signedUrl, "_blank", "noopener,noreferrer")}
          >
            {arabic ? "فتح المرفق المؤقت" : "Open temporary attachment"}
          </Button>
        )}
      </div>
    </section>
  );
}
