# Native implementation and executed local evidence — 2 November 2026

Implementation commits: Fitsin `8a1f92802d9edb9ca1a7c85e0c11e31b5348307d`; Crosstopher `3c092ecd62da29be29c697f231acd81a304fa80e`. Subsequent evidence commits contain this record. Both existing PRs remain draft: [Fitsin #1](https://github.com/louisgrochla/fitsin-mvp/pull/1), [Crosstopher #1](https://github.com/louisgrochla/Crosstopher/pull/1).

The app uses Crosstopher's actual scoped stock commands and state machine. Connected checks ran the actual Worker, migrations, D1, R2 and Swift URLSession client locally. Fixtures isolated data and providers; no live stock was modified. This record does not claim production rollout or physical-device acceptance. The owner subsequently requested an end to extended synthetic walkthroughs; verification was consolidated and completed without further approval stops.

## Environment and preservation

Local Mac arm64, macOS 26.1 (25B78), Node 22.20.0, npm 10.9.3, Xcode 26.3 (17C529), XcodeGen 2.44.1, SDK 26.2, iOS 26.3 simulator. Locked npm installs were used; npm locks and Swift Package.resolved did not change. Fresh simulator: `68F5F60D-FF23-4EC5-9258-BF0C04F560EF`, Fitsin Synthetic QA 20261102. No physical-device installation or owner signing change.

Both original dirty checkouts were preserved. Development was isolated in `/Users/Avii/Developer/fitsin-local-verification-20261102/{fitsin,crosstopher}`. Source defaults: native workspace NO, native Worker false, optional locations false, stock summary NO. Local YES/loopback overrides were command arguments only. No ATS exemption was added. Migrations 0021/0022 were applied only to disposable local databases.

## Executed results

| Check | Actual result | Evidence |
| --- | --- | --- |
| Fitsin backend `npm test --prefix backend` | 34 passed; source-shop/SKU addition preserves finance values | [backend output](evidence/native-local-20261102/fitsin-native-backend-final.txt) |
| Crosstopher `npm test` | 677 passed, one opt-in performance test skipped in normal suite | Companion PR `docs/ecosystem/evidence/native-local-20261102/worker-release-review.txt` |
| Root/core TypeScript, explicit Worker TypeScript, web TypeScript/Vite build | Passed; existing web bundle warning remains, 836.81 kB main chunk | Companion evidence `root-final-types.txt`, `worker-final-typecheck.txt`, `web-final-build.txt` |
| Real Worker/D1/R2 native command journey | Passed, zero outbound calls; auth/revocation, SKU/write replay, photo bytes/immutability, web conflict, scans, print/manual channel transitions, locations/stocktake | Companion evidence `native-final-connected.txt` |
| Actual Fitsin → local trusted HTTPS → Worker/assets/D1 summary bridge | Passed; foreign seller excluded, disabled/revoked/misconfigured states and recovery; zero outbound | Companion evidence `native-final-bridge-review.txt` |
| Native hostless simulator tests | 26 passed, zero failures: 9 loading/calendar boundaries, 9 workspace core, 7 outbox/recovery, 1 actual local URLSession/Worker/D1/R2 integration | [native test output](evidence/native-local-20261102/native-race-tests.txt) |
| Final native app build | Passed after all UI changes; local ad hoc signing supports Keychain in Simulator | [build output](evidence/native-local-20261102/native-final-ui-build.txt) |
| Default-off native app build | Passed separately using tracked defaults; native NO, summary NO, workspace URL blank | [default build output](evidence/native-local-20261102/native-default-off-build.txt) |

The native suite covers lost replies with identical operation replay, restart, blocked stale edits, access revocation, identity isolation, disk failure, SKU exhaustion/duplicate actions, interrupted-print uncertainty, unchanged-inventory request suppression, exact money parsing, repeated pixel-frame rejection, temporal OCR acceptance/abstention, M02 packet boundaries and Vision decoding of both rendered barcode layouts. It caught and now covers creation finishing while its editor is still open: the first save depends on the creation receipt rather than conflicting with its own draft. Concurrent web edits still conflict.

The Worker suite includes native-vs-web auth separation, disabled defaults, atomic receipt/revision fences and rollback, accepted scans without activation, original/web upload replay, foreign photo/item boundaries, seller-local mapping overrides/forget, optional assignment undo/conflicts and observations, and fake-provider duplicate deletion failure/retry/idempotency. These tests do not prove camera accuracy or physical printing.

## Simulator observations

Simulator froze during initial access and was restarted at the owner's request. An unsigned build could not access Keychain; local ad hoc signing corrected it without changing project signing. No lock-screen bypass was attempted.

Observed through the native UI: staff invitation enrolment against the actual local Worker; restored session and cached work after app restart; Today task counts; accepted manual tag exception; stable SKU `SY-0101`; draft creation and garment editing; explicit retained-conflict comparison and successful reviewed reapplication; synced queue; stock details with the saved brand; queued full sticker and inspected generated preview; optional location creation; assignment of only the selected garment with an undo entry; stocktake start. Draft creation and print queuing did not activate the garment.

The final UI polish opens a created garment directly after editing, dismisses a resolved conflict, formats minor-unit prices, opens a newly started stocktake, labels pending/completed counts and allows clearing an optional assignment. Final compilation passed. Extended UI walkthroughs stopped following the owner's request. Sales/calendar/manual-entry flows remain the existing native implementation; their live-account writes, physical camera/library picker, optical scan and Bluetooth journey were not exercised here. Offline/restart/lost-response coverage is automated, rather than a claimed full UI outage journey.

Screens: [tag entry](evidence/native-local-20261102/accepted-tag.png), [garment editor](evidence/native-local-20261102/garment-editor.png), [sticker preview](evidence/native-local-20261102/sticker-preview.png). Rendered fixtures: [full label](evidence/native-local-20261102/full-label.png), [strip](evidence/native-local-20261102/strip-label.png). Barcode decoding passed; paper quality is unmeasured.

## Performance scope

Final local complete-list benchmark, 10 samples, unsigned photo URLs: 461 / 1,400 / 5,000 records all returned. Median 5.01 / 14.06 / 55.00 ms; p95 66.73 / 18.59 / 62.60 ms. Payload sizes 464,242 / 1,414,853 / 5,072,033 bytes. This is local list assembly, not network or phone rendering latency. No snapshot pagination cap was introduced.

Native 5,000-garment simulator cache measurement: read/decode 391.41 ms, search 2.49 ms, item lookup 0.84 ms, atomic save 95.23 ms; zero network requests. Restore and image preparation run off the main actor; full-snapshot atomic saves still run on the main actor and are a remaining device-performance consideration. Earlier Fitsin benchmark (five samples, concurrent simulator startup) cold median 302.97 / 671.28 / 1,075.96 ms at 461 / 1,400 / 5,000 records, warm upstream calls zero, stale fallback/recovery passed. These measurements are not physical-device cold-launch or p95 UI claims.

## Reproduce locally

Use Node 22 and `npm ci` in Crosstopher and `npm ci --prefix backend` in Fitsin. Do not use production environment files. From Crosstopher: `npm test`, `npm run typecheck`, `npx --no-install tsc -p apps/worker/tsconfig.json --noEmit`, `npm run build -w @crosstopher/web`, `node scripts/native-dev.mjs --check`, and `node scripts/verify-fitsin-bridge.mjs /absolute/path/to/fitsin`.

`node scripts/native-dev.mjs` starts a disposable loopback-only Worker on 31989, prints synthetic enrolment values, and refuses outbound provider access. It is a development fixture, not a production setup/provisioning command. Start Fitsin's `MODE=healthy node backend/scripts/ios-fixture.mjs` on 31988 for isolated finance UI data. From Fitsin/ios, generate `foundation-tests.yml` with XcodeGen and run:

```sh
xcodebuild -project FitsinFoundationChecks.xcodeproj -scheme FitsinFoundationTests \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UUID' \
  CODE_SIGNING_ALLOWED=NO RUN_NATIVE_CONNECTED_TESTS=YES test
xcodebuild -project FitsinMVP.xcodeproj -scheme FitsinMVP \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UUID' \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  'API_BASE_URL=http:/$()/127.0.0.1:31988' \
  'WORKSPACE_API_URL=http:/$()/127.0.0.1:31989' NATIVE_WORKSPACE_ENABLED=YES build
```

Use a unique resultBundlePath for each XCTest run if collecting xcresults. Full local logs and NativeRace.xcresult remain under the isolated workspace's `logs/`; only compact evidence is tracked.

## One remaining owner-assisted/device checklist

- [ ] iPhone: camera permission/denial, focus/torch, overlays, neighbouring/damaged/crossed-out tags, repeated identical garments, clean-tag coverage, wrong-price accepts, time-to-accept, 20-minute heat/battery session and background/restart.
- [ ] Garment photos on the actual phone: camera and library originals, orientation, reorder/remove, interrupted uploads, offline editing and reconnect, app restart, low-storage handling.
- [ ] M02: select/connect/reconnect, full/strip paper dimensions and contrast, barcode reads at real distance, disconnect/battery/paper-out mid-print, uncertain output inspection and deliberate reprint, then attached/activation confirmation in an authorised test account.
- [ ] Physical barcode rails: Find/Assign/Stocktake, visible destination/rail marker, duplicates/unknowns, concurrent moves, undo and discrepancies. Rail assignment remains optional.
- [ ] Device usability/performance: VoiceOver, Dynamic Type, keyboard reach, cold/cache launch and stock search at shop scale; verify the combined sale/item and retained finance/calendar/rota/manual-entry/payout journeys with the intended accounts.
- [ ] Separately authorised rollout: apply migrations before the new Worker, map one existing seller, provision staff invitations, configure HTTPS app endpoint, validate provider/account boundaries and retention for orphaned immutable photo uploads, then deliberately enable flags. No production configuration, deployment, migration, live listing/delisting, messages, notification or release happened in this session.

Vinted submission/removal remains a human native share/copy handoff because its desktop extension does not run on iOS. Real camera/printer access and rollout authority are the outstanding acceptance limits. Dissertation tracking, a financial ledger and speculative expansion remain future work.
