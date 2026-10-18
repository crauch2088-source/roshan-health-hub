#!/usr/bin/env python3
"""Verify the frozen historical hash snapshot plus the separately tracked forward-source delta; this is not a live-ledger query."""
from __future__ import annotations
import hashlib, json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/recovered-migrations/source-parity-report.json"
DELTA = ROOT / "docs/live-migration-delta-2026-10-18.json"
def normalize(sql: str) -> str:
    # Matches the documented report normalizer; not a SQL parser or semantic proof.
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    sql = re.sub(r"--[^\n]*", " ", sql)
    sql = re.sub(r"\s+", "", sql).lower()
    sql = re.sub(r"^(begin;|begintransaction;|starttransaction;)+", "", sql)
    sql = re.sub(r"(commit;|end;)+$", "", sql)
    return sql
def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr); raise SystemExit(1)
def main() -> None:
    report = json.loads(MANIFEST.read_text(encoding="utf-8")); entries = report.get("entries", [])
    versions = [e.get("version") for e in entries]
    if report.get("live_migration_count") != 93 or len(entries) != 93: fail("expected exactly 93 migration entries")
    if len(set(versions)) != len(versions) or any(not re.fullmatch(r"\d{14}", str(v)) for v in versions): fail("versions must be unique 14-digit strings")
    if report.get("unmapped_versions") != 0: fail("manifest records unmapped versions")
    if report.get("production_mutated") is not False: fail("manifest must state production_mutated=false")
    matches = placeholders = 0
    for e in entries:
        rel = e.get("source_path"); path = ROOT / str(rel or "")
        if not rel or not path.is_file(): fail(f"{e.get('version')}: missing source file {rel}")
        live_hash = e.get("normalized_live_sql_sha256")
        if not re.fullmatch(r"[0-9a-f]{64}", str(live_hash)): fail(f"{e.get('version')}: invalid live SQL hash")
        source = path.read_text(encoding="utf-8")
        if e.get("source_is_placeholder") is True:
            placeholders += 1
            if e.get("normalized_source_sql_sha256") is not None: fail(f"{e['version']}: placeholder must not claim source hash")
            if "PUBLIC ARCHIVE REDACTION" not in source or re.search(r"(?im)^\s*(select|insert|update|delete|alter|create|drop|grant|revoke)\b", source): fail(f"{e['version']}: redacted file is not a non-executable placeholder")
            if e.get("normalized_text_match") is not False: fail(f"{e['version']}: placeholder cannot be marked matching")
            continue
        source_hash = e.get("normalized_source_sql_sha256")
        if not re.fullmatch(r"[0-9a-f]{64}", str(source_hash)): fail(f"{e['version']}: invalid source SQL hash")
        actual = hashlib.sha256(normalize(source).encode("utf-8")).hexdigest()
        if actual != source_hash or source_hash != live_hash: fail(f"{e['version']}: normalized SQL hash mismatch ({rel})")
        if e.get("normalized_text_match") is not True: fail(f"{e['version']}: matching hash not marked true")
        matches += 1
    if matches != 92 or placeholders != 1: fail(f"expected 92 matches and one redacted placeholder; got {matches} and {placeholders}")
    if report.get("normalized_content_matches") != matches: fail("match count differs from manifest metadata")
    delta = json.loads(DELTA.read_text(encoding="utf-8"))
    delta_entries = delta.get("entries", [])
    if delta.get("live_ledger_count") != 108 or delta.get("latest_live_version") != "20261018064638":
        fail("live delta metadata does not match the last verified 107-entry ledger")
    if delta.get("historical_snapshot_count") != 93 or delta.get("forward_migration_count") != 15 or len(delta_entries) != 15:
        fail("expected the frozen 93-entry snapshot plus fourteen forward-source mappings")
    delta_versions = [e.get("version") for e in delta_entries]
    if len(set(delta_versions)) != 14 or any(not re.fullmatch(r"\d{14}", str(v)) for v in delta_versions):
        fail("forward migration versions must be unique 14-digit strings")
    if delta_versions != sorted(delta_versions):
        fail("forward migration delta must be ordered by ledger version")
    for e in delta_entries:
        rel = e.get("source_path")
        path = ROOT / str(rel or "")
        if not rel or not path.is_file(): fail(f"{e.get('version')}: missing forward source {rel}")
        if not re.fullmatch(r"[0-9a-f]{40}", str(e.get("source_git_blob_sha"))): fail(f"{e.get('version')}: invalid source Git blob SHA")
        source_hash = e.get("normalized_source_sql_sha256")
        if not re.fullmatch(r"[0-9a-f]{64}", str(source_hash)): fail(f"{e.get('version')}: invalid normalized source hash")
        actual_hash = hashlib.sha256(normalize(path.read_text(encoding="utf-8")).encode("utf-8")).hexdigest()
        if actual_hash != source_hash: fail(f"{e.get('version')}: forward source hash mismatch ({rel})")
        if e.get("live_sql_hash_verified") is not False: fail(f"{e.get('version')}: do not overstate live SQL hash verification")
        if not e.get("verification_evidence"): fail(f"{e.get('version')}: missing evidence note")

    replay_safe = ROOT / "docs/recovered-migrations/replay-safe/20260818191254_fix_patients_rls_and_admin_link.sql"
    if not replay_safe.is_file(): fail("replay-safe policy-only variant is missing")
    replay_sql = replay_safe.read_text(encoding="utf-8")
    if re.search(r"(?im)^\s*update\s+public\.users\s+set\s+auth_user_id\b", replay_sql): fail("replay-safe variant contains an Auth identity UPDATE")
    if re.search(r"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", replay_sql): fail("replay-safe variant contains an email literal")
    if re.search(r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b", replay_sql, re.I): fail("replay-safe variant contains an identity UUID")
    for policy in ("patients_select", "patients_insert", "patients_update", "patients_delete"):
        if not re.search(r"(?im)^\s*create\s+policy\s+" + policy + r"\b", replay_sql): fail(f"replay-safe variant missing {policy}")
    print(f"PASS: frozen historical snapshot — {len(entries)} mappings; {matches} normalized SQL hashes verified; {placeholders} redacted placeholder.")
    print(f"PASS: separate forward-source delta — {len(delta_entries)} source files hash-verified; ledger metadata records {delta.get('live_ledger_count')} entries through {delta.get('latest_live_version')}.")
    print("LIMIT: no live SQL hash or database connection is checked by this workflow. Full historical replay and semantic equivalence remain unproven; see docs/live-migration-delta-2026-10-18.json and docs/DB_MIGRATION_RECONCILIATION.md.")
if __name__ == "__main__": main()
