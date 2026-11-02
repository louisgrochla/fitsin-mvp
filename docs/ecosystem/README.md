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

Documentation prepared for remote publication; the owner authorised committing and pushing this packet on 2 November 2026. The owner also authorised bulk cloud foundation development followed by local iOS verification and manual review; see NEW-SESSION-GOAL.md for the bounded scope. No application implementation, deployment, migration, cloud environment creation or new session has been performed. Before starting in cloud, verify that the selected remote revision contains this packet. Existing local Xcode changes are outside the documentation commit.

## Programme tracker

| Gate | Scope | Status |
| --- | --- | --- |
| 0 | Cloud readiness, baseline audit, concrete delivery proposals | Prepared for a new session; not started |
| 1 | Performance/reliability/usability foundation | Authorised for measured, bounded cloud implementation after baseline; local verification before release |
| 2 | Shared identity, item and transaction contracts | Proposed |
| 3 | Backlog capture and draft-completion workflows | Proposed |
| 4 | Connected Today and image-led sales | Proposed |
| 5 | Reconciled sales, refunds and reporting | Proposed |
| 6 | Stock intelligence, events and selected wider ideas | Retained candidates |

Update this tracker after each approved delivery slice with evidence, remaining checks and the next decision. Never mark native/device validation complete based solely on a cloud code review.
