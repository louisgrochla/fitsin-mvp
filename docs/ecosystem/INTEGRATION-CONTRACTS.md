# Integration contracts — approved scope and later proposals

The initial read-only stock bridge is implemented behind default-off switches; its exact shipped contract is in STOCK-BRIDGE.md. The wider image, ledger and section contracts below remain proposals, not assertions about existing APIs. The owner has approved the initial shared single-seller audience below. Server-bound seller selection and dedicated bridge authentication are implemented; actual source bindings/credentials and production edge access remain unconfigured for a later approved activation. Keep both applications initially.

## Ownership and authority

| Domain | Authority | Integration rule |
| --- | --- | --- |
| Garment, immutable SKU, tag/online/listing lifecycle | Crosstopher | Commands go through its seller-scoped state machine; Fitsin never writes independent stock state. |
| Shopify orders/payments/refunds | The specific Shopify source account | Preserve source facts and revisions; do not infer payments from a scan, product or asking price. |
| Manual/Vinted financial event | Explicitly confirmed record with actor and provenance | Stable local ID allocated before submission; lifecycle mark-sold alone has no trustworthy actual amount. |
| Targets, rota, manual-entry legacy IDs, payout flags | Fitsin | Keep legacy API responses; no silent reclassification, backfill or commission change. |
| Calendar | Current iOS Google Calendar integration | Keep event ID + calendar/account context; backend Notion is a separate legacy path. |
| Cross-app summary | Derived, read-only | Each section carries its own source revision/freshness; never the authority for stock or payments. |

## Identity and visibility

### Approved initial scope — 2 November 2026

One existing Crosstopher seller represents the business for this phase. Multiple people have access to all of that business's data in Crosstopher and Fitsin MVP; do not build per-person stock, sales or earnings visibility restrictions for this phase. Preserve Crosstopher as it currently operates. This is a shared audience decision, not a request to combine existing seller records, reassign garments, remove seller scoping, change marketplace credentials or grant public access.

The initial bridge binds the existing seller on the server and retains authenticated access. Staff names/local PINs need not become distinct seller accounts. Keep source-account mapping separate from staff identity and do not infer it from initials. Foreign-seller isolation tests remain useful boundary tests even though the deployed initial audience uses one seller. Multi-seller product work is deferred.

Mac/Xcode/device/manual checks are batched at the end of the intended change set. Continue authorised cloud implementation and verification before that batch; native checks are not a prerequisite for each cloud slice. Release readiness still requires that final native/device pass. Feature gates remain explicit: this scope decision does not approve the whole candidate catalogue.

### Boundary requirements

An authenticated principal resolves server-side to allowed seller IDs and source accounts. Default remains one seller, no cross-seller view. A future owner aggregate requires explicit permission and specification changes to PROJECT.md, not use of the shared Fitsin code as a superuser credential. Map seller → source account → POS enrolment separately; initials, user display names, SKU text and notification preferences are not authorisation. Unknown ownership remains unknown.

Every query/cache/image key includes environment, principal/permission version, source account, seller, resource and query period. On logout/switch: cancel old work, invalidate memory/disk/image caches, then load the new identity. An old completion cannot repopulate the new identity's cache. Server denies arbitrary seller IDs and returns non-enumerating missing results for foreign items. Never log tokens, private image URLs or customer payloads.

Acceptance: two synthetic sellers with overlapping descriptions and different source accounts; tampered seller parameter, stale signed link, token switch during a delayed request and cached offline reopen must expose no foreign record. Unsynced seller A work must never upload as seller B.

## Garment resolution and images

Canonical garment reference: `{sellerId, garmentId, sku}`. SKU is immutable; resolve within the authenticated source-account/seller mapping. Match priority: stored external variant/product mapping, then exact scoped SKU, then explicit human selection. Multiple/absent matches stay ambiguous/unmatched. Manual search selection enriches the same sale line. Scanning into a basket is not a completed sale.

First garment image means the lowest ordered garment photo, **never** a tag-scan photograph. Return nullable image metadata separately from money: image ID/version, thumbnail/detail variants, authenticated access or signed URL with explicit expiry. Existing Crosstopher signed URLs do not implement expiry and cannot be assumed to satisfy this contract. Refresh expired links without repeating a sale alert. Images fail to a placeholder; multi-line orders use a lead image plus count, with all lines in detail. Cap image bytes, decode dimensions, prefetch and cache lifetime. Do not expose a lock-screen image until the separate native/privacy gate.

## Transaction identity, money and corrections

Proposed immutable identity is `(sourceSystem, sourceAccountId, externalOrderId, externalLineId)` with event/delivery ID and source revision stored separately. Manual records use a generated UUID operation ID before first submission. Deduplicate event deliveries and idempotent writes on those stable keys, not SKU. A returned garment can sell again under a new transaction. Cash processed in Shopify POS is one Shopify event with payment method cash; it is not also a manual sale.

Each transaction/line retains currency, quantity, confirmed actual paid amount, discounts, tax/shipping allocation, fees/cost completeness, channel, payment method, location, original occurrence timestamp, receipt timestamp, London business date, provenance and nullable garment/owner match. Proposed money representation is integer minor units, converted from decimal **strings** with an approved rounding rule. Never mix currencies or use binary-float guesses, list price or tag price as proceeds. Legacy Fitsin decimal totals remain unchanged until an explicitly verified migration/adapter is approved.

Refunds/returns are adjustment records referencing the original transaction/line, with partial quantities and independent return-to-stock decisions. Late matches add a relationship and imagery without creating revenue or another new-sale notification. Vinted's confirmed actual-amount event may eventually trigger existing delist commands once, with durable idempotency; human Vinted removal remains human. Seller statement/commission rules are versioned agreements, not hardcoded initials. Missing costs/fees produce incomplete margins, not zero costs.

Proposed verification fixtures (not implemented ledger tests): duplicate webhook and out-of-order update → one sale; partial refund → linked adjustment; returned/resold SKU → two transactions; mixed scanned/manual basket → one total; unknown manual sale → money retained, later match no total change; identical order IDs in different accounts → distinct records; POS cash → one source; discount/refund → actual amounts reconcile; London DST/midnight → correct business date; unknown currency/owner → explicit incomplete state.

## Read-only summary and freshness

A proposed summary response has `schemaVersion`, authorised scope, and independently versioned sections for removals/conflicts, listing failures, capture/review/print/attachment, draft completion, recent sales, rota/events and target progress. Each section has `status` (fresh/stale/unavailable/unauthorised), `lastSuccessAt`, `sourceUpdatedAt`, `receivedAt`, `complete`, nullable data and an authorised deep link. Successful empty is data with zero rows; unavailable is not zero. A failed stock section cannot block sales or calendar; image failure cannot block money.

Start with a **read-only scoped stock summary bridge** after identity approval. Images require transaction-to-garment matching as a separate slice. Native rich push needs its own notification service extension, APNs payload/device validation, recipient/privacy agreement and expiring image retrieval. Durable event ingestion, retry/deduplication, reconciliation and incomplete-data indicators precede combined financial reporting. No paid infrastructure is assumed.

Implemented C1 slice: see [STOCK-BRIDGE.md](STOCK-BRIDGE.md). It uses one configured shared-business seller, a dedicated read-only credential and no disk cache. Per-person bridge identity is not required for the approved initial audience. All later scope/finance/image gates remain separate.
