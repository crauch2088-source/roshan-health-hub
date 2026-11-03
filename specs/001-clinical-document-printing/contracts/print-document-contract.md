# Print Document Contract

**Contract type:** Internal frontend presentation boundary; no new HTTP endpoint or database RPC.

## Input
A single typed view model for exactly one persisted document:
- document type and opaque internal ID
- branch ID
- saved document number/date where available
- language and canonical clinic identity
- document-specific saved fields

## Output
A printable semantic document root with:
- accessible title and document type
- saved source fields only
- clear incomplete/reversed/void state where applicable
- no navigation, action controls, edit forms, or unrelated records
- no public URL or patient-identifying QR payload

## Authorization
- Route-level permission checks remain in place.
- Supabase RLS and branch policies remain authoritative.
- The print component is not an authorization boundary.
- Reprint permission must be verified separately from create/read permission where the application distinguishes them.

## Failure behavior
- Missing record, soft-deleted record, mismatched branch relations, expired session, or denied read: do not render an official document.
- Missing required prescription instructions: block official prescription printing and show a safe explanation in the application UI.
- Missing clinic identity: show a neutral, explicit missing-configuration state; do not fabricate a clinic address/phone.
- Payment reversal: render the persisted reversal state, not a stale cached status.
- Browser print cancellation: no application data mutation.

## Explicit non-goals for v1
- Public document verification, public QR lookup, or patient-facing links.
- Server-side PDF generation or paid PDF services.
- Digital signature issuance or cryptographic signing.
- New audit tables or print-job history unless separately justified and approved.
- Automatic clinical completion or dose calculation.
