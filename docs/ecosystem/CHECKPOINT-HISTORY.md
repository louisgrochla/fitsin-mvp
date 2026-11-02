# Historical checkpoints — 2 November 2026

## Active final review checkpoint — 2 November 2026

Resumed from clean fetched heads Fitsin `0006f3e9f596593a3bd07ca3d1e6e91e4f411ebb` and Crosstopher `f04dfcf3c95e338eab9a3312504476cd4651c447`; retained local `work` branches. Node 22.23.4/npm 10.9.9 locked installs completed. Reviewing actual asset routing and the connected stock contract, configuration/credential failures, and manual-store unreadable/corrupt-file data loss. Current suites pass: Fitsin 33 checks; Crosstopher 651 tests plus root/Worker typechecks and web build. Connected Express/HTTPS/asset-router/Worker/D1 verification passes. The old routing returned HTTP 200 app HTML instead of the disabled endpoint's 404; old manual-storage and mutable-configuration tests also fail as expected. Final benchmark evidence and review handoff are being completed. All integration switches remain off. Native/device checks remain one final unexecuted batch. Continue without requesting per-slice approval; no merge/deploy/live actions.

## Latest direction and slice

Local Mac/Xcode/device/manual validation is batched at the end, per the owner's updated direction; continue authorised cloud slices first. The initial audience is the existing single Crosstopher seller/business shared by every Fitsin user. Earlier "native checks next" and unresolved audience guidance below is historical and superseded by this decision.

The first read-only stock bridge is now implemented behind default-off Worker, backend and native build switches. See [STOCK-BRIDGE.md](STOCK-BRIDGE.md) for its exact contract, configuration and limits. It exposes operational counts only, preserves Crosstopher behavior and adds an independent optional Today card. No credentials/live configuration were installed and nothing was enabled/deployed/merged. Cloud: Fitsin **29** checks and Crosstopher **644** tests pass; root/Worker typechecks and web build pass. Native: **seven** authored tests remain unrun, and the entire final device/manual batch remains pending. All later feature gates stay closed.


Draft reviews: [Fitsin #1](https://github.com/louisgrochla/fitsin-mvp/pull/1) and [Crosstopher #1](https://github.com/louisgrochla/Crosstopher/pull/1). Both branches are pushed; neither PR is merged.

## Approved scope and result

Completed the synchronised source audit, synthetic baseline, bounded performance/reliability implementation, contract design, full candidate traceability and local verification plan. New ecosystem features remain gated. No merge, deployment, production migration, marketplace publish/delist, message, paid service or seller-visibility change occurred. Do not mark the app release-ready: native tests/build/device/manual review are pending.

| Repository | Base | Branch | Reviewable implementation commits |
| --- | --- | --- | --- |
| Fitsin | `19b57ad752cc88a2558ffa09f75c97eac1eba60a` | `codex/foundation-reliability` | `203fe6e` backend; `7b89bae` iOS source + local fixtures; `493e422` background completion guard |
| Crosstopher | `d580b590b8560eb2015dd4ea5733049149c518fc` | `codex/ecosystem-audit` | `20c5250` full-sync grouping + tests |

Documentation/evidence are in the subsequent audit commits on each branch; use `git log` for their full final SHAs. The old claim that OCR/backlog is missing is obsolete. Both required base commits and all specified OCR/backlog files were verified after fetch. Fitsin's 19b57ad correction is read and followed.

## What changed

- Fitsin `backend/src/utils/cache.js`, `utils/http.js`, server cached routes and upstream read declarations: in-flight sharing, invalidation fencing, bounded upstream cancellation including response bodies, safe read retries, London-period cache keys. Existing amounts, commission rules, seller visibility and API shapes remain.
- Fitsin Today/Month models/views, root lifecycle, warm-up and atomic cache writes: independent results/errors, prior-month isolation, goal from the same snapshot, visible-tab foreground refresh, timer pauses, failed manual-input retention and no concurrent same-model/manual submission. An optional month identity field rejects mismatched legacy caches safely.
- Native regression source and an independent XcodeGen test spec are provided; the checked-in main Xcode project and signing were not regenerated. The loopback manual fixture has no real integrations.
- Crosstopher `scope.ts`: group already seller-filtered children once. No row limit, SQL scope, image access, sync protocol, scan confirmation, stock state or marketplace behaviour changed.
- Audit docs: AUDIT-2026-11-02.md, BASELINE.md, INTEGRATION-CONTRACTS.md, MILESTONES.md, LOCAL-VERIFICATION.md and raw evidence. PRODUCT-PLAN.md's entire catalogue is retained; all 76 A–H bullets are mapped.

## Validation and limitations

Fitsin 18/18 backend tests pass (baseline 7). Synthetic actual-endpoint probes at 461/1,400/5,000 rows pass amounts, status, stale fallback and recovery assertions. At 5,000, upstream calls per eight-client burst fell 800 → 200; latest cold median 1,677 → 577 ms. Warm reads make zero upstream calls. These are local fixtures, not iPhone or live hosting results.

Crosstopher 635 tests pass (baseline 634), one opt-in timing test skipped in the ordinary suite and passed separately. Root and explicit Worker typechecks and web build pass; existing large-bundle warning remains. At 5,000 garments the local list median fell 535 → 74 ms with identical row count/bytes. Full unsigned snapshots and mixed photo/listing isolation are tested. Signed-image cost, browser rendering and real D1/R2 latency are unmeasured.

Xcode, simulator, iPhone, Apple signing/APNs and shop hardware were unavailable. Four native regression tests are **authored, not executed**. No live OCR photo scoring or marketplace validation occurred. Build/review/manual steps are in LOCAL-VERIFICATION.md, including fixture commands, exact XcodeGen/xcodebuild commands and the sign-off record.

Known follow-ups include shared history across endpoints/processes, scoped asynchronous caches, calendar query ordering, file-write concurrency outside manual entries and across processes, webhook verification/deduplication, incomplete deduction reporting and settled-proceeds/refund semantics. This foundation does not make combined finances trustworthy by itself.

## Recommended next gate and decisions

First review these branches and run the local/native checklist; address failures before a separate release approval. Then approve **Gate 2 identity/ownership contracts**, followed by **C1 read-only scoped stock summaries**, not the entire feature catalogue. Images (C2), rich native push (C3) and reconciled finances (T1–T3) remain separate gates.

The owner needs to decide:

1. Who can see each seller's stock, sales and earnings; whether any owner aggregate is allowed (existing Crosstopher specs forbid cross-seller views).
2. Exact Shopify account/POS till → shop/seller mappings and whose sales count toward targets; do not infer from historical initials.
3. Who resolves unknown legacy ownership and ambiguous garment matches; approve the match/discard rules without bulk-changing live items.
4. Mac/Xcode and representative iPhone/network verification route, reviewer and acceptable measured budgets. No additional paid infrastructure has been assumed.

Capture/review can continue in Crosstopher and the business dashboard in Fitsin by default. Interface consolidation, AI prose, public QR, customer requests, reservations and every wider opportunity remain in MILESTONES.md for later selection.

## Resume and rollback

Fetch both remotes and inspect clean/dirty state before resuming. Verify the required commits remain in ancestry; preserve any new work and rebase task branches carefully if main advances. Select Node 22 and use locked installs; do not invoke Claude/Anthropic or check their auth. Run the evidence commands appropriate to any new edits, then native checks on Mac. No cloud task depends on laptop wakefulness.

Revert individual implementation commits to undo the unshipped foundation; no database or production rollback is needed. Keep the audit/catalogue documents when reverting a runtime change. Never deploy, merge, migrate production, send messages or trigger live publish/delist as a continuation of this checkpoint without its separate authorisation.

## Continuation checkpoint — 2 November 2026

Independent review resumed from Fitsin `05b5f76` and Crosstopher `abff581` on the existing branches. Existing work branches were retained and no dirty changes were present. Read the continuation section in AUDIT-2026-11-02.md for reproduced failures and scope.

- Fitsin manual metrics now include every matching entry, while public list responses retain their 1,000-entry cap. Manual create/delete read-modify-write operations are serialised within one backend process and recover after write rejection. Multi-process storage, other JSON services, corrupt-file handling, durable write idempotency and financial semantics remain follow-ups.
- Crosstopher runtime grouping passed independent review unchanged. Signed/unsigned full-sync tests now exercise multiple listings and seller-bound photo tokens. Existing OCR/backlog remains untouched and every new ecosystem feature stays gated.
- Cloud: Fitsin 23 passing checks (22 leaf tests and one parent), actual endpoint probes at all three sizes; Crosstopher 636 passing tests, one opt-in benchmark separately passing, root/Worker typechecks and web build passing with the existing bundle warning. New raw evidence uses `*-continuation.*` names.
- Native/device: no new evidence. Four Swift regression tests remain authored but unrun. All Xcode, simulator, iPhone, APNs, accessibility and shop hardware checks remain pending. Release-ready remains **false**.

Changes are intended for the same draft PRs. No merge, deployment, live integration action or new feature approval is included.

## Owner direction — shared business and final local validation batch

The owner clarified on 2 November 2026 that Mac/Xcode/device/manual checks should happen at the end of the change set so cloud work can continue while local testing is unavailable. Do not stop each cloud slice for local verification. Keep all unexecuted checks visible and require them before release readiness; merge and deployment remain unauthorised.

Initial scope is one existing Crosstopher seller/business with multiple people sharing access to all its data, across Crosstopher and Fitsin MVP. Preserve Crosstopher's current operation. Per-person seller permissions and multi-seller product expansion are deferred; do not merge/reassign existing seller data or weaken foreign-seller boundaries. The initial audience decision is settled. Exact external account bindings and secure server-side bridge configuration remain technical work, rather than reasons to ask the same audience question again.

Continue the authorised foundation work in cloud, recording tests per slice. New ecosystem features retain their individual gates; this direction does not approve the entire backlog. The final local checklist is a batched acceptance step, not the next blocker to cloud progress.
