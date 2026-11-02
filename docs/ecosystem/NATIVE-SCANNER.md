> Implementation update, 2 November 2026: see [current capability inventory](NATIVE-IMPLEMENTATION.md) and [executed evidence/device checklist](NATIVE-LOCAL-EVIDENCE.md). This brief is preserved as design history; historical unimplemented wording below is superseded.

# Native live tag scanner

Owner direction, 2 November 2026: overhaul recognition on the phone. A continuously running native camera with framing/grid overlays, live recognition and visible readiness is the primary tag-entry workflow. Photographing a tag and processing that still later is a fallback. Clean, sufficiently evidenced readings should be accepted automatically without a routine review screen. When evidence is weak, keep reading the live tag and guide the person to improve the view.

This is the scanner design/acceptance brief, not an implemented scanner or a measured accuracy claim. It extends NATIVE-WORKSPACE.md and supersedes its earlier assumption that native tag recognition merely wraps the web capture/review flow. Preserve existing web operation and stock boundaries while building the native replacement.

## Interaction

1. Open Scan and immediately see the native camera preview, a light grid/alignment guide and the detected tag outline. Track one active tag; ignore unrelated garment/background text and prevent mixing neighbouring tags.
2. Read while the camera stays live. Show compact description, size and price overlays anchored to the active tag; use field-specific pending/ready labels, not colour alone. The progress indicator represents readiness, not a fabricated probability of correctness.
3. When the view needs improvement, offer a specific cue supported by observed conditions: Move closer, Hold steady, Show the whole tag, or Tilt slightly. Provide tap focus/exposure and a torch control where supported. Do not claim that a torch always solves glare or shadows.
4. Accept automatically once all required fields meet the calibrated acceptance rules. Give a short haptic/visual acknowledgement, increment the batch count and keep the camera ready for the next tag. No mandatory photo shutter or review form for every clean tag.
5. Suppress repeat capture while the same tracked tag remains in view. Rearm only after a clear tag exit/new track or explicit New item action. Two physical garments may have identical tag text: do not globally merge/deduplicate them by description/size/price.
6. Leave uncertain fields live so a better view can resolve them. A damaged or ambiguous tag can be parked for later correction or edited directly; it must not trap the whole batch. The accepted-items tray supports correction/removal before later stock/printing actions and makes uncertain save state visible.

The scanner may retain the best tag crop for traceability/reprocessing without making the user take a photograph. Avoid retaining the whole video by default. Tag evidence remains distinct from garment product photographs, which use a separate camera/gallery workflow.

## Reuse for optional barcode workflows

The owner wants future rail assignment and stocktaking using this camera/scanning platform. Keep the recognition pipeline separate from the chosen action: live OCR for old tags, barcode lookup for known items, assign/move to a selected rail, and observe/count a rail. Code 128 SKU decoding is the existing garment identity path; do not OCR-guess known IDs. Share native camera feedback, tracking and durable sessions, while giving each mode explicit acceptance/side-effect rules.

There are ten upstairs rails and an unknown future number in the basement. Rail assignment stays optional and is not a prerequisite for creating/listing an item. [LOCATIONS-STOCKTAKE.md](LOCATIONS-STOCKTAKE.md) records stable location IDs, batch assignment, reconciliation, and separation of confirmed scans from the dissertation visual-tracking project's future predictions. These future modules are not implemented by the live scanner brief.

## Recognition and acceptance

Use a native camera-frame pipeline with on-device text recognition as the starting implementation (AVFoundation and Apple Vision, subject to device/OS validation). The capture preview runs independently of recognition. Process a bounded number of current frames off the main thread, drop superseded work and avoid queuing every camera frame. Track the active tag and its perspective/region of interest. On backgrounding, interruption or cancellation, stop camera/recognition work appropriately and retain accepted queue entries.

A high OCR engine score alone is insufficient for automatic acceptance. Combine:

- Required text/price/size region visibility, useful resolution, focus/motion and exposure/contrast evidence.
- Field-level candidate confidence and agreement across a calibrated observation window, tied to the same tag track. Repeating one identical or similarly obscured frame is not independent proof.
- Layout/field constraints: price must come from the relevant tag region with credible currency/decimal evidence; size and description cannot come from an adjacent tag or garment print.
- Explicit detection of disagreement: multiple plausible prices, old crossed-out prices, handwriting/overprints, a field oscillating between values, clipped required regions or changing tag identity must prevent automatic acceptance of the affected read.
- Stable completion of the whole required result. Do not stitch a description from one tag to the price of the next. Reset observations when the active tag changes; a previously green field is not permanently trusted after that.

Required fields are driven by the existing garment/tag contract, not an arbitrary desire to fill every field. Missing optional fields remain unknown. Printed seller initials are content, never an authorisation selector: the current shared business and server-resolved seller binding remain authoritative.

Do not inherit the web parser's “first price wins” behavior for automatic acceptance. Preserve the problem fixtures as regression examples, but change the expected native outcome to unresolved when competing prices cannot be disambiguated. The existing pink-pen heuristic is evidence of a known problem, not proof of general handwriting/cross-out detection under all lighting. Choose OCR/parser/quality thresholds through measurements on representative tags rather than transferring Tesseract confidence thresholds to Vision.

Live recognition can choose clearer frames as focus, exposure, angle and shadow change. It cannot recover information hidden throughout the observation. Keep feedback actionable and allow a correction when the tag cannot be read reliably; do not promise zero mistakes or indefinite holding as a guaranteed solution.

## Automatic capture and stock writes

Automatic acceptance should persist a stable scan ID and its accepted result locally before advancing the batch. This removes routine recognition review while preserving recovery, correction and retry identity. Map accepted entries to the existing stock system through the scoped native read/write design; preserve SKU allocation, existing-item handling and separate scan/product-photo storage.

The existing web `confirmScan` path can activate an item and queue Shopify POS creation. A green OCR overlay must not silently inherit those side effects. Implement/choose an explicit draft-save/accepted-scan contract for the native workflow, with durable operation IDs and the documented later stock/print actions. Do not weaken the existing web confirmation path or automatically publish marketplace stock because text recognition completed. Production activation remains outside this development brief.

Repeated frames, camera interruptions, retry after a lost response and reopening the app must not create duplicate scan records or allocate multiple SKUs for one accepted capture. Suppressing one continuous view is distinct from detecting a genuinely duplicated physical garment; ambiguous matches remain explicit.

## Prototype and verification

Build this scanner early in the native programme: it is central to the intended experience, not a late adapter after recreating the photo-review UI. The first prototype can use a durable synthetic/local scan queue while authenticated stock commands are developed independently.

Cloud tests can cover pure recognition observations, field parsing, tracking resets, readiness transitions, queue/idempotency behavior and replay sequences. Mac/simulator tests can cover native compilation, UI state and injected frame/read results. Neither establishes actual camera/OCR performance. Use an actual representative iPhone for live camera quality, focus/torch behavior, interruptions, thermal load and shop-lighting acceptance.

Use a labelled set of permitted tags and short replayable clips spanning clean print, varied layouts, folds, shadows, glare, low light, blur, oblique views, clipped fields, multiple tags, handwriting and crossed-out/replacement prices. Existing parser fixtures are a starting point; do not run the live production-scoring tool or collect live stock data unattended.

Measure and report:

- Wrong automatic accepts, especially price errors, separately from reads correctly left unresolved.
- Field-level accuracy and the share of normal clean tags accepted without a correction.
- Time to a stable accepted result, sustained batch throughput, frame/preview responsiveness and thermal/battery behavior.
- Duplicate captures from one continuous view; deliberate rescans; separate but visually identical garments.
- Recovery across lost network, app interruption/restart and repeated saves, preserving accepted queue order and source IDs.
- Overlay alignment across orientation/crop changes, clear non-colour status, readable text and adjustable haptic/audio feedback.

Use separate calibration and evaluation examples. A high average OCR score or perfect result on a small clean sample is not evidence that false acceptance is acceptably low. Numerical acceptance targets remain to be chosen from real-device evidence; do not claim a confidence percentage is a measured error probability.

No scanner implementation or new test execution is recorded by this document. Existing cloud/native verification counts still describe the earlier foundation, not this scanner. Development stays on synthetic/permitted data; no deployment, live stock mutation or printer action is performed by recording this direction.
