# Local Mac Codex goal — build the native Fitsin business workspace

Owner direction, 2 November 2026. This is the current implementation goal for a **local Mac session**, replacing the previous cloud-audit prompt. The foundation and read-only bridge are implemented for draft review; this goal authorises the next native development programme. It does not claim that the new features or native tests are complete.

## Outcome

Build Fitsin into a fast, fully native iOS **read/write** workspace for running the shared shop business. Bring existing Crosstopher workflows into a coherent SwiftUI experience designed for an iPhone: stock, live scanning, garment photography, stickers, listing work, sales and daily tasks. Preserve Crosstopher's existing web operation and backend authority. Daily work must happen in native screens; a web viewer, stretched web UI, summary card or browser link does not satisfy the goal.

Start with **one shared Fitsin business**, whose staff share all that business's data, mapped to **one existing Crosstopher seller**. Separate businesses come later. Business, staff actor and seller are distinct identities. Preserve every existing foreign-seller boundary; do not combine seller records, reassign their stock or invent per-person stock restrictions.

The product can evolve as it is built. Make routine architecture, visual design and interaction choices, implement complete journeys, inspect the result and improve it. Preserve the wider opportunity list without treating it as an instruction to implement every speculative feature.

## Work continuously

- This is authorisation to implement, test, fix, document, commit and push the development scope below. Do not stop after an audit, plan, prototype, first vertical slice or passing test suite to ask whether to continue.
- Keep a short internal plan and brief progress updates. Continue through the remaining scope after each checkpoint. Do not require approval for ordinary SwiftUI screens, local test schemas, scoped API implementation, refactoring, fixtures or regression fixes.
- When one task is blocked, finish independent work. Missing production credentials do not block local implementation. Missing physical camera/printer access does not block native compilation, simulated transports, replay tests or other workflows.
- Ask only when a material business rule cannot safely be inferred, indispensable information is unavailable, or an action outside the authorised boundary is actually necessary. State the precise blocker and continue unaffected work. Do not ask again about native versus web, shared business versus per-person sellers, or whether to continue.
- Preserve durable checkpoints after coherent changes and before context exhaustion: both revisions, implemented/pending work, exact commands and results, design decisions, blockers and the next concrete action. A checkpoint is a continuation aid, not an instruction to end the task.
- Use Codex only. Never invoke Claude/Anthropic tooling, plugins or APIs, and never inspect their authentication or quota.

## Start from current local and remote work

Locate both checkouts; they need not be siblings. Historical Mac locations were `/Users/Avii/Documents/New project/fitsin-mvp` and `/Users/Avii/Desktop/Crosstopher`; discover rather than assume. Do not require a cloud environment, cloud connector, Linux path or `/workspace`.

| Repository | Existing branch | Existing draft review |
| --- | --- | --- |
| louisgrochla/fitsin-mvp | `codex/foundation-reliability` | [PR #1](https://github.com/louisgrochla/fitsin-mvp/pull/1) |
| louisgrochla/Crosstopher | `codex/ecosystem-audit` | [PR #1](https://github.com/louisgrochla/Crosstopher/pull/1) |

1. Inspect applicable instructions, status, untracked files, branches and worktrees. Fetch both task branches and compare local/remote history. Preserve local edits and remote advances. Never reset, force-push or blindly stage everything. Use an isolated worktree when an owner checkout is dirty or its branch is in use; integrate only your task commits back into the existing PR branch without overwriting the other work.
2. Protect the owner's signing, Xcode user state, workspace files and unrelated directories. Do not regenerate a dirty owner project. Record starting full SHAs; old hashes in evidence are provenance, not reset targets.
3. Read Fitsin `CHECKPOINT.md` first, then this goal, `NATIVE-WORKSPACE.md`, `NATIVE-SCANNER.md`, `LOCATIONS-STOCKTAKE.md`, `AUDIT-2026-11-02.md`, `STOCK-BRIDGE.md`, `INTEGRATION-CONTRACTS.md`, `MILESTONES.md` and `LOCAL-VERIFICATION.md`, all in `docs/ecosystem/`. Consult `PRODUCT-PLAN.md` for retained opportunities. Read Crosstopher's `PROJECT.md`, `ARCHITECTURE.md`, `STATE_MACHINE.md`, `SHOP.md`, `PLATFORMS.md` and later `BACKLOG.md` implementation notes.
4. Latest owner direction takes precedence over historical cloud-only, read-only, web-only, photo-first OCR and per-feature approval wording. Preserve existing web/backlog functionality while building the explicitly authorised native scanner replacement. Historical money/provider constraints remain relevant.
5. Inspect actual APIs, Swift sources, migration history, native test targets and scripts. OCR/backlog already exists; do not rebuild it because an old audit claimed it was absent. Reuse existing stock rules and identifiers.
6. Use Node 22 and locked dependency installs. Discover macOS/Xcode/XcodeGen, available iOS 17+ simulators, Swift package resolution and any connected test devices. Install ordinary free development dependencies where permitted; a tool download requiring Apple account interaction is a blocker for that tool, not permission to end unrelated work.

## Delivery sequence

Complete these stages in dependency order, adjusting the internal breakdown as source inspection warrants. Build and run native code throughout; batch owner-assisted physical/manual acceptance at the end. Do not postpone all compilation until the programme is finished.

### 1. Establish the native design and safe read/write foundation

Create a concise capability-to-screen/API/test inventory, including less visible Crosstopher functions. Mark each as implemented, awaiting implementation, provider-limited, blocked or deliberately future. Do not silently redefine missing native functions as out of scope.

Use Today, Stock, Capture, Sales and Work as a starting navigation proposal. Design clear primary actions, independent loading, empty/error/stale states, retained form input, accessibility and useful return navigation. Prototype the scanner early alongside the stock screen. Do not spend the whole session on static mockups.

Implement business-scoped native access, durable local storage and a command outbox. Use revocable sessions, secure native credential storage and explicit server-derived business-to-seller binding; the existing embedded app code and read-only bridge key must not become broad write credentials. Keep marketplace secrets server-side. Add only the minimum identity model needed for this shared business, with synthetic membership/session fixtures; no full SaaS onboarding or billing.

Use stable operation IDs, server-enforced idempotency, conflict/version checks, bounded retries and explicit pending/synced/failed states. Test interrupted requests, lost replies, replay after app restart, concurrent web/native edits and revoked access. Scope cached records, photos and queued uploads by business; never drain an old business's queue under a new identity. Preserve failed or conflicting user work for recovery.

Crosstopher remains the authority for stock commands and state transitions. Extend its APIs compatibly where needed; do not make the app a direct database client or fork the stock rules. Write and verify migration files against disposable local databases only. The web sync client prunes absent rows from a complete snapshot: no server-only pagination limit that makes records disappear.

### 2. Finish the first operational journey

**Find an item or scan its old tag live → accept a stable read or correct an exception → save/create with a stable SKU → take garment photos when useful → print a sticker → continue.**

- Native stock search, filters, detail, create/edit, relevant history and practical batch navigation. Render cached content promptly, use thumbnails and keep large image decoding off the main thread.
- Existing immutable SKU allocation/reserved blocks, including offline exhaustion and retry behavior. Never allocate a second SKU just because a response was lost.
- Native camera/library garment photos, ordering and durable uploads with progress, retry and restart recovery. Keep garment images separate from tag evidence.
- Native live tag scanner as specified below; accepted entries survive interruptions and can be corrected.
- Native M02 Bluetooth connection, print preview, raster/barcode generation, serial print queue, reconnect and clear recovery. Inspect existing `printer.ts`, `tag.ts`, `strip.ts` and `codes.ts`; verify packet/raster fixtures before actual hardware tests. Do not assume browser Bluetooth behavior proves CoreBluetooth behavior.
- Keep tag printing independent of online listing fields and garment photos. A basic shop tag must not require completion of an online listing.
- Distinguish saved scan, saved garment, bytes sent, printed, physically attached and activated/listed. An uncertain physical print cannot be guaranteed exactly once: show inspection/reprint controls instead of blindly resending.

Connect the native app to the actual local API/state machine and disposable database. UI mocks are useful during development but are not the final integration. Demonstrate web/native coexistence on the same synthetic item. Exercise restart, offline edits, upload failure and concurrent change before moving on; then continue to the remaining stages without another approval.

### 3. Complete operational coverage and useful combined workflows

Implement native access to existing supported daily functions: stock queues and draft completion, tag backlog/corrections, review questions and answer mappings, channel readiness, listing/preflight/retry, deliberate manual listed/removed/sold confirmations, pull/restore/delete where currently valid, double-sale conflicts, history including deleted-item history where supported, and account/integration status/settings. Preserve state-machine checks and deliberate confirmations for destructive product actions.

Develop and test marketplace commands against isolated fake providers. This authorises their implementation, not execution against live marketplaces. Vinted's desktop Chrome extension cannot run inside iOS: supply native preparation/copy/share/media handoff and clear human submission/removal steps where official capabilities require them. Document genuine provider limits; do not hide unfinished ordinary native work behind a browser link.

Preserve and integrate Fitsin's existing Today/Month/day detail, manual sales, seller/payout markers, calendar and rota journeys. Fix regressions and relevant cache/account/race issues exposed by the new flows. Money values retain their source, currency and meaning. Sale-to-item links use stable source account/order/line/SKU mappings with explicit unmatched or ambiguous states; matching must not create a second sale or change totals.

Build two useful combined experiences using available data: an actionable Today/work queue that opens the relevant native task, and sale/item detail with the garment photo and source sale facts where a verified match exists. Reuse existing data first. Record other promising experiments, such as event packing lists or retag suggestions, without expanding this session into every catalogue idea.

Current source establishes Shopify order/sales reads and Google Calendar, not a general card-processor settlement/fee/chargeback stream. Verify inputs before designing around them. Do not invent payment facts, treat asking price as received money, build a new financial ledger or execute payments/refunds as part of this goal.

### 4. Add the small optional rail/stocktake foundation

After the core journeys work, implement the minimal optional location/scanning module described in `LOCATIONS-STOCKTAKE.md`, behind a default-off switch. This prepares the future workflows for local testing without cluttering the ordinary app or making them a prerequisite for listing. The full dissertation visual-tracking system remains future work.

- Stable editable location IDs with parent/type/name. Ten upstairs rails are present context, not a hardcoded maximum or a production seed. Support any future basement rail count. Item location remains nullable.
- Reuse the native camera for exact Code 128 SKU lookup, rail selection and continuous barcode batches. Modes are explicit: Find item, Assign/move, Stocktake. Printed rail markers may select a destination; keep that destination visible during scanning.
- Assignment changes only explicitly scanned items. Provide duplicate suppression, unknown/conflict feedback, unique counts, undo/correction and restart/offline recovery. An old queued assignment must not overwrite a newer move; return per-item applied/conflict results.
- A stocktake records observations against an expected snapshot, accounts for moves/sales during the session and surfaces discrepancies. Not observed does not mean sold, deleted, delisted or missing with certainty. Do not replace a rail's entire contents just because some items were not scanned. Partial stock registration is not a count of everything physically present.
- Keep operational assignment, confirmed observation and future predicted location separate. Preserve item/location/session/actor/device/source identity, observation time versus receive time and correction history needed for future research.
- Keep this module absent from ordinary navigation while disabled, with no location requirement on capture/create/listing. Local test configuration can enable it. Add no camera-based shop surveillance, visual model, live research export, projector or floor-map editor in this programme.

## Live scanner requirements

Use native capture and on-device recognition as the starting point, for example AVFoundation and Vision. Share camera/session infrastructure with barcode modes; keep recognition separate from the action it triggers.

- Live preview, light grid, tracked tag outline and field overlays. Give useful focus/lighting/framing guidance, tap focus/exposure and torch where supported. Readiness needs labels as well as colour; use haptics for an accepted capture.
- Use per-field agreement across frames, image quality and layout/currency checks tied to one tag track. Reset on tag changes. Do not mix neighbouring tags or treat repeated identical obscured frames as independent proof.
- Clean high-evidence reads auto-accept into a durable local queue without requiring a review form each time. Low-evidence readings remain live; damaged/ambiguous tags can be parked or corrected.
- Competing/crossed-out prices, clipped fields and unstable candidates must prevent unsafe automatic acceptance. Do not inherit the web parser's first-price-wins rule. OCR scores are not calibrated probabilities; do not invent a certainty percentage.
- Suppress repeated capture of the same tag still in view; deliberately separate but visually identical garments remain separate items. Retain a best crop only when useful; no continuous video storage by default.
- Recognition acceptance must not silently activate stock or queue POS/marketplace creation. Existing web scan confirmation can do both. Use an explicit native accepted-scan/draft contract and separate deliberate later stock/print actions, preserving existing web semantics.
- Measure with labelled permitted tags and replayable observations/clips: wrong automatic accepts, especially prices; correct abstentions; clean-tag coverage; time to accept; duplicates; restart recovery and camera responsiveness. Keep calibration and evaluation examples separate. Synthetic fixtures prove logic, not real handwriting or shop-lighting accuracy.

Do not stop native implementation waiting for a perfect numerical OCR threshold. Build conservative acceptance and an exception path, exercise available evidence, and clearly record real-device calibration still needed before live automatic use.

## Local verification and evidence

Verify current results; historical counts are not acceptance of new code. Last recorded runtime evidence was **33 Fitsin checks**, **651 Crosstopher tests**, root/Worker typechecks, web build, connected bridge test and synthetic benchmarks. Seven native regression tests were authored but unexecuted in cloud. The owner reported local success conversationally; find actual logs/results if available and record their revisions instead of silently marking everything passed.

With Node 22, these existing commands form the baseline. Run them in the indicated isolated checkout, adapt only when the actual project has intentionally changed, and save exit status plus readable logs. Do not run production seeds, live scoring or deploy scripts.

From Fitsin root:

```sh
npm ci --prefix backend
NODE_ENV=test npm test --prefix backend
SAMPLES=5 node backend/scripts/benchmark.mjs
```

From Crosstopher root:

```sh
npm ci
npm test
npm run typecheck
npx --no-install tsc -p apps/worker/tsconfig.json --noEmit
npm run build -w @crosstopher/web
PERF_OUTPUT=/tmp/crosstopher-local-list.json npx --no-install vitest run --project worker apps/worker/test/performance.test.ts
node scripts/verify-fitsin-bridge.mjs "/absolute/path/to/isolated/fitsin-mvp"
```

The connected script requires Node 22, OpenSSL and both locked installs. It uses actual local Express/Worker routes, trusted loopback TLS and disposable synthetic D1, with external Worker calls blocked. Extend this pattern for native writes, sessions, photos, outbox conflicts and optional locations. Do not test new writes solely against a fake native repository.

Use `LOCAL-VERIFICATION.md` for the existing hostless Swift tests, app build and synthetic fixture modes. Select an actual available iOS 17+ simulator. In the isolated Fitsin `ios/` directory, the current foundation commands are:

```sh
xcodegen generate --spec foundation-tests.yml
xcodebuild -project FitsinFoundationChecks.xcodeproj -scheme FitsinFoundationTests -destination 'platform=iOS Simulator,id=<ACTUAL-UDID>' -derivedDataPath build/FoundationDerived -resultBundlePath build/FoundationChecks.xcresult CODE_SIGNING_ALLOWED=NO test
xcodegen generate --spec project.yml
xcodebuild -project FitsinMVP.xcodeproj -scheme FitsinMVP -destination 'platform=iOS Simulator,id=<ACTUAL-UDID>' -derivedDataPath build/AppDerived CODE_SIGNING_ALLOWED=NO API_BASE_URL=http://127.0.0.1:31988 build
```

Use fresh result-bundle paths on reruns. Review generated project changes and preserve the owner's signing configuration. Extend appropriate test targets for the new code. Check Swift concurrency diagnostics. Verify the **built Info.plist** points to loopback before launching: the committed default is a live Render URL. Use Debug-only fixture settings, never weaken Release transport security. Keep fixture sessions signed out of live Google accounts and prevent real push registration/delivery. Extend the local fixture rather than pretending its current limited routes cover the whole new workspace.

Add meaningful tests for session/business isolation, retained drafts, immutable SKU/retry identity, offline/restart/photo recovery, stale edits and sold-during-action conflicts; scanner tracking/readiness/price ambiguity/duplicate sequences; printer bytes/queue/reconnect/uncertain outcomes; location assignment versus observation; and native/web coexistence. Include negative cases with another seller. Test default-off switches and enabled synthetic configurations.

Run native unit tests and simulator journey tests, inspect actual simulator screenshots, and correct clipping, keyboard, navigation and accessibility issues. Check slow/offline/revoked/malformed responses. Measure cached launch/search/item-open/save and request counts on the available target, identifying simulator timings as such. Re-run focused checks during development, then the complete relevant suite on the final changes. Provide a repeatable local verification entry point or exact consolidated command list that returns nonzero on failures and reports unavailable hardware separately.

Batch physical iPhone camera/OCR, M02 print/scannability, focus/torch, interruptions, sustained scanning, thermal/battery, VoiceOver and device performance checks at the end. Use a controlled synthetic tag/test-printer setup when available within authorisation; do not invoke live stock transitions to test the printer. Physical printing or account/device actions needing owner participation remain clearly identified for the final batch. Camera/BLE mocks cannot close those checks. Missing hardware is an acceptance limitation; finish all independently verifiable implementation first.

## Boundaries

Development code, local schemas, synthetic commands, native builds/simulator runs and reviewable commits are authorised. All new integration and optional-module switches stay **disabled by default**; enable only explicitly isolated synthetic development configurations.

Do not merge, deploy, migrate production, provision production credentials, activate live integrations, publish/delist live stock, make real calendar/account writes, send notifications/messages, buy services, upload TestFlight or distribute a release. Do not read/import production secrets or customer data for convenience. Preserve existing APIs and web operation. Test new provider behavior with fakes and consult official API documentation when implementing new contracts.

Rich push, financial ledgers/reconciliation, real payment/refund actions, new paid services, extra marketplace channels, separate-business SaaS onboarding and the dissertation visual-tracking pipeline remain outside this build. Native garment photos, live tag OCR overhaul, read/write stock workflows, Bluetooth printing and the optional location module are included; old gates must not be used to stop those ordinary development steps.

## Completion and handoff

The development goal is complete when the native journeys and operational coverage above work end to end against the local stack, the optional rail module works when enabled with synthetic data, relevant regressions are fixed, current automated checks pass or have precise genuine blockers, and remaining physical/provider/release limitations are explicit. A scaffold, screenshots alone, mocks-only integration or completion of just the first journey does not meet this goal.

Keep `CHECKPOINT.md`, the capability inventory, API contracts, migrations and verification instructions coherent with the final implementation. Commit coherent changes and push to the existing PR branches, preserving concurrent work; keep both PRs draft and rewrite their descriptions around what is actually implemented/tested. Never claim coverage, accuracy or readiness based on authored-but-unrun tests.

Finish with one concise handoff: implemented journeys and material decisions; both commit SHAs and draft PR links; executed automated/simulator results with evidence; genuine blockers; and one consolidated final physical/manual checklist. If context or tool limits force an interruption, save a precise checkpoint and resume from it when possible. A local session cannot continue while its Mac is asleep or Codex is not running; do not promise otherwise. No release-readiness claim or live activation follows automatically from development completion.
