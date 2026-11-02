# Optional rail assignment, stocktaking and research observations

Owner direction, 2 November 2026. Reuse the native scanner for optional rail assignment and stocktaking, with a later connection to the owner's dissertation visual-tracking research. There are **ten upstairs rails** now. The basement expansion will add an **unknown number** of rails. Rail assignment is **not required during initial listing/item creation**. These are future capabilities to accommodate in the architecture; this document does not implement them or authorise live stock changes/research capture.

## Improve the scope around reusable scanner modes

The same camera, barcode recognition, feedback and durable batch queue can support several explicit modes:

| Mode | Input and result | Boundary |
| --- | --- | --- |
| Read an old tag | Live OCR of description/size/price, automatic acceptance when sufficiently evidenced | Existing-item/creation workflow; not evidence of rail presence unless a rail session is explicitly active |
| Find an item | Decode an existing SKU barcode and open its native record | Read-only lookup; no location or stock-state change |
| Assign/move to a rail | Choose or scan the destination rail, then scan the garments | Explicit batch location assignment; no changes to price, ownership, listing or sale state |
| Stocktake a rail | Choose/scan a rail, then collect observed garment barcodes | Compare observed stock with expected stock; discrepancies require resolution rather than silent reassignment/deletion |

Crosstopher's current garment labels use Code 128 containing the immutable SKU (`apps/web/src/codes.ts`). Decode that barcode directly for known garments; do not use OCR to guess an existing ID. Resolve it within the authenticated business/seller scope. There is no verified rail/location/stocktake data model in the current item schema. Scanner modes and future location contracts need implementation; existing barcode generation alone does not provide stocktake functionality.

## Locations that survive expansion

Use stable location IDs with editable names, optional parent and type. An example structure is Shop → Upstairs → Rails 1–10; Basement can later contain however many rails exist. Names, counts and floor-plan positions are configuration, never hardcoded identifiers. The ten rails are owner-reported physical context, not ten records to seed into production automatically.

A rail can be renamed, moved between areas or retired without losing its history. Additional shelves, storage boxes or event locations can use the same small model when needed. Keep optional coordinates/map layout separate from identity so research or a floor plan does not force a stock migration. Preserve effective layout/name history where needed to interpret past observations.

An item can have no assigned location. That means “not assigned”, not “missing”, and must not prevent creating/editing/listing/printing the item. Scanning a rail after initial listing is the normal way to add location coverage. No per-person seller restrictions are introduced; the initial shared Fitsin business and existing foreign-seller boundaries remain.

Recommend a readable rail label plus a machine-readable marker carrying the stable location ID. Keep rail-marker payloads distinguishable from item SKUs and validate business ownership server-side. Scanning a rail marker can select/change the active destination with unmistakable feedback. Label printing can reuse the native print pipeline later; QR/fiducial generation and actual legibility require implementation and printer/camera testing. A QR label alone is not a visual-tracking system.

## Rail assignment journey

1. Select “Assign to rail” and choose the rail, or scan its marker. Keep floor/rail/mode visibly pinned throughout the batch.
2. Scan garment barcodes continuously. Show a thumbnail/name and a distinct accepted/already-added/unknown/conflict response with haptics/audio where appropriate. A barcode remaining in frame must not repeatedly add the item.
3. Persist the session and accepted choices locally so a pause, network loss or app restart does not discard work. Unknown or unreadable labels go to an exception tray; search/manual identification or a replacement-label task is available without blocking the entire rail.
4. Finish the batch to submit the proposed assignments with stable operation IDs and per-item success/conflict status. Show previous → destination rail for moves and offer correction/undo. Do not claim completion while unapplied operations remain.
5. Items not scanned are left alone. This additive assignment flow does not mean “replace every item previously assigned to this rail”. Bulk clearing/replacing a rail is a separate deliberate operation if later needed.

Retain a movement history rather than overwriting the only location fact. An older offline assignment must not silently overwrite a newer confirmed move; use server revisions/conflict handling. A duplicate barcode on two physical garments is an exception to investigate, not permission to merge them. Record the staff actor for recovery/history while preserving shared access.

## Stocktake journey

Start a session with the selected rail, expected item set/version and start time. Scan what is actually observed; count unique item IDs once per session, while retaining distinct observation/correction events if needed. The session can be paused/resumed and remains visibly incomplete until explicitly finished and synced.

Useful outcomes:

- Expected here and observed.
- Observed here but assigned to another rail.
- Observed here with no previous assignment.
- Expected here but not observed in this session.
- Unknown/unreadable barcode or an item awaiting registration/retagging.
- An item marked sold/closed/archived that was physically observed and needs investigation.
- Stock that changed after the session began, such as a sale or a concurrent move.

Finishing a stocktake does not prove an unobserved item is lost/sold, remove it from stock, change ownership, restore a sold item or delist it. Present discrepancies for explicit resolution. Likewise an observed item on another rail can be offered as a proposed move, not silently assigned by stocktake mode.

Use the start snapshot plus subsequent stock/movement changes when reconciling a session. An item sold while staff counted must not simply be labelled missing. Do not infer physical presence from online-listing status. Where stock is not yet fully registered, show location/barcode coverage and unresolved observations; scanned known items are not automatically the whole rail's physical count.

## Separate facts for operations and research

Keep three distinct concepts:

1. **Assigned location:** the current operational placement recorded by a deliberate assignment/movement.
2. **Last confirmed observation:** where/when a barcode was observed in an explicit rail session, with its source, actor/device, session and correction history. It is evidence from that time, not a guarantee the item is still there.
3. **Predicted location:** a later visual system's suggestion with timestamp, model/version, confidence and provenance. It must not silently replace the operational assignment or a confirmed scan.

A small future data contract should cover location identity/hierarchy, assignment/movement events, session mode/state/snapshot, and observations with stable IDs, item/SKU, location, observed time, received time, source and correction/reversal references. Include business scope and device/session identity. Preserve source time separately from sync time for offline scans; do not resolve concurrent moves solely by an untrusted device clock.

This gives the research project timestamped reference observations to compare with visual predictions. They are useful labels, not perfect ground truth: a wrong selected rail, duplicate physical sticker or later move can invalidate an assumption. Capture corrections and a time window so evaluations are interpretable. The exact visual-tracking method/camera setup remains unspecified; do not assume garment identity can be inferred from appearance or rail-level detection.

Later, an opt-in export/API can expose pseudonymous item/location IDs, session/time provenance, relevant layout version, corrected reference observations and model predictions for evaluation. Product/customer financial details and whole camera video are not necessary for this interface by default. No research collection/export/integration is activated by planning it. Measure assignment agreement, false positives, unknown coverage and delay to detection with clear evaluation windows; scanner observations from one session should not leak between training/calibration and evaluation sets.

## Recommended adjacent features

| Priority | Feature | Why it fits |
| --- | --- | --- |
| First | Scan rail label to select it; pinned mode/destination; undo last scan | Reduces wrong-rail mistakes and makes long batches practical |
| First | Last scanned rail/time on item detail and search | Immediate “where do I look?” value without needing visual tracking |
| First | Pause/resume/offline sessions and an exception tray | Handles basement connectivity, interruptions and incomplete stock registration |
| Next | Rolling counts: one rail at a time, with progress and last-checked dates | Avoids requiring a whole-shop shutdown for stocktake |
| Next | Pick/put-away lists grouped by rail | Combines item lookup, order/event preparation and shelf work; sale matching must be explicit |
| Next | Retag queue for unreadable/unknown labels | Connects the scanner, existing item search and Bluetooth printer |
| Later | Simple floor/rail map with editable layout | Makes search and research locations understandable as the basement expands |
| Later | Visual prediction versus confirmed observation comparison | Supports the dissertation without allowing experimental predictions to change stock |
| Later | Sales/stock analysis by rail | Requires matched sale-to-item data and the location at sale time, not today's rail; disclose unassigned/unknown coverage |

Avoid building empty future tabs or a full location-management product upfront. Build the shared scanner/mode/session boundaries now as needed; keep location assignment optional, then add the smallest usable rail workflow when wanted. Reserve extensible IDs/provenance so basement expansion and research do not require redoing the scanner.

## Acceptance for future implementation

Use synthetic businesses/items/rails first. Verify: arbitrary rail counts and renaming; item creation without location; same barcode held in view; repeated scan counted once; distinct identical garments; unknown/foreign codes; additive assignment leaving unscanned items unchanged; undo/correction; offline resume/retry; concurrent assignments; stock sold/moved during counting; incomplete sessions; no stock mutation from read-only lookup/stocktake observations; corrected history; isolation between staff sessions and future businesses; research predictions remaining separate. Actual camera/label/haptic/print ergonomics require device tests.

These are planning changes only. No database migration, dormant production feature switch, new runtime implementation or test pass is claimed. Existing native scanner and foundation execution status remain as documented in CHECKPOINT.md.
