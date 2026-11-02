# Ready-to-paste goal for a new Codex cloud session

Use after both repositories and the documentation are available in the published environment. The owner authorises bulk cloud development of the performance/reliability foundation, with local iOS tooling and manual review before release. New ecosystem features remain gated; this is not approval to implement the entire catalogue.

---

Read `docs/ecosystem/README.md`, `PRODUCT-PLAN.md`, `PERFORMANCE-PLAN.md` and `CLOUD-HANDOVER.md` in the Fitsin MVP repository. They preserve my product direction and the context from our planning conversation. Discover the actual cloud paths for both `louisgrochla/fitsin-mvp` and `louisgrochla/Crosstopher`; do not assume Mac paths exist.

My overall objective is a fast, reliable, pleasant-to-use Fitsin app connected to Crosstopher: mixed legacy/new stock, tag-photo/OCR backlog, existing draft completion, manually entered and scanned sales, first garment images on matched sales, richer notifications, daily actions and eventually trustworthy reporting. Keep the entire idea list; I have not rejected those ideas and will gate them when we build.

The current app is slow, sometimes does not load, and has poor usability. Performance, caching, reliability and data presentation come first, before expanding its workload. Around 33% of physical stock is recorded: 461 garments, 168 online and 128 drafts described as in-store but not online. Those are approximate owner-reported figures, not a fresh stocktake or guaranteed disjoint status groups.

Use Codex only. Do not invoke Claude, Claude Code, its plugin or Anthropic APIs, and do not check their authentication or quota. This supersedes older delegation instructions.

Your goal is to audit the current remote code, implement a measured performance/reliability foundation, and prepare the remaining programme for gated delivery:

1. Verify both checkouts, revisions, instructions, dependencies and local test/build capabilities. Preserve existing changes. If a repository is unavailable, continue independent work and identify the exact missing access.
2. Inspect actual code and existing workflows, especially OCR/backlog, sales semantics and loading/cache behaviour. Separate implemented behaviour, historical documentation, hypotheses and verified runtime findings.
3. Establish a reproducible synthetic baseline for loading, failure recovery, request counts and backend timings. Document what cannot be measured without an iPhone, Xcode, live access or physical hardware. Never claim source inspection proves live performance.
4. Audit current Fitsin UX journeys and propose concrete loading/error/empty/stale states and navigation improvements. Propose a small first refactor slice with before/after acceptance criteria, rather than a blanket rewrite.
5. Design the integration contracts and data ownership: seller identity/permissions; garment/SKU matching; transaction provenance and deduplication; manual unmatched sales; real sale amounts/refunds; image access; independent section freshness. Preserve seller isolation and never mistake asking price for money received.
6. Map every product-plan idea into dependency-ordered, reviewable slices. Keep all ideas, identifying existing capability, required work, verification and owner decisions. Separate a read-only summary bridge, in-app images and rich native push delivery.
7. Implement small, reviewable performance/reliability improvements to existing behaviour where the audit establishes a clear benefit. You are authorised to refactor request coordination, independent loading states, caching, bounded retries, data presentation and related regression tests. Preserve financial semantics, API compatibility and seller visibility. Do not stop at a plan when this bounded work can proceed.
8. Save findings, baseline evidence, proposed contracts, a milestone backlog and the next-session checkpoint in the repository. Mark measurements as measured or unavailable, not guessed. Include a precise local Xcode/device/manual-review checklist and before/after evidence for cloud-verifiable behaviour.

Work autonomously on the audit, local fixtures/tests, design, documentation and bounded foundation implementation described above. Use separate codex/ branches and reviewable commits or draft PRs. Do not merge to main. New backlog/integration/financial/customer-facing features still need my feature gate; retain them in the plan rather than silently building or dropping them. Do not deploy, migrate production, publish/delist marketplace items, send messages, add paid services or alter seller visibility. Do not import production secrets/customer data for convenience.

Once the foundation changes and concrete proposals are ready, present the reviewable changes, outstanding local checks, recommended next feature gate and specific decisions I need to make. I want a reviewable proposal at that point, not permission questions before you have done the independent groundwork. Cloud work should not depend on my laptop; explicitly track the later Xcode/macOS, APNs and shop-hardware validation that cloud alone cannot complete.

Completion means both repositories have been assessed (or a precise access blocker recorded), available baseline checks have run, justified foundation changes are implemented and tested in reviewable branches, every remaining proposed slice has acceptance criteria and dependencies, and a durable handover identifies the next owner gate and all local verification. Do not mark the iOS app release-ready without Xcode/device checks. It does not mean the entire ecosystem has been implemented.
