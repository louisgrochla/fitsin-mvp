> Local implementation update, 2 November 2026: see [NATIVE-IMPLEMENTATION.md](NATIVE-IMPLEMENTATION.md), [NATIVE-API.md](NATIVE-API.md) and [NATIVE-LOCAL-EVIDENCE.md](NATIVE-LOCAL-EVIDENCE.md) for current implemented scope, protocol and actual Mac results. Earlier planning/cloud-only status below is historical.

# Dependency-ordered delivery backlog

Current execution mandate: [NEW-SESSION-GOAL.md](NEW-SESSION-GOAL.md) authorises continuous local Mac implementation of the native workspace, scanner, photos/printing, connected workflows and minimal optional rail/stocktake module. Historical approval questions below are not new gates for that included development. Local synthetic migrations are included; production migrations, live actions and the separately excluded catalogue features remain outside scope. Run automated native checks throughout and batch owner-assisted physical/manual acceptance at the end.

Latest direction: [NATIVE-WORKSPACE.md](NATIVE-WORKSPACE.md) defines the native read/write Fitsin workspace and supersedes a read-only summary/link as the final product. Native photos/capture/printing and existing stock actions belong in that destination; design and development proceed in complete journeys. Existing financial/provider/live-action requirements remain. The owner confirmed one shared Fitsin business first, with separate businesses later.

All product ideas are retained. F0, the manual-store aggregation/serialization/corruption safeguards of F1, and the first default-off I1/C1 read-only bridge are implemented for review; see STOCK-BRIDGE.md. “Existing” means source/test evidence at the synchronised commits; it does not assert live deployment or hardware success. Remaining work requires its feature/release gate. Cross-seller access, paid services, publishing, delisting, migrations and notifications are not implicitly authorised by this plan.

## Native scanner update

[NATIVE-SCANNER.md](NATIVE-SCANNER.md) supersedes the earlier photo-first OCR/native-adapter assumption: live camera overlays, continuous per-field recognition, calibrated automatic acceptance and exception correction are required. Prototype this early. Existing backend/web behavior remains; no scanner/hardware test result is implied.

## Optional rail/stocktake expansion

The owner wants future reuse of the scanner for rail assignment and stocktakes: ten upstairs rails now, any number in the basement later, and no mandatory rail field at initial listing. [LOCATIONS-STOCKTAKE.md](LOCATIONS-STOCKTAKE.md) refines B3/O3 with stable locations, explicit assignment/count modes, resumable batches, discrepancy handling and separate research predictions. This records the extension direction; implementation and live/research activation are not claimed.

## Current owner decisions — 2 November 2026

Initial audience: one existing Crosstopher seller/business, with multiple people sharing access to all of its data in both applications. Preserve Crosstopher as it operates today. Per-person seller restrictions and multi-seller expansion are deferred; preserve existing server-side seller boundaries. I1's audience question is resolved for this phase, bridge authentication and server-side selection are implemented; actual source-account bindings and activation remain unconfigured.

Batch Mac/Xcode/device/manual verification at the end of the intended changes. Continue authorised cloud slices and their automated checks before that batch. Native acceptance remains required before release readiness, and every new feature keeps its gate.

## Reviewable slices

| ID / gate | Existing capability → required work | Dependencies | Acceptance and verification | Owner decision |
| --- | --- | --- | --- | --- |
| F0 / 1 | TTL cache, retry helper, Today/Month views and full stock sync → coalescing, invalidation fencing, deadlines, independent sections, failed-save retention, linear child grouping | Baseline audit | Cloud tests/benchmarks pass without changed totals, payloads or scope; native tests and manual checklist remain pending | Review branches and nominate Mac/device route before release |
| F1 / 1 follow-up | Atomic JSON and local caches → serialised writes, aggregate cap correction, scoped/versioned async caches, captured calendar query keys, bounded memory/disk | F0 review | Simultaneous writes retain both records; >1,000 manual rows reconcile; stale calendar responses cannot overwrite selected month; account switch cannot reuse prior cache; device I/O profile | Confirm compatibility/data-retention policy; separately authorise any schema/storage migration |
| I1 / 2 | Initial server-bound single-business bridge with dedicated read-only key implemented; no new disk cache | F0; approved shared audience | Foreign-seller/credential isolation and connected cloud route pass; native/browser and production Access remain pending | Audience settled; exact live binding/credential provisioning and activation are separate. Per-person permissions/multi-seller expansion deferred |
| I2 / 2 | Immutable SKU, seller-scoped webhook match → durable external item mapping, explicit unknown/ambiguous ownership | I1 | Exact SKU/variant match within source account; identical descriptions never auto-select; legacy stock retains unknown owner; no duplicate SKU allocation | Owner mappings, lookup rules and legacy reconciliation responsibility |
| T1 / 5 | Fitsin dated manual amounts/day lines, Crosstopher lifecycle sale → provenance ledger, scanned/search/unmatched paths, mixed baskets and reconciliation queue | I1, I2, F1 | Duplicate/delayed events and manual retries remain one transaction; POS cash counted once; actual paid/discount/channel/payment distinct; late match changes no total; independent unmatched coverage | Which transactions count toward targets; money/currency/rounding and source-of-truth rules; first entry surface |
| T2 / 5 | Source order current totals, lifecycle closure → explicit refunds/returns/resale and durable reconciler | T1 | Partial refund references original line; same SKU resold is new transaction; return-to-stock is deliberate; replay/out-of-order fixtures reconcile | Refund authority, allocations, retention and stock-return procedure |
| T3 / 5 | Existing 15% prefix rules and paid flags → approved seller statements/commission versions and payout adjustments | T2 | Discount/refund/fee examples reconcile to confirmed proceeds and statement totals; payment flag not presented as bank proof | Seller agreements, who may mark/see payouts, accounting review |
| B1 / 3 | Capture/OCR/Dexie/review already present → validate and refine uncertain readings, restart/import recovery and original-photo policy | F0 review | Twenty permitted representative tags scored right/blank/wrong; no incorrect price silently confirmed; offline capture/reopen/retry retains each photo; human owner confirmation | Representative photos, original retention, acceptable OCR error rate; no metered model default |
| B2 / 3 | Hash dedup, confirm guards, twins review → explicit match-to-existing flow where approved | B1, I2 | Double taps/retries create at most one item; ambiguous physical twins require human review; no mutation of unrelated live stock; sold match cannot republish | Match/merge/discard policy, allowed edits to existing items |
| B3 / 3 | Print queue, shutter order, print history → location/session records and separate captured/reviewed/registered/printed/attached states | B1, I2 | Printer disconnect/reprint preserves progress; attachment requires human acknowledgement; sold-during-review/print cannot become available; tag-price mismatch stays visible | Rail/location vocabulary, strip versus replacement, attachment responsibility |
| B4 / 3 | “To write up”, in-store/online tabs → broader missing-fields/draft completion queues | I2, B1 | Existing photographed/unwritten rule preserved; all incomplete draft categories visible with reasons; reported 128 is reconciled against definitions, not assumed | Definition of complete/eligible draft and workflow host |
| C1 / 4 | Separate summaries and task URLs → read-only scoped stock summary bridge | I1, F1 | Removals/conflicts first; independent timestamps/error/empty states; failure in stock does not block financial/calendar sections; deep links enforce auth; no stock writes | Initial shared-business audience approved; first operational counters implemented default-off, final local batch and activation/release review pending |
| C2 / 4 | Day line details and ordered garment photos → in-app image-led recent sales/detail | C1, I2, T1 | First garment image, placeholder on missing/expired image; manual matches same treatment; multi-item count/detail; late match no duplicate alert; image fetch never blocks amounts | Image variants, retention and seller detail visibility |
| C3 / 4 separate native gate | Existing APNs text/preferences/deep links → rich-image extension and recipients/privacy | C2, T1 | Signed-link expiry/failure/offline fallback, notification dedup and all/own/milestone/operational preferences; real APNs/device/lock-screen tests | Recipients, lock-screen earnings/image policy, Apple build route |
| C4 / 4 | Targets/rota/events and individual queues → connected Today/deterministic daily briefing | C1, B3, B4, T1 | Prioritise urgent removals/failures, then review/print/attachment/photo/write/publish/match tasks; every number links to source and freshness; optional prose cannot invent facts | Card order, daily timing; explicit separate gate for any AI prose |
| E1 / 3–4 | Editor, photos, channel readiness, Vinted human actions → completion checklists, batches/handoffs, stalled reminders, photo quality, eligibility/goals/prioritisation | B4, B3 | Missing fields explain each channel; only eligible available stock in coverage denominator; unknown age not treated as old; publish/submit/removal remain deliberate human actions | Eligibility rules, weekly publishing goal, reminders and assignees |
| E2 / later | Authored listing fields → optional reviewed listing-copy suggestions | E1 | Suggestions use confirmed facts, retain provenance, require review; no auto-publication or invented brand/measurements | Whether wanted, acceptable provider/cost and approval workflow |
| S1 / 6 | Created/sold/tag timestamps, costs/list prices → completeness-aware age, availability, cycle time, values/margins/channel reports | T2, B3, E1 | Unknown/approximate arrival distinct from import; asking value separate from revenue/cost; fees/refunds completeness explicit; matched/unmatched/verified denominators visible | Arrival policy, cohort definitions, approved reporting metrics |
| S2 / 6 | Stock/category history → slow-stock, photo/reprice/seasonal and sourcing suggestions | S1 | Suggestions cite evidence and data quality; no guaranteed sales or unattended repricing; preserve physical tag state | Business rules and decision owner |
| O1 / 6 | Google events and garment records → linked event stock/preparation and explicit sale attribution | I2, B3, T1 | Missing tag/photo checks; same-day non-event sale excluded; event report reconciles to attributed transactions | Calendar authority/permissions and attribution method |
| O2 / 6 | Rota and work queues → linked handover notes, assigned batches, opening/closing lists and shift summaries | C1, B3, T1 | Tasks link to items; pending issues survive shift changes; summaries reflect source freshness; no staff ranking/scoring | Who can assign/edit/read, retention and handover routine |
| O3 / 6 | SKU scanning/locations → movements and physical stocktake | B3, I2 | Expected/found-elsewhere/not-found cases persist; count completion never implies sale or changes ownership; offline scan/retry tested with hardware | Stocktake authority, discrepancy resolution and location taxonomy |
| W1 / later | Item events/tag logs → full timeline and internal phone scan-to-record | I2, B3, T2 | Capture/tag/listing/price/sale/refund events preserve chronology/provenance; barcode opens only authorised item; no price overwritten silently | Timeline retention and internal scan entry point |
| W2 / later | Garment images/details → separately permissioned public customer QR | I1, I2 | Public allowlist excludes seller finances/scans/private notes; revoked access and shared URLs tested; selected measurements shown accurately | Exactly what is public and whether public access is wanted |
| W3 / later | Garment content → curated drops/collections and content preparation | E1, W2 | Only approved images/details selected; preparation does not publish; unavailable/reserved stock handled | Curation/publishing approvals, channels and schedule |
| W4 / later | No customer request workflow → consented size/type requests matched to stock | I1, I2 | Permissioned contact use, opt-out/deletion and human-reviewed matches; no unsolicited messages | Consent, recipients, retention and contact policy |
| W5 / later | Quantity-one state machine → reservations with expiry | I2, T1 | Expiry/concurrent sale/offline retry cannot double-reserve or silently reopen sold stock; authority reconciles | Reservation policy, expiry, deposits and channels |
| W6 / later | No cross-system question service → natural-language questions over authorised reliable records | I1, S1, T2 | Answers cite records, scope and freshness; refuse unsupported totals; adversarial permission tests | Scope/provider/cost and human review |
| W7 / later | Native Fitsin + existing Crosstopher web → Fitsin web companion | F1, I1, C1 | Same scoped contracts and freshness, responsive/a11y task checks, no independent financial logic | Need/audience; keep native app as default |
| W8 / later | Separate services with clear authorities → shared backend or eventual interface merge if justified | Measured evidence from F0, I1, C1 and owner architecture gate | Concrete migration/rollback rehearsal, old-client compatibility, no split stock authority or permission regression | Whether benefits justify cost/risk; not required for any first bridge |

## Product-plan traceability

The following rows preserve every A–H candidate bullet verbatim. A slice can cover multiple related bullets; its dependency, acceptance and owner gate above apply to each mapped idea. Product-plan prose additionally requires: all three scanned/search-matched/unknown-manual sale paths (T1); mixed legacy/new stock and separate arrival/import dates (I2/S1); current sales/target/monthly pace/rota/events alongside stock tasks (C4); independent freshness and deep links (C1/C4); deterministic briefing before optional AI prose (C4); durable reconciliation and exact money (T1/T2); and retaining both interfaces initially (W7/W8).

| Idea ID | Retained idea | Slice |
| --- | --- | --- |
| A01 | Batch photograph a rail without filling forms between shots. | B1 |
| A02 | Offline capture, resumable uploads and review sessions; retain work through app closure. | B1 |
| A03 | OCR suggestions for description, size, price and seller initials, with uncertain fields highlighted. | B1 |
| A04 | Explicit confirmation of ambiguous/crossed-out prices and seller ownership; do not silently invent values. | B1/I2 |
| A05 | Retain original tag photos next to corrected readings; distinguish tag photos from garment photos. | B1 |
| A06 | Human-reviewed duplicate suggestions using available text, size, price and images; match existing stock rather than recreate it. | B2 |
| A07 | Reconcile retries/double taps without issuing multiple garments/SKUs. | B2 |
| A08 | Track rail/rack/shelf/box and capture session. | B3 |
| A09 | Separate queues for captured, needs review, registered, print pending, printed and attached. | B3 |
| A10 | Batch print/reprint; recover from printer interruption and distinguish printed from successfully attached. | B3 |
| A11 | Permit incomplete records and unknown fields while showing what is missing. | B4 |
| A12 | Handle garments sold while capture/review/printing is outstanding. | B3 |
| A13 | Stock coverage reporting with estimated versus verified denominators. | S1 |
| A14 | Preserve a separate completion queue for existing drafts, including the reported 128 in-store drafts. | B4 |
| B01 | Search by description, seller, size and price; suggest matches without silently choosing between similar garments. | I2/T1 |
| B02 | Mixed baskets with scanned and manual lines. | T1 |
| B03 | A sales-needing-match queue; late matching enriches the same transaction, never creates another sale. | T1 |
| B04 | Actual price paid, discounts, sale channel and payment method as distinct fields. | T1 |
| B05 | Cash taken through Shopify POS is already a Shopify transaction, not an extra manual sale. | T1 |
| B06 | Refund/return adjustments linked to original sale; return-to-stock is a deliberate physical-state decision. | T2 |
| B07 | Matched/unmatched revenue coverage to expose reporting quality. | T1/S1 |
| B08 | Record a Vinted sale once, with confirmed actual amount, and eventually update reporting and delisting from that record. | T1 |
| B09 | Seller statements and commission adjustments once ownership, actual proceeds and permissions are reliable. | T3 |
| C01 | Recent-sales feed with thumbnails, amount, source, time and authorised seller detail. | C2 |
| C02 | Sale detail with full image, item history and transaction links. | C2/W1 |
| C03 | Text/placeholder fallback for missing images; never block financial data on photo loading. | C2 |
| C04 | Multi-item transactions: lead image plus count, with all lines in detail. | C2 |
| C05 | Late matching adds imagery without sending a duplicate new-sale alert. | C2 |
| C06 | Rich push image as a separate native implementation/validation slice, not assumed to work because the in-app image works. | C3 |
| C07 | Preferences for all sales, own sales, milestones and operational alerts. | C3 |
| C08 | Decide recipients and earnings visibility; existing notifications to the team do not imply blanket access to personal seller data. | I1/C3 |
| C09 | Plan authenticated/signed image access, expiry, cache eviction and lock-screen privacy. | C2/C3 |
| C10 | Tag-scan photos stay distinct from garment hero photos. | C2 |
| D01 | Urgent pending Vinted removals and double-sale conflicts. | C1/C4 |
| D02 | Failed listings and missing marketplace information. | C1/C4 |
| D03 | Tags awaiting review, printing or attachment. | C4/B3 |
| D04 | Garments awaiting photographs or write-up. | C4/B4 |
| D05 | In-store garments ready to go online. | C4/E1 |
| D06 | Manual transactions awaiting a match. | C4/T1 |
| E01 | Per-garment missing-fields checklist: photos, title, description, measurements, category and price. | B4/E1 |
| E02 | Separate needs-photo, needs-writing, needs-review and ready-to-publish queues. | B4 |
| E03 | Batch photography by rail/category; handoffs between photographer, writer and reviewer. | E1 |
| E04 | Stalled-draft reminders and channel-specific readiness explanations. | E1 |
| E05 | Optional reviewed listing-copy suggestions based on confirmed facts. | E2 |
| E06 | Image-quality checks and missing-photo warnings. | E1 |
| E07 | Online coverage over eligible available stock, not every historical record. | E1/S1 |
| E08 | Weekly publishing goals alongside revenue goals. | E1 |
| E09 | Prioritise by readiness, season, value or known time waiting. | E1 |
| E10 | Preserve Vinted's existing human submit/removal boundaries; no unattended marketplace automation or scraping. | E1 |
| F01 | Age by garment, location, brand and category; support approximate/unknown arrival dates for legacy stock. | S1 |
| F02 | Time from arrival to capture, tagging, publishing and sale. | S1 |
| F03 | In-store-only versus online availability. | S1 |
| F04 | Asking-price inventory value distinct from cost and realised revenue. | S1 |
| F05 | Actual margins where costs, fees and refunds are sufficiently known; display completeness. | S1 |
| F06 | Selling speed, returns and channel comparisons. | S1 |
| F07 | Suggestions for new photos, repricing, seasonal merchandising and slow-stock review. | S2 |
| F08 | Evidence-based sourcing suggestions, not claims of guaranteed sales. | S2 |
| F09 | Tag-price mismatch warnings after changes; do not silently overwrite physical tag state. | B3/W1 |
| G01 | Link an event to selected garments, preparation checklist and missing tag/photo checks. | O1 |
| G02 | Explicit event-sale attribution and post-event performance; same-day sales are not automatically event sales. | O1 |
| G03 | Staff handover notes linked to items/tasks. | O2 |
| G04 | Assignable capture/review/listing batches; opening/closing checklists. | O2 |
| G05 | Shift summaries with sales and unresolved issues. | O2 |
| G06 | Stock movements between rails, storage and events. | O3 |
| G07 | Later scan-based stocktakes: expected here, found elsewhere, not found. | O3 |
| G08 | Task completion supports coordination; do not silently introduce staff performance scoring. | O2 |
| H01 | Complete garment timeline: capture, tag, listings, price changes, sale and return. | W1 |
| H02 | Internal phone scan opens an item record. | W1 |
| H03 | Separately permissioned public customer QR pages with measurements and selected content. | W2 |
| H04 | Curated drops and themed collections. | W3 |
| H05 | Content preparation using approved images/details; publishing is a separate action. | W3 |
| H06 | Customer size/type requests matched to new stock; permissions and contact use need design. | W4 |
| H07 | Reservations with expiry and coordinated inventory rules. | W5 |
| H08 | Natural-language questions over authorised reliable records. | W6 |
| H09 | Web companion for the Fitsin business dashboard. | W7 |
| H10 | Shared backend later, or an eventual interface merge if justified; neither is a prerequisite for initial integration. | W8 |
