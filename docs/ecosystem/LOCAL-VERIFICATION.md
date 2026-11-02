# Local Xcode, device and manual verification

Owner direction (2 November 2026): batch these local checks at the end of the intended change set. Continue authorised cloud work and cloud checks in the meantime; do not require a Mac/device pass before every slice. Any cloud finding that depends on native behavior remains unverified until this final batch.

All boxes are pending unless a reviewer adds an evidence link, date, revision and result. Cloud tests do not establish iOS compilation or release readiness. Do not merge, deploy, archive for release, upload TestFlight, migrate production or send push as part of this checklist without the separate release/action gate.

## Prepare safely on a Mac

- [ ] Fetch the two `codex/` branches and record full commit SHAs. Preserve existing local project/signing/user-state changes. Use a fresh worktree for these checks, not the owner's modified Xcode project. Required bases: Fitsin `19b57ad`, Crosstopher `d580b59`.
- [ ] Record `xcodebuild -version`, macOS, XcodeGen, simulator/device model, iOS version, network profile and power mode. The app targets iOS 17+; choose an installed supported simulator from `xcrun simctl list devices available`.
- [ ] Install locked backend dependencies with Node 22 (`cd backend && npm ci`). Do not copy production `.env`, tokens, customer data or signing files into fixtures.
- [ ] In `ios/`, generate the independent hostless regression project: `xcodegen generate --spec foundation-tests.yml`. Run `xcodebuild -project FitsinFoundationChecks.xcodeproj -scheme FitsinFoundationTests -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -derivedDataPath build/FoundationDerived -resultBundlePath build/FoundationChecks.xcresult CODE_SIGNING_ALLOWED=NO test`. Substitute the actual UDID. These tests inject all used network functions and disable disk cache; they do not launch the app or require Google sign-in.
- [ ] Confirm all seven `LoadingTests` pass: Today before delayed/failing week, overlapping refresh coalescing and later recovery, current month before previous month, failed manual save result, plus independent stock loading, outage/scope/revocation handling and disabled stock behavior. Archive the xcresult locally and link the result in CHECKPOINT.md.
- [ ] Generate the main project with `xcodegen generate --spec project.yml` **in the isolated worktree**. Review the generated diff; do not overwrite the owner's signing or Xcode workspace changes. The checked-in `.xcodeproj` was not regenerated in Linux.
- [ ] Build Debug for the selected simulator: `xcodebuild -project FitsinMVP.xcodeproj -scheme FitsinMVP -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' -derivedDataPath build/AppDerived CODE_SIGNING_ALLOWED=NO API_BASE_URL=http://127.0.0.1:31988 build`. Resolve the pinned GoogleSignIn package normally; no account login is needed to build. Check warnings and Swift concurrency diagnostics.
- [ ] Ensure the **built Info.plist** has the local API_BASE_URL before launching. The committed project default is a live Render URL and must not be used for these synthetic checks. If ATS blocks localhost, use a temporary Debug-only local-network exception in the isolated project; never relax Release transport security. Deny push permission and stay signed out of Google during fixture checks.

## Reproducible synthetic app exercise

Run `MODE=healthy MONTH_DELAY_MS=2000 node backend/scripts/ios-fixture.mjs` on the Mac. It binds only localhost:31988, logs method/path only, and has no external integrations. Restart with the mode below; changing mode clears its temporary manual list. The fixture covers Today, Month, manual entries and empty rota/schedule; other routes deliberately return 404. It is **not** a complete finance simulator: fixture totals remain fixed after a manual save. Use the backend's synthetic integration probe/tests for cache invalidation and a separately configured development backend for the broader mutation checklist.

- [ ] Cold launch: remove only this test app's cache. Today £25 appears before the delayed week. Week shows progress, then data with its own updated time. Empty rota is distinct from unavailable sales. Manual form remains reachable.
- [ ] `MODE=week-failure`: Today still shows £25; week ends in a clear error and pull-to-retry; there is no permanent primary spinner. Previously saved week remains labelled stale.
- [ ] `MODE=today-failure`: useful week/rota and manual form remain accessible; primary area offers retry. With same-day cache, retain it with refresh-failed text; with no cache, never display fabricated zero sales.
- [ ] `MODE=unauthorized` and `MODE=malformed`: failure ends loading and is actionable; no success notice. Restore healthy mode and pull to recover.
- [ ] Warm launch, foreground, repeated pull, rapid Today↔Month switching: log request counts and time-to-first-useful-content. Only the visible tab refreshes on foreground; same-view overlaps share work. Do not mistake the backend's upstream coalescing for client cross-view coalescing.
- [ ] Background while initial loading is pending, let it finish, and remain backgrounded for >60 seconds: automatic Today/Month work pauses; return to visible tab resumes. Navigate away while its initial task is loading and confirm its auto-refresh does not start after disappearance. Check memory for retained view models/timers.
- [ ] Warm cache then stop fixture/enable airplane mode: last-success data stays visible with stale/error text; retries finish within client timeout. Restart and retry; fresh data replaces stale. Cold offline launch must show retry, not an endless spinner.
- [ ] Corrupt one test cache JSON file, then relaunch: ignore the bad cache and recover. Switch London day/month and test DST boundaries; yesterday's total is not shown as today's current data, previous-month cache matches its requested period. Older month caches lacking the period field are safely ignored.
- [ ] `MODE=save-failure`: type amount, note, description, source and date; submit; all input is retained and error uses failure styling. Tap twice rapidly: at most one concurrent POST. A later successful save clears only the per-sale fields and keeps source/date. Check recent manual entries before retrying any response whose outcome is uncertain; no durable idempotency is claimed.
- [ ] Force a slow pre-save metrics request, then confirm a manual save on the development backend; ensure a fresh post-write request runs and the old response cannot repopulate backend cache. Repeat for month-goal edits and payout flags. Fixture-only fixed totals cannot prove this.

## Unchanged journeys requiring regression review

- [ ] Test Google sign-in/expiry/account switch, current/previous/next month navigation and event create/edit on an explicitly approved test calendar. Record the known calendar ordering/cache-scope follow-up; do not use a production calendar for convenience.
- [ ] Test rota signup/removal/weekly schedule and error recovery on isolated development data. Verify failed mutations do not claim success and separate sections remain usable.
- [ ] Compare Today, Month, historical Month, day line breakdown, seller paid/unpaid and manual date/source totals before/after with the same fixtures. Include consignment, discounts and refund examples; existing semantic discrepancies remain release/reporting decisions, not fixed by this refactor.
- [ ] Verify existing notification deep links to a day/seller from local synthetic notifications. Real APNs delivery is unavailable in cloud and belongs to an explicitly approved device check. Rich image push has not been built.
- [ ] Dynamic Type through accessibility sizes, VoiceOver labels/focus, contrast, reduced motion, tap targets, scroll position and keyboard usability. Measure taps/time for checking sales, recording a manual sale and looking up an event.
- [ ] Instruments: Time Profiler, Main Thread Checker, memory/allocations and network trace on a representative physical iPhone. Capture 20 cold/warm/foreground samples under agreed healthy/slow/offline profiles. Report median/p95, first useful content, each section completion, request count, cache state, payload bytes and max memory. Proposed <1s cached / <3s p95 fresh budgets remain unverified targets.

## Crosstopher and later feature hardware gates

- [ ] In an isolated synthetic browser profile and local Worker, two sellers remain isolated through token change, offline reopen and delayed sync. Preserve unsent work; never upload seller A's outbox as seller B. Do not use production seed.sql or migration commands.
- [ ] At 461/1,400/5,000 synthetic garments, full sync returns every record, ordered photos and correct listings. Confirm no locally pruned item merely fell outside a server page. Test signed photo fetching separately; benchmark disabled signing and did not measure R2/D1 remote latency.
- [ ] Capture offline, close/reopen, resume upload, duplicate import and double confirm. Verify separate tag photos, corrected readings and photographed “To write up” drafts. Run the twenty-tag scoring tools only on permitted supplied photos; never run `score-live.mjs` as an unattended test.
- [ ] With the shop team and explicit live-action approval later: BLE print/reprint, disconnect mid-strip, battery/paper recovery, duplicate strips and physical attachment confirmation. Check POS scanner and phone camera; a scan into a basket is not a sale.
- [ ] Sold-during-review/print/listing, human Vinted removal and double-sale conflict recovery with approved test accounts/hardware. Existing confirm queues a POS product; do not use real stock during a supposedly read-only review.
- [ ] Rich push's later gate: service extension compilation/signing, mutable-content payload, expiry/download timeout, placeholder, recipient settings, lock-screen privacy and real APNs delivery. In-app thumbnails do not prove rich push works.

## Sign-off record

Record reviewer, both SHAs, Mac/Xcode/device versions, environment/data source, passed/failed checks, logs/screenshots/xcresults, timings, known issues and next action. Leave release-ready **false** until native/device and owner review are complete. Revert the separate foundation commits if needed; no data migration or production rollback is required for this unshipped work.

## Continuation cloud evidence — 2 November 2026

Cloud rerun: Node 22.23.4, locked installs, `cd backend && NODE_ENV=test npm test` passes 23 checks (including one parent); `SAMPLES=5 node scripts/benchmark.mjs` passes actual loopback endpoint assertions. The new manual-store tests use temporary synthetic JSON only and cover uncapped aggregation plus in-process mutation serialisation. See `evidence/fitsin-tests-continuation.txt` and `evidence/backend-continuation.json`. These results do not complete any native/device checkbox above.

Crosstopher: `npm test` passes 636 tests, `npm run typecheck`, `npx tsc -p apps/worker/tsconfig.json --noEmit` and `npm run build -w @crosstopher/web` pass. Run the opt-in synthetic benchmark with `PERF_OUTPUT=/tmp/crosstopher-list.json npx vitest run --project worker apps/worker/test/performance.test.ts`. Signed photo correctness is covered by the ordinary snapshot tests, but this timing probe still disables signing.

## Optional stock card — include in the final local batch

The read-only shared-business bridge remains disabled by default. Follow [STOCK-BRIDGE.md](STOCK-BRIDGE.md) for its contract and synthetic fixture modes. In the isolated fixture app build only, pass `STOCK_SUMMARY_ENABLED=YES` and verify the built Info.plist contains YES. Sales must remain visible while stock is delayed/failing; stock error is not a zero count. Verify same-scope saved data keeps its original timestamp, unauthorized/changed scope clears it, disabled hides it, and later healthy refresh recovers. Confirm default NO performs no stock request and displays no card. Test VoiceOver/Dynamic Type and normal external-link authentication in an approved development instance; no real source credentials are needed for the synthetic fixture. The seven native tests are authored, not yet run.

## Final cloud review evidence — 2 November 2026

The final cloud rerun passes 33 Fitsin checks, 651 Crosstopher tests, root/Worker typechecks, web build, both synthetic size probes and the connected real-route bridge test. See CHECKPOINT.md for exact commands/evidence and limits. No native/device checkbox has been completed: **all seven Swift tests remain authored, unexecuted**. The independent deadline test was made deterministic after a CPU-contention failure; the final suite passes.

Additional final-batch checks: simulate a corrupt manual-entry store in the disposable development backend and confirm a failed save preserves the file and form input; restore the synthetic store and verify recovery. For the optional card, distinguish malformed same-scope source data (saved-data outage) from source 401/403 or wrong scope (clear saved data). The cloud connected test proves local HTTPS/asset routing only; actual Cloudflare Access and ordinary browser login must be validated later using separately approved development configuration. Leave all production switches off.
