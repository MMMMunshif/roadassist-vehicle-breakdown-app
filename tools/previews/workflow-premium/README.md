# Premium service workflow preview

Standalone HTML/CSS/JS concept. Sample data only; no Firebase, requests, account changes, uploads or real payments. Production application files are not changed by this preview.

Open `index.html` in a browser. Query examples: `?screen=driver&embed=1`, `?screen=provider&embed=1`, `?screen=bill&embed=1`, `?screen=selection&embed=1`; add `&light=1` for the light appearance.

The four panels show different stages of one illustrative workflow, not simultaneous live sessions. Visit fees use the existing rule: Rs. 100 within the first km, then Rs. 20 for each additional started km. Example distances are straight-line. The car image is an illustration, not a photo of the sample driver's vehicle.

## Motion proposal

- Page changes: consistent 220–300ms fade/short slide. Preserve scroll and entered data on return.
- Provider/service selection: 140–200ms selection feedback and a shared summary into confirmation.
- Request submission: one-time 450–650ms sent-state transition only after server success; provider acceptance is a separate event.
- Active assistance: 400–600ms timeline state transition; map positions change only on real fresh location updates. Do not animate fabricated travel or ETA.
- Arrival: short 300–450ms acknowledgment after explicit driver confirmation.
- Final bill: 350–500ms contextual bill-sheet transition. Summary saved with submission; replacement estimates only when applicable. Display charges accurately without decorative fake totals.
- Cash/bank payment report: move to receipt-pending state, never a paid-success animation. Provider receipt confirmation (or genuine gateway confirmation in a future release) may show a 600–800ms check/receipt reveal.
- Editing, chat, settings: small press/focus/selection feedback, not repeated full-screen animation.
- Errors/offline: concise persistent explanation, saved draft/selection, meaningful retry; progress shown only when backed by actual work.
- Admin review/suspend/restore/delete: retain authorization, confirmation and audit behavior; animate final state only after server success.
- Respect OS reduced-motion and accessibility settings. Avoid idle loops and effects that delay emergency, cancellation or payment actions.

## Checks

`capture.py` renders dark/light comparison images and records driver/payment demos under `build/previews/workflow-premium/`. Browser checks cover original assets, arrival confirmation, non-negative bill amounts, provider fee selection, interrupted connection/retry, separate payment-report vs receipt-confirmed states, modal Escape and reduced motion.
