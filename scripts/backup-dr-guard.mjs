import { createHash, timingSafeEqual } from "node:crypto";
import { existsSync, readFileSync, renameSync, rmSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const AGE_RECIPIENT_RE = /^age1[0-9a-z]{20,}$/;

export function classifyBackupPreflight(env) {
  const accessToken = (env.SUPABASE_ACCESS_TOKEN ?? "").trim();
  const dbToken = (env.SUPABASE_DB_ACCESS_TOKEN ?? "").trim();
  const dbPassword = (env.SUPABASE_DB_PASSWORD ?? "").trim();
  const ageRecipient = (env.AGE_RECIPIENT ?? "").trim();

  if (!accessToken) {
    return {
      ok: false,
      category: "authentication",
      code: "missing_access_token",
      message: "Configure SUPABASE_ACCESS_TOKEN for Supabase CLI authentication.",
    };
  }

  const hasDbToken = dbToken.length > 0;
  const hasDbPassword = dbPassword.length > 0;
  if (!hasDbToken && !hasDbPassword) {
    return {
      ok: false,
      category: "authentication",
      code: "missing_db_credential",
      message: "Configure exactly one of SUPABASE_DB_ACCESS_TOKEN or SUPABASE_DB_PASSWORD.",
    };
  }
  if (hasDbToken && hasDbPassword) {
    return {
      ok: false,
      category: "authentication",
      code: "ambiguous_db_credentials",
      message: "Configure exactly one of SUPABASE_DB_ACCESS_TOKEN or SUPABASE_DB_PASSWORD.",
    };
  }

  if (!ageRecipient) {
    return {
      ok: false,
      category: "encryption",
      code: "missing_age_recipient",
      message: "Configure AGE_RECIPIENT as a repository Actions variable.",
    };
  }
  if (!AGE_RECIPIENT_RE.test(ageRecipient)) {
    return {
      ok: false,
      category: "encryption",
      code: "invalid_age_recipient",
      message: "AGE_RECIPIENT is not a valid age recipient.",
    };
  }

  return {
    ok: true,
    category: "ok",
    code: "valid",
    authMode: hasDbToken ? "db_access_token" : "db_password",
    message: "Required backup credentials are configured; secret values redacted.",
  };
}

export function redactBackupLog(raw) {
  let out = String(raw ?? "");
  out = out.replace(/postgres(?:ql)?:\/\/[^\s'"]+/gi, "postgresql://[REDACTED]");
  out = out.replace(/AGE-SECRET-KEY-1[0-9A-Z]+/g, "[REDACTED_AGE_PRIVATE_KEY]");
  out = out.replace(/sbp_[0-9a-zA-Z_-]+/g, "[REDACTED_SUPABASE_TOKEN]");
  out = out.replace(/Bearer\s+[A-Za-z0-9._-]+/gi, "Bearer [REDACTED]");
  out = out.replace(
    /\b(PGPASSWORD|SUPABASE_ACCESS_TOKEN|SUPABASE_DB_PASSWORD|SUPABASE_DB_ACCESS_TOKEN)=[^\s'"]+/g,
    "$1=[REDACTED]",
  );
  return out;
}

export function sha256Hex(input) {
  return createHash("sha256").update(input).digest("hex");
}

export function verifySha256Digest(input, expectedHex) {
  const actual = sha256Hex(input);
  const cleanExpected = String(expectedHex ?? "")
    .trim()
    .toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(cleanExpected)) {
    return { ok: false, actual, expected: cleanExpected, reason: "invalid_expected_hex" };
  }
  const match = timingSafeEqual(Buffer.from(actual, "hex"), Buffer.from(cleanExpected, "hex"));
  return {
    ok: match,
    actual,
    expected: cleanExpected,
    reason: match ? "matched" : "digest_mismatch",
  };
}

export function checkPg17Compatibility(clientVersion, serverVersion) {
  const parseMajor = (v) => {
    const m = /\b(\d{1,2})(?:\.\d+)?\b/.exec(String(v ?? ""));
    return m ? Number(m[1]) : null;
  };
  const clientMajor = parseMajor(clientVersion);
  const serverMajor = parseMajor(serverVersion);
  const ok = clientMajor === 17 && serverMajor === 17;
  return {
    ok,
    clientMajor,
    serverMajor,
    reason: ok ? "compatible_pg17" : "pg17_version_mismatch",
  };
}

export function stageEncryptedArtifactAtomic({ artifactDir, artifactName, encryptToFile }) {
  const finalPath = join(artifactDir, artifactName);
  const tmpPath = join(artifactDir, `${artifactName}.tmp`);
  const sumsPath = join(artifactDir, "SHA256SUMS");
  const sumsTmpPath = join(artifactDir, "SHA256SUMS.tmp");

  try {
    encryptToFile(tmpPath);
    if (!existsSync(tmpPath) || statSync(tmpPath).size === 0) {
      throw new Error("Encrypted artifact is missing or empty.");
    }
    const digest = sha256Hex(readFileSync(tmpPath));
    writeFileSync(sumsTmpPath, `${digest}  ${artifactName}\n`, "utf8");
    renameSync(tmpPath, finalPath);
    renameSync(sumsTmpPath, sumsPath);
    return { ok: true, finalPath, sumsPath };
  } catch (err) {
    rmSync(tmpPath, { force: true });
    rmSync(sumsTmpPath, { force: true });
    return {
      ok: false,
      error: redactBackupLog(err instanceof Error ? err.message : String(err)),
    };
  }
}
