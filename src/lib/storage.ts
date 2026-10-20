import { supabase } from "./supabase";
import {
  assertClinicalStoragePath,
  buildClinicalStoragePath,
  validateClinicalFileMetadata,
  type ClinicalFileMetadata,
  type ClinicalStorageBucket,
} from "./storage-path";

export {
  assertClinicalStoragePath,
  buildClinicalStoragePath,
  validateClinicalFileMetadata,
  type ClinicalFileMetadata,
  type ClinicalStorageBucket,
} from "./storage-path";

/** Upload only after validating the private bucket's MIME and size contract. */
export async function uploadClinicalFile(
  bucket: ClinicalStorageBucket,
  path: string,
  file: File,
): Promise<{ path: string }> {
  assertClinicalStoragePath(bucket, path);
  validateClinicalFileMetadata(file, bucket);

  const { data, error } = await supabase.storage.from(bucket).upload(path, file, {
    contentType: file.type,
    upsert: false,
  });

  if (error) throw new Error(error.message || "Clinical file upload failed.");
  return { path: data.path };
}

/** Signed URLs are short-lived; never persist or expose a public URL for clinical files. */
export async function createClinicalSignedUrl(
  bucket: ClinicalStorageBucket,
  path: string,
  expiresInSeconds = 300,
): Promise<string> {
  assertClinicalStoragePath(bucket, path);

  if (
    !Number.isInteger(expiresInSeconds) ||
    expiresInSeconds < 30 ||
    expiresInSeconds > 3600
  ) {
    throw new Error("Signed URL expiry must be between 30 and 3600 seconds.");
  }

  const { data, error } = await supabase.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  if (error || !data?.signedUrl) {
    throw new Error(error?.message || "Could not create a signed clinical file URL.");
  }
  return data.signedUrl;
}
