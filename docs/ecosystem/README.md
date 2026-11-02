# Fitsin ecosystem programme

Saved 2 November 2026. Owner: Louis. Status: planning and handover only.

## Read in this order

1. [Product plan and complete opportunity list](PRODUCT-PLAN.md)
2. [Performance, reliability and usability plan](PERFORMANCE-PLAN.md)
3. [Cloud setup and new-session handover](CLOUD-HANDOVER.md)
4. [Ready-to-paste new-session goal](NEW-SESSION-GOAL.md)

## User direction

- Connect Fitsin MVP and Crosstopher into a useful shop ecosystem.
- Retain the broad idea list. The user has not rejected the suggestions and will gate features when it is time to build; inclusion is not blanket implementation approval.
- Support old stock without SKUs/barcodes, partial records, manual sales and offline shop workflows.
- Reuse Crosstopher's existing tag-photo/OCR capability for the backlog.
- Show the garment's first image on matched sales in the app; consider rich push notifications separately.
- Treat the current app's poor speed, intermittent loading failures and low usability as a core workstream, not polish at the end.
- Prepare work for a new Codex cloud session so progress does not depend on the laptop being awake.
- Do not invoke Claude, Claude Code, its plugin, or Anthropic APIs. Do not check their authentication/quota. The user no longer subscribes; older delegation instructions are superseded.

## Current execution status

The synchronised cloud audit and bounded foundation implementation are complete for review on `codex/foundation-reliability` and Crosstopher `codex/ecosystem-audit`. Nothing has been merged or deployed. Native compilation/device verification remain pending; this is not a release-ready declaration.

- [Audit and corrected capability inventory](AUDIT-2026-11-02.md)
- [Measured synthetic baseline and reproduction](BASELINE.md)
- [Proposed integration contracts](INTEGRATION-CONTRACTS.md)
- [Complete dependency/acceptance backlog, including all 76 candidate bullets](MILESTONES.md)
- [Xcode/device/manual verification checklist](LOCAL-VERIFICATION.md)
- [Next-session checkpoint and owner gate](CHECKPOINT.md)

## Programme tracker

| Gate | Scope | Status |
| --- | --- | --- |
| 0 | Cloud readiness, baseline audit, concrete delivery proposals | Complete on synchronised bases; evidence saved |
| 1 | Performance/reliability/usability foundation | Bounded changes implemented/tested in cloud; native tests authored but unrun; local review before release |
| 2 | Shared identity, item and transaction contracts | Proposed |
| 3 | Backlog capture and draft-completion workflows | Proposed |
| 4 | Connected Today and image-led sales | Proposed |
| 5 | Reconciled sales, refunds and reporting | Proposed |
| 6 | Stock intelligence, events and selected wider ideas | Retained candidates |

Update this tracker after each approved delivery slice with evidence, remaining checks and the next decision. Never mark native/device validation complete based solely on a cloud code review.
