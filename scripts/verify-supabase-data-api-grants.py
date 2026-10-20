#!/usr/bin/env python3
"""CI guard for Supabase Data API grants on new public tables after 2026-10-30."""
from pathlib import Path
import re, sys
ROOT = Path(__file__).resolve().parents[1]
CUTOFF = '20261030'
ROOTS = [ROOT / 'supabase' / 'migrations', ROOT / 'db']
CREATE = re.compile(r'\bcreate\s+(?:unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?(?:(?:public)\s*\.\s*)?([a-zA-Z_][\w$]*)', re.I)
def main():
    files = [p for root in ROOTS if root.exists() for p in root.rglob('*.sql')]
    errors, checked = [], 0
    for path in sorted(set(files)):
        m = re.match(r'(\d{8})', path.name)
        if not m or m.group(1) < CUTOFF: continue
        sql = path.read_text(encoding='utf-8')
        for table in CREATE.findall(sql):
            checked += 1
            for role in ('authenticated', 'service_role'):
                found = False
                for grant in re.finditer(r'\bgrant\s+([^;]+?)\s+on\s+(?:table\s+)?([^;]+?)\s+to\s+([^;]+);', sql, re.I | re.S):
                    target = re.sub(r'\s+', '', grant.group(2)).lower()
                    roles = [x.strip().lower() for x in grant.group(3).split(',')]
                    privileges = grant.group(1).lower()
                    if target in ('public.' + table.lower(), table.lower()) and role in roles and 'select' in privileges:
                        found = True
                if not found: errors.append(f'{path.relative_to(ROOT)}: {table} lacks explicit SELECT grant to {role}')
            pattern = r'\balter\s+table\s+(?:only\s+)?(?:public\s*\.\s*)?' + re.escape(table) + r'\b[^;]*\benable\s+row\s+level\s+security\b'
            if not re.search(pattern, sql, re.I | re.S): errors.append(f'{path.relative_to(ROOT)}: {table} lacks ENABLE ROW LEVEL SECURITY')
    if errors:
        print('Supabase Data API grant guard FAILED:\n' + '\n'.join('- ' + e for e in errors)); return 1
    print(f'Supabase Data API grant guard passed: {checked} table creation(s) checked in timestamped migrations dated >= {CUTOFF}.')
    return 0
if __name__ == '__main__': sys.exit(main())
