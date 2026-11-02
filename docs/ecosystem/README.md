# Fitsin ecosystem programme

Updated 2 November 2026. Owner: Louis. Status: foundation complete for draft review; local native build goal prepared; new native workflows not yet implemented.

## Current product direction

The owner wants a native iOS read/write business workspace: redesigned stock workflows, a continuous live scanner, photos, Bluetooth tags/stickers and connected daily work. One shared business comes first; separate businesses come later. The implemented default-off stock summary is a foundation component, not the finished integration. Preserve the existing web app/backend while building native coverage.

## Start the local Mac session

1. [Current checkpoint and evidence](CHECKPOINT.md)
2. [Local native build goal, autonomy rules and tests](NEW-SESSION-GOAL.md)
3. [Native workspace and capability map](NATIVE-WORKSPACE.md)
4. [Live scanner behavior and evaluation](NATIVE-SCANNER.md)
5. [Optional rail/stocktake and later research design](LOCATIONS-STOCKTAKE.md)
6. [Existing local verification checklist](LOCAL-VERIFICATION.md)

The goal authorises continuous implementation through the included workflows, not repeated approval after each slice. Run automated Xcode/simulator checks throughout; batch owner-assisted physical/manual checks at the end. Keep durable checkpoints and both PRs draft. No cloud environment is required.

## Standing decisions

- Shared access to one existing seller/business; preserve all foreign-seller boundaries.
- Native SwiftUI read/write journeys and redesigned phone UX; existing web/backend operation remains usable.
- Live OCR overhaul with stable automatic acceptance and exception correction; preserve existing web backlog rather than rebuilding it.
- Optional rail assignment and stocktaking after the core workflows, default off; never require a rail during initial listing. Ten upstairs rails do not limit the future basement.
- Honest source amounts, unmatched sales and incomplete stock coverage; no invented payment/settlement data.
- Speed, offline recovery and independent loading are part of functional acceptance.
- Rich push, financial reconciliation, separate-business SaaS and the dissertation visual-tracking system remain later work.
- Codex only. No Claude/Anthropic tooling or authentication checks.
- No merge, deployment, production migrations/credentials, live integration/marketplace/calendar actions, notifications/messages or purchases.

## Programme status

| Work | Status |
| --- | --- |
| Performance/reliability foundation and default-off read-only bridge | Implemented and tested in cloud; draft review; historical evidence in checkpoint |
| Native read/write identity, storage/outbox and complete shop workflows | Included in the local build goal; not implemented by the documentation update |
| Live scanner, native photos and Bluetooth printing | Included in the local build goal; hardware/accuracy acceptance still required |
| Native operational coverage and connected Today/sale detail | Included in the local build goal |
| Optional location/assignment/stocktake module | Included after core workflows; default off; synthetic testing only |
| Dissertation visual tracking, rich push, finance/reconciliation and wider opportunities | Retained future work; not blanket implementation approval |

Nothing has been merged or deployed. Seven native foundation tests were authored but not executed in cloud; locate any subsequent local evidence and record exact revisions/results. Do not declare release readiness.

## Source evidence and retained planning

- [Product plan and full opportunity list](PRODUCT-PLAN.md)
- [Performance, reliability and usability plan](PERFORMANCE-PLAN.md)
- [Audit and corrected capability inventory](AUDIT-2026-11-02.md)
- [Measured synthetic baseline and reproduction](BASELINE.md)
- [Existing bridge contract](STOCK-BRIDGE.md)
- [Integration contracts and later proposals](INTEGRATION-CONTRACTS.md)
- [Complete dependency/acceptance backlog, including all 76 candidate bullets](MILESTONES.md)
- [Historical cloud setup handover](CLOUD-HANDOVER.md)

Latest owner direction and NEW-SESSION-GOAL.md supersede old stopping points in the historical packet. Update the tracker and checkpoint as implementation progresses; keep authored, simulated, executed and hardware-verified results distinct.
