# Native workspace implementation — 2 November 2026

This is the implementation inventory for NEW-SESSION-GOAL.md. It supersedes the brief's historical “not yet implemented” wording. Native source is under `ios/FitsinMVP/Workspace`; stock authority remains in Crosstopher's Worker. Both reviews remain draft. No production activation or release is part of this work.

## Capability inventory

“Implemented” below means code and local automated coverage, not physical-device acceptance. The final local evidence record identifies the UI journeys actually exercised.

| Capability | Native screen / implementation | API and evidence | Status |
| --- | --- | --- | --- |
| Shared business and staff access | Invitation sign-in; Keychain; Work device/session controls | Server-derived business → existing seller; revocable 30-day device sessions; default-off, foreign seller and revocation tests | Implemented |
| Stock search, filters, detail/edit | Stock, photo rows, editor, history; immutable SKU | Complete owned inventory; revision fence; local snapshot; stable SKU reservation; web/native conflict and lost-response tests | Implemented |
| Offline/restart recovery | Durable atomic scoped snapshot, dependent command outbox, conflict comparison/editor | Stable operation receipt; retry backoff; original identity scope; corrupt/disk-failure tests | Implemented |
| Continuous tag OCR | Capture preview/grid, tag/field boxes, focus/torch, readiness labels, haptics, accepted tray and exception entry | On-device Vision; five agreeing frames over ≥1.5s, quality/ambiguity gates; repeated pixels ignored; tag-exit duplicate suppression | Implemented; physical accuracy/coverage unmeasured |
| Scan → draft | Accepted scans and existing web backlog; Make draft, edit/correct, discard/link | Separate accepted-scan contract never activates stock; native backlog linking also does not activate | Implemented |
| Garment photos | Camera/library, order/remove, retained original and prepared web derivative | Durable metadata/upload chain, immutable R2 keys, hashed replay, restart and exact original-byte integration checks | Implemented; camera hardware pending |
| Stickers | Full/strip preview, nearby printer selection, serial CoreBluetooth transport, inspect/reprint/attach queue | M02 384-dot raster, ≤255 rows/block, 128-byte chunks; barcode decoding and interrupted-print tests | Implemented; M02 radio/paper acceptance pending |
| Print versus activation | Explicit physical inspection confirmation; attachment recorded separately | Existing print command activates drafts and queues configured POS listing, once per operation; UI explains consequence | Implemented; no real print/listing performed |
| Listing operations | Item channel actions; readiness; Work attention queues | Existing publish, retry, manual listed/removed/sold, pull, restore and delete rules; fake-provider tests | Implemented |
| Duplicate removal | Choose real garment to keep, compare SKUs, destructive confirmation | Both revisions fenced; native command queues Shopify deletion; failed jobs prevent restore; retry/replay tests | Implemented |
| Double sales/history/deleted stock | Item warning/acknowledgement; history and deleted history in Work | Existing events/deletion history, explicit command receipt | Implemented |
| Questions/answers/mappings | Work questions, constrained choices, per-item answers, shared vocabulary plus business overrides | Native corrections never alter foreign seller's vocabulary/reviews | Implemented |
| Vinted preparation | Native text copy, photo share, saved taxonomy choices, explicit human listed/removed confirmations | Existing payload/taxonomy, ordinary garment attributes preserved | Implemented; submission/removal remain human; desktop extension unavailable on iOS |
| eBay category correction | Editor category fields and previously used categories | Existing seller-scoped category history | Implemented; live taxonomy/provider diagnostics deliberately not called |
| Channels/account settings | Enabled/mode status; deliberate enable toggle with compare-and-set | No marketplace secrets or OAuth provisioning exposed | Implemented; account provisioning/diagnostics require separate setup |
| Daily finance/manual sales/payouts | Sales opens retained Today/Month/day/manual-entry/payout flows | Existing Fitsin backend; money semantics unchanged; exact Shopify shop/SKU added to source lines | Implemented; live-account writes not exercised |
| Sale → garment | Verified source account + exact immutable SKU link and garment thumbnail in day detail | Worker validates configured shop and owned SKU; unmatched/unavailable labelled unverified; no second sale or total change | Implemented |
| Calendar/rota | Work → Calendar and rota; existing native Google account/settings retained | Existing services; native branch binds calendar auth without automatically requesting push or Google login | Implemented; owner-account acceptance pending |
| Optional locations | Work-only when module enabled; editable name/type/parent, stable ID, nullable assignment | Default-off flag, two-level hierarchy with transactional checks; no hardcoded rail count | Implemented |
| Barcode modes | Find item; Assign/move; Stocktake; visible destination, LOC: markers, unique batch feedback | Exact Code 128 SKU; unknown feedback; individually queued moves/observations | Implemented; optical barcode acceptance pending |
| Stocktake | Snapshot, observed/unobserved, moved/changed/sold/unexpected, complete | Snapshot and observations separate from assignments; missing does not mutate stock; device/actor/source/observed/receive time and correction history retained | Implemented |
| Research, financial ledger, rich push, extra channels | Retained in product briefs | No surveillance/model/export/payment data invented | Future, outside this build |

## Design and operational decisions

- Today, Stock, Capture, Sales and Work are SwiftUI navigation stacks. Stock edits, reviews, photos and queues do not depend on a browser. Vinted uses the native share sheet for human handoff.
- A business maps to exactly one existing seller. Staff share its stock; actor/device identities support audit and recovery. No production identity or credential was provisioned.
- The outbox persists before acknowledging a scan, allocating a SKU, saving a draft or starting print transmission. Reopened `sending` print jobs become uncertain and require inspection; no automatic physical resend. Server receipt revision, rather than a newly fetched revision, orders dependent commands.
- Stock conflict resolution requires reviewing the current item and explicitly submitting a new operation. The original draft remains visible. Authentication expiry locks access while retaining its scoped disk data.
- A cheap owned-inventory version check avoids downloading unchanged catalogue bodies every 15 seconds. Changed snapshots remain complete for web coexistence. Cache restore and thumbnail preparation run off the main actor; atomic JSON saves still scale with catalogue size and are measured separately from UI latency.
- Native image originals and web derivatives use distinct immutable keys. A failed SQL guard after an R2 put can leave an unreferenced object; no destructive background garbage collector is included. Production retention/cleanup design remains a release concern.
- Ordinary deletion retains the historical sold-out Shopify page. Duplicate removal uses a durable provider deletion job, leaves visible pending/failed state, and cannot restore until deletion completes. Failed ordinary pulls now retry removal rather than create another listing.
- Location identity is stable when its human name/type/parent changes. Assignment history records correction IDs; observation history preserves repeated observations. Rail assignment is never an input requirement for scan/create/print/listing.
- OCR thresholds and crossed-out-price heuristics are conservative engineering rules, not calibrated probabilities. Synthetic parser/stability tests do not establish real camera accuracy, clean-tag coverage or time-to-accept on shop tags.

## Remaining acceptance and boundaries

The single owner-assisted checklist is in NATIVE-LOCAL-EVIDENCE.md. Real iPhone camera/torch/focus, long-session scanning, M02 disconnect/paper/battery and scannability, VoiceOver/Dynamic Type, device performance, and real account/calendar/provider setup are not replaced by fixtures. Defaults remain off. No merge, deployment, production migration, live stock transition, real notification, release distribution or paid service was performed.
