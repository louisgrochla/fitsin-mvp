# Synthetic baseline and verification evidence

Measured on 2 November 2026, Linux x86_64, Node 22.23.4/npm 10.9.9. Before bases: Fitsin `19b57ad`, Crosstopher `d580b59`. After runtime code: Fitsin `203fe6e` (backend) / `7b89bae` (native source), Crosstopher `20c5250`. Native source is unbuilt. Raw results are committed in `evidence/` in each repository. Earlier pre-synchronisation Crosstopher results were set aside and are not used here.

## Fitsin: actual local Express endpoints

`backend/scripts/benchmark.mjs` starts the real server in a subprocess with isolated temporary JSON storage, a fixed London clock (2 November 2026 noon) and a fetch fixture that refuses all non-synthetic destinations. Each cold sample starts a new process/cache. Eight simultaneous clients request four Today and four Month responses; the timer covers completion of the entire burst, not first useful UI content. The fake source returns 100 records/page with 2 ms asynchronous delay, £10/order, two business dates, empty line arrays (unmatched to garments), no deductions/manual amounts. Five samples/size; nearest-rank p95 with five samples is simply the largest observation. Do not use these small-sample tails as a service SLA.

| Synthetic records | Cold median ms before → after | Cold p95 ms before → after | Upstream reads per burst before → after | Month payload bytes |
| --- | --- | --- | --- | --- |
| 461 | 294.7 → 147.9 | 369.0 → 172.4 | 70–80 → 20 | 1,506 (unchanged) |
| 1,400 | 556.8 → 255.3 | 580.6 → 309.3 | 224 → 56 | 1,508 (unchanged) |
| 5,000 | 1677.4 → 577.0 | 1711.9 → 645.4 | 800 → 200 | 1,510 (unchanged) |

Warm reads made zero upstream calls before and after at all sizes. Raw `warmMs` is the last sample's individual warm request, not a median. A few small baseline requests joined already completed cache results, hence the 461-row count range. After the change, all samples use one producer per resource. Today and Month still each fetch history and deductions; this is not shared-source snapshot caching.

After TTL expiry, an injected 503 served the previous value with `data_delayed=true`; after recovery it served fresh data with `data_delayed=false` in both versions. Assertions check expected Today/month amounts and response codes; unchanged payload bytes are not by themselves a complete financial validation.

Backend tests: **7 baseline → 18 passing**. Added cases cover cold/warm sharing, different keys, delete/clear during a flight, old completion versus new flight, stale expiry/recovery, GET retry cap, explicit read-only POST retries, no automatic POST/PATCH retries, 401, caller cancellation, stalled response bodies, retry backoff and shared sequential/parallel deadline. Short test deadlines exercise the same cancellation path as the production 18-second budget. The 18-second setting itself is a policy, not a live phone measurement.

## Crosstopher: full seller snapshot

The opt-in `apps/worker/test/performance.test.ts` uses the real migration SQL through the existing better-sqlite3 D1 stand-in and invokes `SellerScope.listItems()`. Ten measured calls per size, two synthetic sellers, 80% of own items with two ordered photos, some empty titles and no external services. Timing includes local SQL, mapping and unsigned view assembly; excludes fixture setup/assertions/JSON serialisation. A separate regression compares list views to single-item views with mixed channel listings and empty children. Photo signing is disabled in the timing fixture; no R2, actual D1 network, browser rendering or cold OCR download is measured.

| Synthetic garments returned | Median ms before → after | p95 ms before → after | JSON bytes |
| --- | --- | --- | --- |
| 461 / 461 | 12.9 → 6.7 | 14.8 → 7.4 | 449,951 (unchanged) |
| 1,400 / 1,400 | 67.0 → 19.6 | 80.3 → 32.5 | 1,371,453 (unchanged) |
| 5,000 / 5,000 | 534.7 → 74.4 | 651.4 → 80.2 | 4,917,033 (unchanged) |

The complete snapshot is retained, including >500 records. Source changes replace repeated photo/listing array scans with one grouping pass; SQL seller filtering, item/child ordering, signing, lifecycle and publication rules are unchanged. Payload size still grows to ~4.9 MB in this fixture; do not interpret faster assembly as a solved network/sync problem. Pagination requires an atomic snapshot/cursor protocol on the client before it is safe.

Updated baseline: **634 passing tests** (the newly added timing test is skipped in the normal suite). After: **635 passing tests**, plus the opt-in benchmark passed at every size. Root typecheck, explicit Worker typecheck and web production build passed. Root typecheck alone covers packages, not Worker/web; the extra checks matter. Web build retains a >500 kB main-chunk warning; OCR core is ~3.95 MB and committed English data ~2.94 MB. Existing parser/frame/review tests pass, but no representative tag-photo OCR accuracy result was produced here.

## Reproduce

Choose Node 22.23.4 (the prepared environment has `source /workspace/dev-setup/activate.sh`). On a different machine select Node 22.18+ compatible with the lockfile/native addon, then record the exact version.

FitsIn, from repository root:

```sh
npm ci --prefix backend
NODE_ENV=test npm test --prefix backend
node backend/scripts/benchmark.mjs
MODE=week-failure node backend/scripts/ios-fixture.mjs
```

The last command is a local manual fixture, not a benchmark and not an external service. Stop it with Ctrl-C. Its five GET routes were smoke-checked as valid JSON in cloud; native rendering is unverified.

Crosstopher, from repository root:

```sh
npm ci
npm test
npm run typecheck
npx tsc -p apps/worker/tsconfig.json --noEmit
npm run build -w @crosstopher/web
PERF_OUTPUT=/tmp/crosstopher-list.json npx vitest run apps/worker/test/performance.test.ts
```

For a fresh **before** measurement, create a detached worktree at the base SHA, copy only the corresponding benchmark script/fixture (FitsIn) or performance test (Crosstopher) from the reviewed branch into that worktree, install its lockfile and run the same command there. The Fitsin before measurement in this report was rerun in a detached `19b57ad` worktree after synchronisation. No application code was changed in that baseline. For after, use the implementation commits above. Do not compare the superseded capped-list Crosstopher checkout to the current uncapped list.

## Unavailable or not established

Actual iPhone cold/warm/foreground/scrolling timings, main-thread cache I/O, memory, native compilation, API host cold starts, real upstream throttling/pagination sizes, APNs, camera/OCR accuracy, BLE printing, physical attachment and POS scan-to-sale behaviour are **unavailable**. The source audit identifies plausible bottlenecks and risks; it does not establish the cause of live slowness. Native first-content <1s cached and <3s p95 fresh remain proposed budgets. Calendar/rota/detail races, identity caches, durable/manual financial idempotency, refund correctness, persistence concurrency and shared history across different endpoints are follow-up work. See LOCAL-VERIFICATION.md and MILESTONES.md.
