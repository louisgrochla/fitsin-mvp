# Native stock protocol v1

Implemented by Crosstopher `apps/worker/src/native*.ts` and migrations `0021_native_workspace.sql` / `0022_native_workflows.sql`. Migrations have been applied only to disposable SQLite/D1 fixtures. Native access is absent unless `NATIVE_WORKSPACE_ENABLED` is exactly `true`; locations additionally require `NATIVE_LOCATIONS_ENABLED=true`. Tracked Worker defaults are false. Fitsin `NATIVE_WORKSPACE_ENABLED` defaults to NO and workspace URL is blank.

## Identity and transport

`POST /native/session` consumes a high-entropy staff invitation hash and registers a client-generated high-entropy token, session ID and device ID. The exact same request can recover a lost reply; an invite cannot enroll a different session. Only hashes are stored server-side. The server resolves membership, business and its existing seller. Sessions expire in 30 days and may be revoked using `DELETE /native/v1/session`; disabled membership/business also denies access. Native tokens cannot authenticate `/api`, and embedded app codes, web bearer credentials and summary-bridge keys cannot authenticate native writes.

The app stores credentials in WhenUnlockedThisDeviceOnly Keychain and scopes its protected, backup-excluded files by origin/business/actor/device. It accepts HTTPS origins and explicit loopback HTTP for synthetic development; redirects are not followed. No broad ATS exemption was added. `GET /native/v1/session` returns the current identity and optional location capability. Reads and writes use `Cache-Control: no-store`.

## Reads

`GET /native/v1/inventory-version` hashes the owned ordered item IDs and revisions. Clients fetch a complete `/native/v1/read/items` snapshot on change, after pending mutations, or without a saved version. Item revisions advance for web and native writes and relevant child records. No pagination cap is imposed on the existing web snapshot.

`GET /native/v1/read/<allowlisted path>` forwards in-process to existing seller-scoped reads using an unforgeable request-local authority symbol. Supported paths: `me`, `items`, `items/:id`, item `events`, `answers`, `preflight`, `vinted-payload`, owned photo variants, `reviews`, `mappings`, `deleted`, `scans`, scan image, `summary`, `vinted/ready`, `vinted/taxonomy`, `ebay/categories/used`. Provider diagnostics, OAuth setup and arbitrary URLs are excluded. Mappings combine shared vocabulary with business overrides; forget adds only a seller-local tombstone.

`GET /native/v1/scans` returns business accepted scans. `GET /native/v1/sales-link?shop=...&sku=...` returns an owned item ID only for the exact configured Shopify account and immutable SKU, otherwise null. It does not record a sale or change finance data. Source order/line identifiers and amounts stay in the existing Fitsin source line.

## Durable commands

`POST /native/v1/commands` accepts `{id,kind,itemId?,expectedRevision?,data}` (≤256 KiB). `id` is stable across retry/restart. An exact canonical request hash replays its receipt; reusing an ID for different input returns 409. Every `item.*` command needs an owned item and expected revision; creation expects 0 and a reserved SKU owned by that business/device. Unknown/foreign IDs return 404. Version/state races return 409 with user work retained.

The D1 batch rechecks session/membership/business and expected item revision, applies domain statements, writes the replay receipt and deletes a CHECK-constrained guard atomically. Failed guards roll back all SQL, including queued provider jobs. The receipt's revision is read after triggers. Native sale/removal settlement is in that same transaction. Existing web callers continue using the same domain functions without native receipt envelopes.

Kinds: `sku.reserve`; `scan.accept`, `scan.discard`; `item.save`, `item.scan-link`, `item.backlog-link`; `backlog.discard`; `item.print-confirm`, `item.publish`, `item.pull`, `item.restore`, `item.sale`, `item.retry`, `item.listed`, `item.removed`, `item.delete`, `item.remove-twin`, `item.dismiss-conflict`; `item.answer`, `item.forget-answer`, `mapping.forget`; `channel.set-enabled`; optional `location.save`, `item.location`, `item.location-undo`, `stocktake.start`, `stocktake.observe`, `stocktake.complete`.

- Scan acceptance persists description/size/price and observed/received times; it creates no item or provider job. Draft linking does not activate it.
- Print confirmation carries the printed tag snapshot and rejects stale label contents. It retains the existing explicit print → activation/POS semantics. Physically attached is a separate native queue state.
- Duplicate removal includes `keptItemId` and `keptRevision`. Both garments must still match. Native SQL commits the archive, audit and a special Shopify delete job before external work; the existing runner retries and treats already-missing products as success. Restore is blocked while deletion is pending/failed. Other marketplaces must already be down.
- Channel toggles compare `expectedEnabled`. They do not configure credentials. Manual channels require explicit human listed/removed confirmations.

## Photos

`PUT /native/v1/photos/:itemId/:photoId/:variant` accepts `original` (≤20 MiB) or `web` (≤3 MiB), JPEG/PNG/HEIC, operation ID and expected revision headers. Metadata must already belong to the owned item. Immutable R2 puts record a content hash; a different payload cannot overwrite the key. The SQL photo update and receipt use the same guard. Replay validates exact content/type/revision. Failed database commits can leave unreferenced immutable bytes; cleanup is not performed against production.

## Optional locations

`GET /native/v1/locations` returns locations, recent moves and recent stocktake reports. `location.save` compares the location revision and enforces a same-business, two-level parent hierarchy. A move checks the item's revision and changes only that item. Undo references the latest move and refuses intervening moves. Commands persist observation time/source while server-derived actor/device and receive time remain authoritative. Stocktake start snapshots expected item IDs/revisions/status/location inside the receipt transaction. Observations are durable evidence, not assignments; append-only history preserves each operation. Completion reports seen, not observed, changed, moved, sold, removed and unexpected stock without inferring a sale/deletion from absence.
