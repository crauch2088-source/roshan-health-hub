import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import {
  checkPg17Compatibility,
  classifyBackupPreflight,
  redactBackupLog,
  sha256Hex,
  stageEncryptedArtifactAtomic,
  verifySha256Digest,
} from "../scripts/backup-dr-guard.mjs";

const VALID_AGE_RECIPIENT = "age1czhalwdx8a5swtru7mlqtglw6g3qdm26d2rfcjdy5ck95a36vccs25m0ur";

test("classifyBackupPreflight reproduces run #43764265014 missing DB credential failure", () => {
  const res = classifyBackupPreflight({
    SUPABASE_ACCESS_TOKEN: "sbp_dummy_token",
    SUPABASE_DB_ACCESS_TOKEN: "",
    SUPABASE_DB_PASSWORD: "",
    AGE_RECIPIENT: VALID_AGE_RECIPIENT,
  });
  assert.equal(res.ok, false);
  assert.equal(res.category, "authentication");
  assert.equal(res.code, "missing_db_credential");
});

test("classifyBackupPreflight rejects ambiguous DB credentials and invalid age recipients", () => {
  const both = classifyBackupPreflight({
    SUPABASE_ACCESS_TOKEN: "sbp_dummy_token",
    SUPABASE_DB_ACCESS_TOKEN: "tok",
    SUPABASE_DB_PASSWORD: "pwd",
    AGE_RECIPIENT: VALID_AGE_RECIPIENT,
  });
  assert.equal(both.ok, false);
  assert.equal(both.code, "ambiguous_db_credentials");

  const badAge = classifyBackupPreflight({
    SUPABASE_ACCESS_TOKEN: "sbp_dummy_token",
    SUPABASE_DB_PASSWORD: "pwd",
    AGE_RECIPIENT: "not-an-age-recipient",
  });
  assert.equal(badAge.ok, false);
  assert.equal(badAge.category, "encryption");
  assert.equal(badAge.code, "invalid_age_recipient");

  const ok = classifyBackupPreflight({
    SUPABASE_ACCESS_TOKEN: "sbp_dummy_token",
    SUPABASE_DB_ACCESS_TOKEN: "tok",
    AGE_RECIPIENT: VALID_AGE_RECIPIENT,
  });
  assert.equal(ok.ok, true);
  assert.equal(ok.authMode, "db_access_token");
});

test("redactBackupLog strips DB URLs, passwords, Supabase tokens, and age private keys", () => {
  const sample = [
    "postgresql://postgres.ref:supersecret@aws-1-eu-west-1.pooler.supabase.com:5432/postgres",
    "PGPASSWORD=mysecret SUPABASE_ACCESS_TOKEN=sbp_1234567890abcdef",
    "AGE-SECRET-KEY-1QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ",
  ].join(" ");
  const cleaned = redactBackupLog(sample);
  assert.doesNotMatch(cleaned, /supersecret/);
  assert.doesNotMatch(cleaned, /mysecret/);
  assert.doesNotMatch(cleaned, /sbp_1234567890abcdef/);
  assert.doesNotMatch(cleaned, /AGE-SECRET-KEY-1/);
  assert.match(cleaned, /\[REDACTED\]/);
  assert.match(cleaned, /\[REDACTED_AGE_PRIVATE_KEY\]/);
});

test("verifySha256Digest passes on exact match and fails closed on corruption", () => {
  const payload = Buffer.from("synthetic-qa-encrypted-archive-bytes");
  const digest = sha256Hex(payload);
  assert.equal(verifySha256Digest(payload, digest).ok, true);

  const tampered = Buffer.from("synthetic-qa-encrypted-archive-byteX");
  const check = verifySha256Digest(tampered, digest);
  assert.equal(check.ok, false);
  assert.equal(check.reason, "digest_mismatch");
});

test("checkPg17Compatibility enforces PostgreSQL 17 on both client and server", () => {
  assert.equal(
    checkPg17Compatibility("pg_dump (PostgreSQL) 17.6", "17.6 (Debian 17.6-1)").ok,
    true,
  );
  assert.equal(checkPg17Compatibility("pg_dump (PostgreSQL) 16.4", "17.6").ok, false);
});

test("stageEncryptedArtifactAtomic preserves last-known-good artifact on encryption failure", () => {
  const dir = mkdtempSync(join(tmpdir(), "roshan-dr-atomic-"));
  try {
    const existing = join(dir, "last-good.tar.gz.age");
    writeFileSync(existing, "previous-good-ciphertext");

    const fail = stageEncryptedArtifactAtomic({
      artifactDir: dir,
      artifactName: "new-run.tar.gz.age",
      encryptToFile: () => {
        throw new Error("age failed with PGPASSWORD=leakme");
      },
    });
    assert.equal(fail.ok, false);
    assert.doesNotMatch(fail.error ?? "", /leakme/);
    assert.equal(readFileSync(existing, "utf8"), "previous-good-ciphertext");

    const pass = stageEncryptedArtifactAtomic({
      artifactDir: dir,
      artifactName: "new-run.tar.gz.age",
      encryptToFile: (tmpPath) => {
        writeFileSync(tmpPath, "new-valid-ciphertext");
      },
    });
    assert.equal(pass.ok, true);
    assert.match(readFileSync(join(dir, "SHA256SUMS"), "utf8"), /new-run\.tar\.gz\.age/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("qa-synthetic-pg17-restore-drill.sh enforces strict shell safety and never targets Production", () => {
  const script = readFileSync(
    new URL("../scripts/qa-synthetic-pg17-restore-drill.sh", import.meta.url),
    "utf8",
  );
  assert.match(script, /set -Eeuo pipefail/);
  assert.match(script, /set \+x/);
  assert.match(script, /umask 077/);
  assert.match(script, /trap cleanup EXIT/);
  assert.match(script, /DROP DATABASE IF EXISTS/);
  assert.doesNotMatch(script, /jewzonxplxhogqrnhosl/);
});
