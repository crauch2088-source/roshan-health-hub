export type ClinicalStorageBucket = "roshan-lab-reports" | "roshan-medical-certificates" | "roshan-clinical-attachments";
export type ClinicalStorageEntityType = "lab-reports" | "medical-certificates" | "clinical-attachments";
export interface ClinicalFileMetadata { type: string; size: number; name?: string; }

const BUCKET_ENTITY: Record<ClinicalStorageBucket, ClinicalStorageEntityType> = {
  "roshan-lab-reports": "lab-reports",
  "roshan-medical-certificates": "medical-certificates",
  "roshan-clinical-attachments": "clinical-attachments",
};
const MAX_BYTES: Record<ClinicalStorageBucket, number> = {
  "roshan-lab-reports": 10 * 1024 * 1024,
  "roshan-medical-certificates": 10 * 1024 * 1024,
  "roshan-clinical-attachments": 20 * 1024 * 1024,
};
const ALLOWED_MIME = new Set(["application/pdf", "image/png", "image/jpeg"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function safeSegment(value: string, label: string): string {
  const trimmed = value.trim();
  if (!trimmed || trimmed === "." || trimmed === ".." || trimmed.includes("/") || trimmed.includes("\\") || !/^[A-Za-z0-9_-]{1,128}$/.test(trimmed)) {
    throw new Error("Invalid clinical storage " + label + ".");
  }
  return trimmed;
}
export function buildClinicalStoragePath(input: { branchId: string; bucket: ClinicalStorageBucket; entityId: string; filename: string }): string {
  if (!UUID.test(input.branchId)) throw new Error("A valid branch UUID is required.");
  const entityId = safeSegment(input.entityId, "entity ID");
  const rawFilename = input.filename.trim().normalize("NFKC");
  const filename = rawFilename.replace(/\\/g, "-").replace(/\//g, "-").replace(/\s+/g, "-")
    .replace(/[^A-Za-z0-9._-]/g, "-").replace(/\.{2,}/g, ".").replace(/^\.+/, "");
  if (!filename || filename.length > 255 || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$/.test(filename)) throw new Error("Invalid clinical storage filename.");
  return input.branchId + "/" + BUCKET_ENTITY[input.bucket] + "/" + entityId + "/" + filename;
}
export function validateClinicalFileMetadata(file: ClinicalFileMetadata, bucket: ClinicalStorageBucket): void {
  if (!ALLOWED_MIME.has(file.type.toLowerCase())) throw new Error("Only PDF, PNG, and JPEG clinical files are allowed.");
  if (!Number.isFinite(file.size) || file.size <= 0 || file.size > MAX_BYTES[bucket]) {
    throw new Error("Clinical file exceeds the " + Math.floor(MAX_BYTES[bucket] / (1024 * 1024)) + " MB limit or is empty.");
  }
}
export function assertClinicalStoragePath(bucket: ClinicalStorageBucket, path: string): void {
  const parts = path.split("/");
  const branch = parts[0] ?? "";
  const entityType = parts[1] ?? "";
  const entityId = parts[2] ?? "";
  const filename = parts[3] ?? "";
  if (parts.length !== 4 || !UUID.test(branch) || entityType !== BUCKET_ENTITY[bucket]) {
    throw new Error("Clinical storage path does not match its private bucket.");
  }
  safeSegment(entityId, "entity ID");
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$/.test(filename) || filename.startsWith("..")) {
    throw new Error("Invalid clinical storage filename.");
  }
}
