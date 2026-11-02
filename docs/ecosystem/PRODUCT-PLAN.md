# Fitsin + Crosstopher: product plan

Updated 2 November 2026. The owner has clarified the destination: a fully native, read/write Fitsin business workspace with redesigned workflows and the existing Crosstopher capabilities integrated. See [NATIVE-WORKSPACE.md](NATIVE-WORKSPACE.md) for the current brief, source coverage, proposed design, first complete journey and experiments. The wider catalogue below is retained for exploration; it is not blanket permission for live actions or every speculative feature.

## Purpose and starting point

Fitsin becomes the native iOS workspace for running the business, including read/write stock, camera capture and Bluetooth tags/stickers. Crosstopher remains the stock/marketplace backend authority and its existing web app continues to operate. Design the native workflows for the phone; do not reproduce the web layout or treat an external link as completion. The earlier summaries-and-links-first plan describes the completed foundation slice, not the full product destination.

User-reported figures, not a fresh production query:

| Measure | Reported position |
| --- | --- |
| Stock represented in Crosstopher | Approximately 33% |
| Recorded garments | 461 |
| Online garments | 168 |
| Drafts in-store but not online | 128 |

If 461 is about a third, total physical stock might be around 1,400, with around 900 outside the system. These are estimates, not stocktake results. Do not assume the status groups are exhaustive, disjoint or measured with identical filters. Inspect definitions before calculating percentages or classifying the remaining records.

Every workflow must support fully listed stock, partially recorded stock and legacy stock with no usable barcode. Recorded, SKU allocated, tag printed, tag attached and online are separate milestones. Import date is not arrival date.

Performance and usability are prerequisite work: see PERFORMANCE-PLAN.md. Adding more requests and cards to the existing slow app without fixing its loading model is not an acceptable delivery.

## A. Stock backlog and OCR

Reuse the existing stock/scan/print contracts and useful fixtures. The owner explicitly requests a native OCR overhaul: [NATIVE-SCANNER.md](NATIVE-SCANNER.md) defines continuous live recognition, grid/tag overlays, automatic acceptance of strong readings and live guidance/correction for exceptions. The web OCR engine and photo-review UX are not the required native design.

Desired native journey: select rail/session → point the live scanner at a tag → automatically capture a stable reading, correcting exceptions → match an existing record or create a garment/SKU → queue printing → confirm physical attachment. Capture must not automatically imply a trustworthy inventory record or a completed retag.

Candidate features:

- Scan tags continuously along a rail without a shutter/review form for every clean tag; keep garment photography separate.
- Offline capture, resumable uploads and review sessions; retain work through app closure.
- OCR suggestions for description, size, price and seller initials, with uncertain fields highlighted.
- Explicit confirmation of ambiguous/crossed-out prices and seller ownership; do not silently invent values.
- Retain original tag photos next to corrected readings; distinguish tag photos from garment photos.
- Human-reviewed duplicate suggestions using available text, size, price and images; match existing stock rather than recreate it.
- Reconcile retries/double taps without issuing multiple garments/SKUs.
- Track rail/rack/shelf/box and capture session.
- Separate queues for captured, needs review, registered, print pending, printed and attached.
- Batch print/reprint; recover from printer interruption and distinguish printed from successfully attached.
- Permit incomplete records and unknown fields while showing what is missing.
- Handle garments sold while capture/review/printing is outstanding.
- Stock coverage reporting with estimated versus verified denominators.
- Preserve a separate completion queue for existing drafts, including the reported 128 in-store drafts.

## B. Sales with incomplete inventory

Three first-class paths:

1. Scanned sale matched to a garment: link transaction, owner, images and lifecycle.
2. Manual sale matched by search: same result even if the new tag is not attached.
3. Unknown manual sale: record the money immediately, optionally capture description/photo, reconcile later.

Candidate features:

- Search by description, seller, size and price; suggest matches without silently choosing between similar garments.
- Mixed baskets with scanned and manual lines.
- A sales-needing-match queue; late matching enriches the same transaction, never creates another sale.
- Actual price paid, discounts, sale channel and payment method as distinct fields.
- Cash taken through Shopify POS is already a Shopify transaction, not an extra manual sale.
- Refund/return adjustments linked to original sale; return-to-stock is a deliberate physical-state decision.
- Matched/unmatched revenue coverage to expose reporting quality.
- Record a Vinted sale once, with confirmed actual amount, and eventually update reporting and delisting from that record.
- Seller statements and commission adjustments once ownership, actual proceeds and permissions are reliable.

## C. Image-led sales and notifications

Resolve the completed transaction's product/SKU to a garment, then use its first garment image if present. A scan into a basket is not a sale. A manual sale matched to a garment deserves the same image treatment.

- Recent-sales feed with thumbnails, amount, source, time and authorised seller detail.
- Sale detail with full image, item history and transaction links.
- Text/placeholder fallback for missing images; never block financial data on photo loading.
- Multi-item transactions: lead image plus count, with all lines in detail.
- Late matching adds imagery without sending a duplicate new-sale alert.
- Rich push image as a separate native implementation/validation slice, not assumed to work because the in-app image works.
- Preferences for all sales, own sales, milestones and operational alerts.
- Decide recipients and earnings visibility; existing notifications to the team do not imply blanket access to personal seller data.
- Plan authenticated/signed image access, expiry, cache eviction and lock-screen privacy.
- Tag-scan photos stay distinct from garment hero photos.

## D. Connected Today and daily briefing

Show sales versus target, monthly pace, image-led recent sales, rota and upcoming events alongside actionable stock work:

- Urgent pending Vinted removals and double-sale conflicts.
- Failed listings and missing marketplace information.
- Tags awaiting review, printing or attachment.
- Garments awaiting photographs or write-up.
- In-store garments ready to go online.
- Manual transactions awaiting a match.

Prioritise urgent sales/stock issues above routine backlog. Open the relevant native item/task workflow from each card; use external handoffs only where the provider requires them. Show last successful update per section and independent failure/retry states. Start any briefing with deterministic summaries; optional AI prose must remain grounded in measured facts.

## E. Existing stock to online stock

- Per-garment missing-fields checklist: photos, title, description, measurements, category and price.
- Separate needs-photo, needs-writing, needs-review and ready-to-publish queues.
- Batch photography by rail/category; handoffs between photographer, writer and reviewer.
- Stalled-draft reminders and channel-specific readiness explanations.
- Optional reviewed listing-copy suggestions based on confirmed facts.
- Image-quality checks and missing-photo warnings.
- Online coverage over eligible available stock, not every historical record.
- Weekly publishing goals alongside revenue goals.
- Prioritise by readiness, season, value or known time waiting.
- Preserve Vinted's existing human submit/removal boundaries; no unattended marketplace automation or scraping.

## F. Stock intelligence and sourcing

- Age by garment, location, brand and category; support approximate/unknown arrival dates for legacy stock.
- Time from arrival to capture, tagging, publishing and sale.
- In-store-only versus online availability.
- Asking-price inventory value distinct from cost and realised revenue.
- Actual margins where costs, fees and refunds are sufficiently known; display completeness.
- Selling speed, returns and channel comparisons.
- Suggestions for new photos, repricing, seasonal merchandising and slow-stock review.
- Evidence-based sourcing suggestions, not claims of guaranteed sales.
- Tag-price mismatch warnings after changes; do not silently overwrite physical tag state.

## G. Events and team operations

- Link an event to selected garments, preparation checklist and missing tag/photo checks.
- Explicit event-sale attribution and post-event performance; same-day sales are not automatically event sales.
- Staff handover notes linked to items/tasks.
- Assignable capture/review/listing batches; opening/closing checklists.
- Shift summaries with sales and unresolved issues.
- Stock movements between rails, storage and events.
- Later scan-based stocktakes: expected here, found elsewhere, not found.
- Task completion supports coordination; do not silently introduce staff performance scoring.

## H. Wider retained opportunities

- Complete garment timeline: capture, tag, listings, price changes, sale and return.
- Internal phone scan opens an item record.
- Separately permissioned public customer QR pages with measurements and selected content.
- Curated drops and themed collections.
- Content preparation using approved images/details; publishing is a separate action.
- Customer size/type requests matched to new stock; permissions and contact use need design.
- Reservations with expiry and coordinated inventory rules.
- Natural-language questions over authorised reliable records.
- Web companion for the Fitsin business dashboard.
- Shared backend later, or an eventual interface merge if justified; neither is a prerequisite for initial integration.

## Architecture and data choices

Proposed starting ownership:

- Crosstopher owns garment identity, listing lifecycle and stock transitions.
- Shopify owns its order/payment/refund facts; equivalent marketplace/manual facts need their own provenance.
- Fitsin owns targets and business-facing views; audit the actual calendar/rota authorities rather than assuming a README is current.
- The completed foundation exposes a scoped read-only summary; the new native workspace requires separate authenticated read/write contracts and full native workflows. Later financial records retain source account, external order/line identity, currency, event timestamps, actual amounts and adjustments. Manual records need stable internal IDs too.
- Deduplicate by transaction provenance, not garment SKU alone. A returned garment can legitimately sell again.
- Store money in a consistent exact representation (e.g. integer minor units) and define conversion from current decimal amounts.
- Use Europe/London business dates, preserving original timestamps. Separate payment method, channel and location.
- Preserve explicit unknown/unmatched ownership and provenance instead of guessing.
- A read-only bridge must not bypass seller isolation. Decide named identity and access before exposing seller summaries through the old shared app access.
- One stock authority: native Fitsin actions call Crosstopher commands, not independent inventory writes.
- Durable updates, retry/deduplication and periodic reconciliation are required before trusting combined money totals.

Verified local caveats from the exploration:

- Crosstopher `apps/worker/src/scope.ts` calculates `soldValue` from listing prices on closed items, not settled proceeds; closure can lag behind the sale while removals finish.
- Its sale handler records channel/time, not a complete financial transaction. Shopify webhook matching uses seller-scoped SKUs.
- Fitsin `backend/src/services/shopify.js` has fixed TA/AA name-prefix attribution and a 15% commission rate. Replace with explicit approved mappings/rules when integration scope permits; do not assume those rules represent every seller.
- Fitsin manual entries are amount/source/note records, not already item-linked transactions.
- Crosstopher supports seller-derived Access/token authentication. Documentation about exact deployment/auth state is not proof of live configuration.
- Existing Crosstopher specifications deliberately exclude cross-seller views, reporting and some wider features. The ideas here propose scope extensions; the owner must gate them, and any accepted changes should update those specifications explicitly.

## Historical catalogue sequence and gates

The native-first implementation sequence in NATIVE-WORKSPACE.md supersedes the summary/link endpoint implied by this earlier sequence. Keep the data/provider/action dependencies below when selecting experiments.

0. Prepare both repositories, inspect deployment/contract reality, establish performance and usability baseline.
1. Make Fitsin reliably usable: loading, caching, request orchestration, errors and navigation. Avoid an unmeasured rewrite.
2. Agree identity, permissions, garment mapping and transaction contracts.
3. Improve existing OCR/backlog plus draft-completion queues.
4. Add scoped Today summaries, item links and image-led sales; rich push separately.
5. Reconcile actual sales/refunds and reporting across manual and connected sources.
6. Select intelligence, events, stocktake and wider opportunities as data becomes reliable.

Some slices can overlap after dependencies are explicit. Retain every idea above even when a release defers it.

## End-to-end acceptance scenarios

- Unknown legacy garment sells manually without blocking checkout.
- Recorded garment without a new tag is matched by search.
- Scanned garment with no photo still produces a useful sale entry/notification.
- Mixed basket does not double-count cash or matched lines.
- Duplicate webhook, delayed event and late manual matching preserve one financial transaction.
- Partial refund and returned/resold garment remain distinguishable.
- Duplicate tag capture prompts matching, not duplicate SKU allocation.
- Capture offline, review later, print retry and attachment confirmation retain progress.
- A garment sold during backlog processing does not subsequently get published as available.
- Partial API failure leaves useful cached sections visible with honest freshness.
- Seller-specific data and caches never leak to another identity.
