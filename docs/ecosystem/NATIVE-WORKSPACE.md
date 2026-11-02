> Local implementation update, 2 November 2026: see [NATIVE-IMPLEMENTATION.md](NATIVE-IMPLEMENTATION.md), [NATIVE-API.md](NATIVE-API.md) and [NATIVE-LOCAL-EVIDENCE.md](NATIVE-LOCAL-EVIDENCE.md) for current implemented scope, protocol and actual Mac results. Earlier planning/cloud-only status below is historical.

# Fitsin native business workspace — revised product direction

Owner clarification, 2 November 2026. This supersedes treating a read-only stock summary plus an external link as the finished integration. This is a product/design brief and implementation sequence; the native workflows below are not yet implemented by the existing foundation PRs.

The next session runs on the owner's Mac. [NEW-SESSION-GOAL.md](NEW-SESSION-GOAL.md) turns this brief into the authorised continuous build sequence, including tests, optional rail/stocktake preparation, completion criteria and boundaries. Do not stop at this design brief or after the first journey to request routine continuation approval.

## Product intent

Fitsin is the team's native iOS workspace for running the business: stock, photography, tags, sales, payments, events and day-to-day work. It reads and writes through the existing business systems, with an interface designed around work on an iPhone. Crosstopher's current web app remains usable alongside it, while its backend continues to own stock and marketplace rules. Functional coverage should include the existing Crosstopher capabilities, rather than copying its layout or opening a web viewer to complete ordinary tasks.

The product is deliberately exploratory. Build usable native journeys, learn from trying them, and propose useful combinations of the two systems. The full opportunity catalogue in PRODUCT-PLAN.md remains available. A new idea should have a concrete user benefit, a testable interaction and clear data requirements; it need not wait for a final specification of the whole product.

Confirmed owner decision: **one shared Fitsin business first; separate businesses later**. Design for business-scoped data and membership, but do not build a multi-business SaaS product or force staff into separate sellers for the first version. Preserve current shared staff access; do not create or merge seller records or introduce per-person stock restrictions. A business tenant, a staff member and a Crosstopher seller are different concepts, even when the first business maps to one existing seller.

## Live scanner clarification

The owner requires a native live tag scanner with grid/framing overlays, continuous recognition, lighting/focus guidance and automatic acceptance of sufficiently evidenced readings. Ordinary clean tags should not require a photograph followed by a review form. Uncertain readings remain live and improve as the view improves. This authorises an overhaul of the native recognition experience while preserving existing web/backend operation. See [NATIVE-SCANNER.md](NATIVE-SCANNER.md) for the interaction, temporal/field acceptance rules, duplicate handling and actual-device evaluation. Build this prototype early.

## Optional locations and research expansion

The scanner should support future rail assignment and stocktaking as separate modes. The owner has ten upstairs rails, with an unknown future basement count; use configurable location identities, not a fixed ten-rail layout. Select/scan a rail and batch-scan item barcodes, while keeping location optional during initial listing. [LOCATIONS-STOCKTAKE.md](LOCATIONS-STOCKTAKE.md) defines the proposed workflows, movement/observation distinction, research extension and recommended adjacent features. Make room for this without delaying the core native workflow or presenting unused future tabs.

## What the current source actually provides

| Capability | Existing source / constraint | Native work needed |
| --- | --- | --- |
| Stock search/edit and item history | Worker item read/upsert/history APIs; current web sync and local outbox | Native stock repository, local persistence, image list/search, detail/edit and conflict handling |
| Garment photography | Worker photo metadata/upload/read; separate original/web variants | Native camera/library capture, ordering, durable uploads, thumbnail pipeline and access-aware caching |
| Backlog tag capture and review | Existing scan APIs, duplicate hash/confirmation handling; browser Tesseract and review rules | Native continuous tag scanning with tracked overlays and automatic high-evidence capture; use web fixtures as failure examples, not a requirement to preserve unreliable parsing/UX. See NATIVE-SCANNER.md; preserve the stock backend |
| SKU creation | Per-device reserved blocks and immutable SKU rules | Native reservation/assignment that survives offline creation/retry without duplicates |
| Bluetooth tags/stickers | `apps/web/src/printer.ts` speaks to the owned Phomemo M02; 384-dot raster, block/chunk limits and reconnect/release behavior | CoreBluetooth transport, native raster/barcode rendering, serial print queue, explicit uncertain-print/reprint states and hardware verification |
| Print history and stock transitions | Existing tag-printed command; confirm/print paths can activate stock and queue POS creation | Reuse the actual command semantics, distinguish bytes sent from verified physical output, and avoid duplicate side effects after a lost response |
| Listings and operational queues | Publish/preflight, manual listed/removed confirmations, retry, pull/restore, review questions, duplicate removal and deletion commands | Native actionable queues and contextual item actions, showing restrictions and consequences before destructive operations |
| Vinted | Human posting/removal; desktop extension is the current form-filling mechanism | Native preparation, copy/share/media handoff and confirmations; assess official mobile capabilities. Do not promise an iOS Chrome extension or unattended submission |
| Sales and business views | Existing Fitsin sales/day/month/manual-entry/payout-marker APIs; not a reconciled processor ledger | Native sale-to-item relationships, explicit unmatched cases and a coherent sales/detail experience before richer reporting |
| Calendar, rota and team | Google Calendar is the active native calendar path; rota/schedule are separate Fitsin services | Unified planning/handover interactions with explicit account/calendar context and safe asynchronous loading |
| Account/setup/admin | Current seller tokens/Access and channel configuration; diagnostics can call live services | Native account/settings surface with explicit business binding. Do not put shared server bridge secrets or marketplace secrets in the app |

This is the initial coverage map, not a declaration that every existing endpoint is safe to expose as a button. Maintain a detailed function-to-screen/test inventory during implementation, including less visible settings, review answers/mappings, deleted-item history and channel setup. Product completeness is measured by supported user journeys, not matching web screens one for one.

The current code demonstrates Shopify order/sales reads and Google Calendar events. It does not establish a general card-processor event stream, settlements, fees or chargebacks. Confirm the available payment facts before promising features based on them. Receiving a sale does not itself prove settled funds.

## Proposed native navigation

Use this as a first design to test, not a frozen sitemap:

- **Today:** money/pace, today's people/events and a short ordered list of actions. A task opens the native item/workflow that resolves it. Urgent conflicts/removals precede routine photo/tag work. Sections load independently.
- **Stock:** fast local search and photo-led rows, practical filters and saved work queues. One garment record connects photos, tag state, location when supported, listings, sales and history. Search and selection survive returning from an edit.
- **Capture:** immediate live tag/barcode scanner, with overlays, automatic stable-read capture and an accepted-items tray. Keep reading uncertain fields live; correct only exceptions. Persist each accepted read before advancing. Garment photography is a separate native camera/library action; item creation and printing remain in the same working flow.
- **Sales:** today's activity and sale detail linked to garments where known. Show actual source amounts/channel and honest unmatched/refund states. Recording a manual sale and matching an existing payment are visibly different actions.
- **Work:** calendar, rota, handovers and task batches. Printer connection/queue is reachable from capture and item detail; account/integration settings live outside the daily task path.

An item should have a small set of context-appropriate primary actions, not a long copy of the web editor. For example: a draft with no photo offers Take photos; an item needing a tag offers Print; a failed listing opens the missing question; a sold item offers its sale/history and outstanding removals. Destructive actions retain deliberate confirmation.

## First complete journey to build

**Find a garment or scan its tag live → automatically accept a stable reading (edit exceptions) → save → print a sticker → continue to the next garment.**

1. Prototype the live scanner early alongside native stock list/search, item detail and editing, using synthetic fixtures and the existing command contracts. Include a distinct native garment-photo path. Use NATIVE-SCANNER.md for readiness/auto-capture behavior.
2. Scoped local store/outbox and authenticated read/write client; local saves are immediate and display pending/synced/failed honestly. Validate retries and concurrent web/native edits before claiming them safe.
3. CoreBluetooth M02 pairing/reconnect/release, print preview and serial queue. Reuse the existing packet/raster constraints and test against known-good fixtures. Hardware acceptance uses the actual printer; browser success does not prove iOS success.
4. Connect live scanning, exception correction, SKU allocation and printing into the loop. Network loss or app restart must not lose photos, edited fields, queue order or command identity. An uncertain physical print asks for inspection/reprint; it cannot be made exactly-once by a network idempotency key.
5. Exercise the same garment in the existing web app and native app to prove they are extensions of one stock system. Preserve current confirmation/POS side effects; use isolated fixtures, never real stock, during development.

This is a complete, useful slice that can expose design problems early. It is the start of full native coverage, not a permanent restriction to only these operations. Next add the operational queues/listing controls, then connected sale/detail flows and the strongest business-work experiments.

## Combinations worth exploring

| Experiment | Concrete interaction | What must be true / how to judge it |
| --- | --- | --- |
| Sale to stock story | Tap a sale to see the actual garment/photo, source amount, sale channel and any removal work; resolve the task in place | Stable source-account/order/line-to-garment mapping; count unmatched lines; no double-counting or duplicated alerts |
| Ten-minute shop-floor jobs | Choose a short queue: photograph these five items, print these tags, answer these listing questions; stay in a focused batch | Explain why each item is included; measure tasks completed and taps versus current workflows, not staff performance |
| Event preparation | Open an event, choose stock, see missing photos/tags, print a batch and prepare a packing checklist | Explicit garment/event association; sales attribution cannot be inferred just from the date |
| Retag assistant | A price edit shows the last printed price and offers a replacement sticker | Persist printed-version information and require physical attachment confirmation; current print count is insufficient |
| Stock/payment mismatch inbox | A source sale cannot match a garment, or a garment marked sold lacks a corresponding amount; open an actionable review | Source provenance and coverage, no guessed refunds/settlements; enrich an existing transaction rather than create another |
| Return at the rail | Open the original sale/garment, inspect the item, choose return-to-stock and reprint if needed | Payment refund and physical stock return are separate deliberate operations; requires transaction/refund contract work |
| Handover with objects attached | Leave “these three need photos” or “this sale needs checking” with links that open the right native action | Staff actors and task identity; shared business access remains the default unless the owner changes it |
| Evidence-based stock suggestions | “These available jackets have no usable photos” or “these drafts have waited longest”; jump into a batch | Explain source/time/completeness. Do not present speculative demand, arrival dates or margin as facts |

Prefer a working screen and one real synthetic journey over speculative dashboards. For each experiment record: hypothesis, available inputs, a small prototype, observed use, then keep/change/drop. Extra provider permissions, paid AI services, notifications, public sharing and live marketplace actions remain separate decisions.

## Architecture and speed requirements

- SwiftUI for the application UI; native camera/photo APIs and CoreBluetooth for device functions. Core daily workflows do not use a web viewer. External provider login or unavoidable marketplace handoffs are explicit boundaries.
- Crosstopher remains the stock command authority. Add or adapt authenticated API contracts where needed rather than letting the native app write database rows or fork marketplace rules.
- The read-only stock-summary key remains read-only. Do not turn the embedded Fitsin shared app code or the server bridge secret into a broad write credential. Design revocable user/device sessions resolved to business membership and an explicit existing seller/account mapping.
- Keep marketplace credentials server-side. Validate business/seller scope on every request and server-derived operation; scope local databases, image caches, pending uploads and outboxes as well. Switching business must never send the previous business's pending work to the new one.
- For one business, all staff can share the agreed data while actions still record an actor for recovery/history. Actor attribution does not require inventing per-person seller restrictions.
- Durable command IDs, safe retries, explicit pending/failed status and server conflict checks are required for writes. Preserve existing IDs and state-machine behavior; introduce backward-compatible changes and prove web/native coexistence.
- Native UI alone does not guarantee speed. Render cached lists immediately, use thumbnails, avoid decoding large photos on the main thread, fetch independently and avoid refreshing the whole catalogue after every action. Measure launch/search/open/save/first-photo behavior on the iPhone.
- The current full-sync client prunes rows missing from a complete snapshot. Do not add a server-only page limit to make the native list appear faster. Any delta/pagination protocol needs a complete-snapshot contract and compatibility testing.

## Implementation order and evidence

1. Native design prototypes including the live scanner and full parity inventory, using synthetic repositories. Test the proposed navigation and continuous scanning through the first complete journey.
2. Business identity/read-write contract, scoped storage/outbox and conflict/retry test fixtures. Use the confirmed shared-business scope; design explicit business/seller mapping without provisioning production accounts. Separate-business onboarding comes later.
3. Stock/detail/edit/photo vertical slice, then native Bluetooth and the capture/review/print loop.
4. Operational queues, questions, listing/state controls, history and settings; retain provider-required handoffs explicitly in the parity inventory.
5. Connected sales/item detail and event/work experiments selected for usefulness. Reconciliation, payment operations, rich push and other independently consequential features retain their own contracts/tests/action gates.

Record what is actually implemented, simulated, executed on Mac/simulator, or validated on hardware. Batch hardware work intelligently, but do not claim Bluetooth, camera/OCR quality, accessibility or native performance from cloud tests. Existing foundation PR test evidence remains historical for those revisions, not acceptance of this new product.

Development of the native read/write workspace and design exploration is the new direction. Do not ask for a separate approval for each ordinary native screen or scoped implementation step. Continue complete journeys and their tests autonomously; seek input when a real business-rule ambiguity or an independently restricted external action needs a decision. Merge/deployment, production credentials/migrations, live stock publish/delist, notification/message sending and purchases are still not authorised by this brief. No runtime or production configuration is changed by this document.
