# Service disputes

Open a completed job's invoice and choose Report a problem / View report. Each completed job has a single report at requests/{requestId}/disputes/case. The driver selects extra charge, repair quality, incomplete service, or other and supplies a 10â€“1000 character description. Up to two compressed gallery photos are optional. A driver may have no photograph of a verbal charge demand, so evidence is not mandatory.

Both assigned participants see changes live. Provider responses (10â€“1000 characters) change Open to Under review. Only the driver can confirm Resolved, using an explicit confirmation dialog. A resolved case is read-only. Report descriptions, evidence, reporter IDs, invoice totals at reporting and creation time cannot be changed by either party. Firestore rules enforce these restrictions and reject unrelated accounts.

Invoice totals and payment confirmation remain independent of the dispute. The case captures the approved and final totals at creation; the invoice links existing quote/approval records. This does not process refunds, establish an admin verdict, or send background push. Under review means the participants are discussing the report; no administrator is automatically assigned. Administrative adjudication and escalation remain a future feature requiring the team's admin policy.

On Spark, Firestore real-time updates work while the screens are open. Deploy only Firestore rules after emulator verification; no Cloud Functions or billing upgrade is needed.