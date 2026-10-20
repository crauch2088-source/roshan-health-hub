#!/usr/bin/env python3
"""Compare replayed PostgreSQL catalog with the captured live v115 manifest."""
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path("docs/live-catalog-fingerprint-v115.json").read_text(encoding="utf-8"))
if manifest.get("migration_version") != 115 or manifest.get("project_id") != "jewzonxplxhogqrnhosl":
    raise SystemExit("Expected the captured v115 fingerprint for project jewzonxplxhogqrnhosl.")
expected = manifest["categories"]
raw = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/roshan-catalog-fingerprint.json").read_text(encoding="utf-8").strip()
actual = None
for line in reversed(raw.splitlines()):
    try:
        value = json.loads(line)
    except json.JSONDecodeError:
        continue
    if isinstance(value, dict):
        actual = value
        break
if actual is None:
    raise SystemExit("Could not parse JSON catalog fingerprint from psql output.")
if set(expected) != set(actual):
    raise SystemExit(f"Fingerprint categories differ: expected={sorted(expected)}, actual={sorted(actual)}")
mismatches = []
for category in sorted(expected):
    exp, got = expected[category], actual[category]
    if exp.get("count") != got.get("count") or exp.get("sha256") != got.get("sha256"):
        mismatches.append({"category": category, "expected_count": exp.get("count"),
          "actual_count": got.get("count"), "expected_sha256": exp.get("sha256"),
          "actual_sha256": got.get("sha256")})
if mismatches:
    print(json.dumps({"exact_match": False, "matched_categories": 7-len(mismatches),
      "total_categories": 7, "mismatches": mismatches}, indent=2))
    raise SystemExit("Catalog fingerprint mismatch; exact parity has not been established.")
print(json.dumps({"exact_match": True, "matched_categories": 7, "total_categories": 7}, indent=2))
