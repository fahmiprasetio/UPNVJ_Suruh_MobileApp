# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Two roles sharing one app and one account model:

- **Clients** — UPN Veteran Jakarta (UPNVJ) students who need an errand or odd job done
  (a ride, food or item pickup, moving out of a boarding house, boarding-house or bathroom
  cleaning, or anything else via a free-form request) and place orders for it.
- **Runners** — UPNVJ students who accept broadcast jobs and complete the work for pay.

The surface that opens is decided by the active role, not by a separate build or account.
One account may hold both roles.

## Product Purpose

An errand and odd-job marketplace scoped to UPNVJ students: clients place an order, the
system broadcasts the job to available runners, and the first runner to accept takes the
work. Conversation, payment, and completion evidence all stay attached to the order they
belong to. Success is a job requested, quoted/priced, paid, run, and closed with evidence,
without the price or the paid state ever being something the client interface can assert on
its own.

## Positioning

A two-track pricing mechanism a neighboring product could not truthfully copy: **Track A**
(ride, food delivery, item delivery) prices from the form, shows the client the total before
ordering, and broadcasts the job the moment it's paid. **Track B** (moving, cleaning, and
every free-form request) can't be formula-priced — the client describes the need, an admin
reads it and asks questions in the order's own chat, then sends a quote with a price, a
duration estimate, and a schedule the team can commit to. The client accepts, asks for a
recalculation with a stated reason (which lands back in the same chat), or declines. Prices
never originate from the client on either track — they are computed and held server-side.

## Operating Context

- **Order lifecycle:** Request/AwaitingPayment → (Track B only: AwaitingApproval, with a
  recalculation loop back to Request) → AwaitingPayment → FindingRunner → InProgress → Done,
  with Cancelled reachable from Request and AwaitingPayment but not after payment.
- Only the payment gateway (via webhook) can move an order out of `AwaitingPayment` — the
  app has no way to declare itself paid.
- A paid order cannot be cancelled through the cancel endpoint; a refund is never a
  side-effect of one button.
- Jobs needing more than one runner stay broadcast until quota is filled; simultaneous
  acceptance is settled server-side under a serializable transaction with optimistic
  concurrency, not in the interface.
- Runners close a job with photo evidence, which stays attached to that order.
- Auth is JWT bearer tokens plus a one-time code over phone number.
- Payment is QRIS through a payment gateway, confirmed by webhook (the gateway partner
  itself is not yet chosen; the flow, contracts, and webhook are already in real shape).

## Capabilities and Constraints

- Six catalogued services plus one free-form door: Anter Jemput (ride/drop-off), Jastip
  Makanan (food delivery), Jastip Barang (item delivery/errand), Bantu Pindah Kos (moving
  out of a boarding house), Bersih-Bersih Kos (boarding-house cleaning), Bersih Kamar Mandi
  (bathroom cleaning), and Permintaan Lain (free-form request).
- Working end to end today: registration and sign-in, both order tracks, quotes, payment,
  broadcasting and claiming jobs, order chat, completion with photo evidence, role
  assignment.
- Not yet built (do not assume it exists): the admin dashboard's web surface (its API
  endpoints exist), live updates (the app still polls; a SignalR hub exists but isn't
  consumed yet), object storage for photo evidence, the payment gateway integration itself,
  and the food delivery form (pending a decision on who fronts the cost of goods).
- A mock data source (`SUMBER_DATA=tiruan`) lets screens be built without a live server; it
  is deliberately rejected in non-debug/release builds.
- Working/product language is Indonesian (bahasa Indonesia) — identifiers, screen names, and
  copy throughout the codebase are Indonesian (`klien`, `runner`, `lencana`, `pembuka`,
  etc.); this is the product's actual language, not an internal-only convention.

## Brand Commitments

- Name: **UPNVJ Suruh** ("suruh" = to send someone on an errand/task).
- Primary brand color: **#4B7043** (green) — confirmed by the user during this interview.
- Secondary/accent color: **#594370** (purple) — tentative only; the user described it as a
  complementary-generator suggestion, not a settled choice. Treat as an open decision, not a
  locked commitment, in future visual work.
- Neutral: **#F5F8F4**.
- This palette **supersedes** the navy/amber (`#16336B` / `#F5A524`) currently hardcoded in
  `mobile/lib/core/theme/app_theme.dart` — the code has not been updated to match yet; that
  update is future design/build work, not done by this record.
- The crocodile ("buaya") badge mascot and its processed logo asset
  (`mobile/assets/logo/lencana.png`, "lencana" = badge) were not raised for change when the
  palette was revisited — treat the mascot as still current pending explicit contrary
  instruction.
- The animated splash-screen sequence and its layered-overlay architecture (documented in
  `CATATAN_DEV.md`) are finished, deliberate work with dedicated regression tests
  (`mobile/test/features/pembuka_overlay_test.dart`) — not a placeholder to redo.

## Evidence on Hand

- Source logo art: `assets/logo-no-bg.png`, `assets/logo-white-bg.png`,
  `assets/logo-with-name.jpg`, `assets/tanpa nama.png`. Processed app asset:
  `mobile/assets/logo/lencana.png`.
- No customer testimonials, pricing/plan claims, press, or case studies exist anywhere in
  the project; future work must not fabricate any.

## Product Principles

1. Prices are never client-supplied — the client only ever confirms or reacts to a number
   the server already computed.
2. A paid state is reached only through the payment gateway's webhook, never through app
   logic — money movement is never a UI side-effect.
3. Track A optimizes for speed (formula price, instant broadcast); Track B optimizes for fit
   (human-quoted, negotiable in the order's own chat). The split exists because campus
   errands vary too much for one pricing model to serve both honestly.
4. Client and runner are two lenses on one account and one app, not two products — the
   surface follows the active role, not a separate build.
5. Evidence and conversation stay attached to the order they belong to, never floating in a
   separate space.

## Accessibility & Inclusion

No product-specific standard has been established yet (confirmed during this interview).
