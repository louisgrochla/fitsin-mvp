# Performance, reliability and usability foundation

Date: 2 November 2026. Priority: first delivery gate. Planning only; no profiling or implementation completed in this documentation task.

## User problem

The current app is slow to load, sometimes does not load at all, is poorly optimised and is not pleasant to use. The user explicitly wants refactoring, caching and better management/presentation of data. Interpret this primarily as Fitsin MVP; evaluate the Crosstopher integration cost and clarify any additional affected surfaces during the audit.

Outcome: useful content appears promptly, failures are recoverable, existing data remains visible, and routine shop work requires fewer steps. Refactor around measured bottlenecks, not a wholesale rewrite chosen in advance.

Remote publication check: GitHub main contains a newer code commit (`bc2fd55132561cdeb248c1ae0f2c82941e42ad96`) than the local checkout inspected here. Recheck the observations below against the cloud checkout before acting; see CLOUD-HANDOVER.md.

## Observed code, not measured root causes

| Evidence in Fitsin repository | What to investigate |
| --- | --- |
| `ios/FitsinMVP/Views/RootTabView.swift` reloads Today, Month, Events and rota on foreground | Request bursts, hidden-tab work and overlapping lifecycle refreshes |
| `ios/FitsinMVP/ViewModels/TodayViewModel.swift` fetches Today and Month and awaits both before assigning fresh Today data | An unrelated slow/failing month request delaying or suppressing useful Today results |
| Today also has an auto-refresh loop; Month has its own loading path | Shared in-flight requests, cancellation, response ordering and duplicate refreshes |
| `ios/FitsinMVP/Storage/LocalCache.swift` uses synchronous JSON file reads/writes without a freshness envelope | Main-thread work, account scoping, schema versioning, atomic writes, age display and corruption recovery |
| `ios/FitsinMVP/Networking/APIClient.swift` uses a 20-second request timeout | Whole-request budget and actionable error distinctions |
| `backend/src/utils/http.js` allows repeated upstream attempts with a 15-second timeout each | Backend work continuing past the client's timeout and compounding latency |
| `backend/src/utils/cache.js` is process-local TTL/stale storage | Cold caches, stampedes, in-flight deduplication and restart behaviour |
| `backend/src/services/metrics.js` builds Today/Month from historical sales and deductions | Repeated upstream reads, duplicated aggregation and opportunities for shared snapshots |
| Existing iOS and backend caching already exists | Repair and measure caching policy rather than describing the app as having none |

Other audit items: runtime API URL, hosting cold starts, network quality, upstream limits, payload size, historical pagination, existing screen loading states, calendar authentication, and persistence durability. Do not claim any is the live cause without evidence. Older deployment docs mention temporary endpoints; verify actual configuration without exposing secrets.

Identity issue to include in the contract audit: APIClient contains an embedded shared app credential and its warm-up path uses a different credential source. Never copy credential values into reports/fixtures. An account-scoped integration must not inherit an ambiguous authentication/cache boundary.

## Baseline before changes

Record build/commit, device or test host, dataset size, network conditions, sample count and timing methodology. Separate synthetic tests from real-device/live measurements.

- Cold launch without cache; warm launch; foreground resume; pull-to-refresh; tab switching.
- Time to first useful content and to each refreshed section; median/tail latency.
- Request count per journey, duplicate calls, response sizes, backend and upstream time.
- Cache hit/miss/age, retries, cancellations and errors without logging private payloads.
- Main-thread work, memory, list scrolling and image decoding when Apple tools are available.
- Offline, slow network, server timeout, malformed payload, expired login, one upstream failing.
- Write flows: manual sale, target update, rota/event changes and freshness after mutation.
- Synthetic inventory fixtures around 461, 1,400 and 5,000 items; varied photos, unmatched sales and incomplete records. These are test sizes, not asserted live counts.

## Proposed refactoring slices

### Data loading and state

- Shared repositories/stores for common Today/Month data with in-flight coalescing.
- Render independent successful sections immediately; avoid all-or-nothing screens.
- Explicit initial/loading/content/stale/empty/error/unauthorised states per section.
- Load cached content before revalidation; show last successful refresh and stale status.
- Prioritise visible content, defer optional/background work and define foreground refresh policy.
- Cancel superseded work, prevent old responses overwriting newer state and preserve scroll/filter state.
- Coordinate pull-to-refresh, timers and foreground events rather than adding another refresh trigger.

### Cache correctness

- Account/seller/store/query-scoped keys; never reuse another user's data after logout/switch.
- Versioned cache envelopes with timestamps and explicit TTL/stale policies.
- Off-main-thread I/O where needed; atomic writes and safe corrupt-cache fallback.
- Mutation-specific invalidation or updates and financial freshness rules.
- Bounded memory/disk usage; no indefinite stale display presented as current truth.
- Shared backend fetches and request coalescing; evaluate persistent precomputed aggregates only if measurements justify the operational cost.
- Do not hide incorrect totals with longer TTLs.

### Network/backend reliability

- Align client and backend end-to-end deadlines; bounded retry/backoff and cancellation.
- Avoid automatically retrying non-idempotent writes without stable operation IDs.
- Share historical source reads; incrementally update summaries where safe.
- Paginate/filter detailed lists and return compact summary payloads.
- Decouple optional sections from upstream failures, while showing which numbers are incomplete.
- Instrument failures and cache status; add reliable reconciliation before financial integration.
- Verify cache invalidation after sales, manual edits, refunds and goal changes.

### Presentation and usability

- Show the most useful information first; secondary detail opens on demand.
- Keep readable existing content during background refresh rather than blanking a whole screen.
- Clear empty versus failure states, retry actions and accurate save feedback.
- Preserve manual-entry input if saving fails; prevent accidental duplicate submissions.
- Test navigation, tap count and task completion for a quick sales check, manual entry, event lookup and backlog handoff.
- Consistent date/currency formatting, legible typography, accessible labels and Dynamic Type.
- Lazy/paginated lists and thumbnail-sized images with bounded prefetching; avoid loading every original photo.
- Offline indicators distinguish saved locally, queued and confirmed on the server.

## Proposed acceptance budgets

These are initial engineering targets, to confirm against the baseline and representative device; they are not measured achievements or user-approved guarantees.

- Cached useful content visible within 1 second on the agreed representative device.
- Tab switching with cached content does not wait for network completion.
- Under controlled healthy-network fixtures, useful fresh primary content within 3 seconds at p95; record the test sample size.
- One slow/failing optional endpoint cannot prevent other useful sections appearing.
- Concurrent consumers share one in-flight request for an identical resource/key.
- Every request terminates in content, an honest stale state or actionable error within the declared deadline; no endless spinner.
- No known cross-account cache reuse, duplicate financial writes or altered totals from the refactor.
- Show before/after evidence for latency, request count and failures; do not claim a percentage improvement without a comparable baseline.

## Verification and release evidence

Use targeted backend/cache/contract tests, deterministic delayed/error responses and manual UX checks. Add native tests appropriate to changed behaviour; do not replace device validation with source inspection.

Cloud can verify backend/TypeScript work and many contracts/fixtures. SwiftUI compilation, iOS simulator checks, device responsiveness, APNs image delivery and physical scanner/printer behaviour need suitable Apple tooling/devices. A separately configured macOS CI service could remove dependence on the laptop for builds; its access, cost and signing setup are not assumed or approved.

Each slice should report changed behaviour, evidence, unchanged financial invariants, rollback approach, and remaining Apple/device checks. Preserve compatibility while old deployed app versions still exist.
