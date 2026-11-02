# Cloud environment and implementation handover

Prepared 2 November 2026. No environment has been created or tested by this documentation task. No cloud task has been started.

## Repository access

| Project | Verified local origin | Local location (reference only) |
| --- | --- | --- |
| Fitsin MVP | https://github.com/louisgrochla/fitsin-mvp.git | `/Users/Avii/Documents/New project/fitsin-mvp` |
| Crosstopher | https://github.com/louisgrochla/Crosstopher.git | `/Users/Avii/Desktop/Crosstopher` |

Local HEADs when inspected:

- Fitsin: `4edf2c07a0bcb72e3168e560679c89f3897f17eb`
- Crosstopher: `d580b590b8560eb2015dd4ea5733049149c518fc`

Remote verification during publication found Fitsin main at `bc2fd55132561cdeb248c1ae0f2c82941e42ad96`, one commit ahead of the inspected local checkout. Its commit describes seller payout tracking, per-item sale breakdowns, dated manual entries and improved notification/deep-link behaviour. Those code changes were not audited in the original exploration. Start from the current remote code and reassess all local observations before proposing replacements. The documentation publication preserves that remote code.

These are provenance anchors, not assertions that remotes are up to date. Cloud checkout paths and selected revisions must be discovered in the new environment, not copied from this Mac.

Pre-existing local changes observed before documentation:

- Modified Fitsin `ios/FitsinMVP.xcodeproj/project.pbxproj`.
- Modified Fitsin Xcode user-interface state; untracked shared workspace data.
- Untracked Fitsin `.claude/`; do not use Claude tooling or upload unrelated local configuration.
- Untracked Crosstopher `storefront/`; outside this initial integration scope and not guaranteed to exist in a cloud checkout.

Do not stage all local files, discard changes or infer that an untracked directory is part of the remote product. Review any code needed by the cloud task separately.

## Getting the handover into cloud

1. Review these documentation files locally.
2. Commit and push the documentation to a selected branch when authorised, or supply the files directly to the new session. A remote checkout will not automatically include these local uncommitted files.
3. Ensure the GitHub connection has access to both repositories and select the intended refs.
4. Create/publish a cloud environment containing both repositories, then verify a new task can read both and this documentation packet.
5. Start with NEW-SESSION-GOAL.md. It authorises audit and bounded performance/reliability implementation, then a concrete gate for additional ecosystem features. Local iOS verification and manual review precede release.

Official guidance checked 2 November 2026: Codex Cloud can continue while the computer sleeps. Environments include repositories, tools and access settings; the current setup flow supports selecting GitHub repositories and publishing the prepared environment. Use Work in > Cloud or Settings > Codex Cloud > Environments. Account access still needs checking. See [OpenAI cloud environment documentation](https://learn.chatgpt.com/docs/environments/cloud-environments).

Cloud execution is not a promise of unlimited autonomous runtime. Keep durable checkpoints, an explicit approved slice and clear completion criteria so a later session can continue after usage limits, failures or user decisions.

## Suggested environment setup brief

> Prepare a development-only environment with louisgrochla/fitsin-mvp and louisgrochla/Crosstopher. Read their instructions and docs/ecosystem in Fitsin. Use Codex only, never Claude/Anthropic. Install compatible Node/npm tooling from manifests and lockfiles, and run existing tests/typechecks/builds against local synthetic data. Do not deploy, migrate production, connect real marketplace writes or configure Apple signing. Report repository revisions, dependency setup, baseline checks, missing access and the exact limits of iOS validation. Preserve a reproducible setup and a startup procedure for local services before publishing the environment.

## Development dependencies and commands

These commands were inspected in manifests, not executed/verified as part of saving this plan. Run them from the indicated checkout directories. Node >=20 is required by Fitsin; choose and record a currently supported version compatible with both lockfiles and native dependencies. Do not blindly upgrade packages.

Fitsin, from `backend/`:

```sh
npm ci
NODE_ENV=test npm test
```

Crosstopher, from repository root:

```sh
npm ci
npm test
npm run typecheck
npm run build -w @crosstopher/web
```

Crosstopher includes `better-sqlite3`; installation may require compatible native binaries or build tooling. Frontend OCR tests may require local fixtures/assets. Verify required runtime/download hosts during setup rather than assuming network access.

Read the relevant Cloudflare skill before any Wrangler work. For local runtime work, inspect the existing example configuration, use isolated local D1/R2 and synthetic sellers/garments, and apply only local migrations. `migrate:local` exists in `apps/worker/package.json`. Do not use production `seed.sql`, secrets, `migrate:remote` or deployment commands. Prepare repeatable fixtures covering multiple sellers and matched/unmatched stock.

Fitsin tests may not exercise full endpoint startup. Inspect configuration requirements and stub external Shopify/calendar/Notion/APNs services for integration tests. A missing live secret should not force a production connection to run local tests.

Use environment-managed development secrets only if needed. Never put credentials into prompts, docs, commits, fixtures or logs. Allow necessary dependency/documentation hosts; production marketplace access is unnecessary for the first audit. Consult current environment settings rather than assuming a setup script and a running task share the same access.

## What cloud can and cannot establish

| Work | Expected verification route |
| --- | --- |
| Express backend changes and tests | Cloud Node runtime and synthetic services |
| Crosstopher web/Worker/core code | Cloud tests, typechecks, web build, local bindings and browser checks where available |
| Shared API/financial contracts | Cloud fixtures, duplicate/delay/refund scenarios and seller-isolation tests |
| OCR logic | Cloud fixture tests; final camera accuracy needs representative permitted tag photographs and real capture checks |
| Swift source changes | Can be authored/reviewed in cloud; do not claim SwiftUI build success without Xcode |
| iOS build/simulator/profiling | Mac with Xcode or explicitly configured macOS CI |
| Signing, archive and TestFlight | Apple credentials/tooling and separately authorised release workflow |
| Rich APNs notifications | Native extension/build checks plus real delivery/device validation |
| BLE tag printing and POS scanning | Physical printer/scanner/POS tests |

No laptop wakefulness is needed for cloud code/test work. Fully independent iOS builds need separate macOS infrastructure; no such CI setup has been inspected or purchased. Physical shop workflow validation still needs someone with the equipment.

## Source map for the next session

### Fitsin

- `README.md`, `DEPLOYMENT.md`, `ios/README.md`: orientation; some configuration descriptions are old.
- `ios/FitsinMVP/Views/RootTabView.swift`: tab lifecycle/foreground loading.
- `ios/FitsinMVP/ViewModels/TodayViewModel.swift`, `MonthViewModel.swift`: refresh coordination and state.
- `ios/FitsinMVP/Networking/APIClient.swift`: request policy/auth; avoid printing embedded credential values.
- `ios/FitsinMVP/Storage/LocalCache.swift`: local caching.
- `ios/FitsinMVP/Networking/CalendarService.swift`, `CalendarAuthManager.swift`: current calendar integration; backend also retains Notion paths.
- `backend/src/server.js`: endpoints, webhook and push orchestration.
- `backend/src/services/metrics.js`, `shopify.js`: target and revenue semantics.
- `backend/src/services/manualEntries.js`, `monthGoals.js`, `rota.js`: persistence and mutations.
- `backend/src/services/push.js`, `pushDevices.js`: notifications.
- `backend/src/utils/cache.js`, `http.js`: caching and retries.
- `backend/src/metrics.test.js`, `metrics.smart-targets.test.js`: existing regression coverage.

### Crosstopher

- `PROJECT.md`, `ARCHITECTURE.md`, `STATE_MACHINE.md`, `SHOP.md`, `PLATFORMS.md`: constraints and intended architecture.
- `BACKLOG.md`, `EBAY.md`: implementation history and known issues; distinguish historical claims from present code.
- `packages/core/src/schema.ts`, `types.ts`, `item.ts`, `settle.ts`: contracts/state transitions.
- `packages/db/migrations/`: schema history, including tag scans and publication distinctions.
- `apps/worker/src/auth.ts`, `scope.ts`: seller identity/isolation, item views and summaries.
- `apps/worker/src/index.ts`, `scans.ts`: routes and scan handling.
- `apps/worker/src/transitions.ts`, `webhooks/shopify.ts`, `detect.ts`, `reconcile.ts`: lifecycle and sale processing.
- `apps/web/src/`: capture/OCR, local Dexie state, print and work queues; discover current file names.
- `tools/tag-reading-test/`: inspect fixtures/scoring; do not run live-data scripts or export photos without suitable authorisation.

## Rules to carry across sessions

- No Claude/Anthropic use or auth/quota checks, even if old project instructions recommend it.
- The user approved cloud foundation implementation with local iOS verification/manual review, not implementation of every catalogue idea. Gate new feature slices; retain deferred ideas.
- Existing Crosstopher seller isolation, marketplace human-action boundaries and cost constraints remain until explicitly changed. A shared owner dashboard is a scope decision, not an accidental relaxation of permissions.
- No production deployment, data migration, listing publish/delist or customer messaging as part of the audit.
- Do not introduce recurring paid services by default.
- Preserve uncommitted work and distinguish local versus remote state.
- Treat financial correctness, unknown ownership and stale-data honesty as invariants during optimisation.
- Use small reviewable patches/PRs per repository with linked contract changes; record which checks require Mac/devices.

## Open decisions to turn into concrete gates

1. Exactly whose sales count toward shop targets, and what does each person see?
2. Which Shopify account/till maps to each seller and the shop? Do not infer from old initials.
3. How do legacy garments map to owners and existing records?
4. Which app surfaces host capture versus review versus owner summaries?
5. Which performance targets are realistic on the agreed representative phone/network?
6. What first implementation slice does the owner select after the baseline audit?
7. Keep native-only Fitsin, add web companion, or eventually consolidate? Default proposal is keep both interfaces and connect them.
8. What macOS/device verification route will be available before shipping?

## Required checkpoint format

At each handover, record: approved scope; repository/branch/revision; files changed; tests with results; before/after measurements; decisions; deferred ideas; blockers; remaining native/device checks; next bounded action. Avoid claiming completion while a required verification remains outstanding.
