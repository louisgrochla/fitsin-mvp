import { config } from '../config.js';
import { readJsonFile, writeJsonFile } from '../utils/storage.js';

// Tracks which consignment seller line items have been paid out. Keyed by the
// stable Shopify item id (`${orderId}:${lineItemId}`) so the state survives
// re-fetches and is shared across every device via the persistent disk.

async function readState() {
  const parsed = await readJsonFile(config.sellerPayoutsFile, null);
  const paid = parsed && typeof parsed.paid === 'object' && parsed.paid !== null ? parsed.paid : {};
  return { paid };
}

async function writeState(state) {
  await writeJsonFile(config.sellerPayoutsFile, {
    paid: state.paid,
    updated_at: new Date().toISOString()
  });
}

// Returns a Set of item ids that have been marked paid.
export async function getPaidItemIds() {
  const { paid } = await readState();
  return new Set(Object.keys(paid).filter((id) => paid[id]?.paid === true));
}

export async function setSellerItemPaid(itemId, paid, by = null) {
  const id = String(itemId || '').trim();
  if (!id) throw new Error('Item id is required.');

  const state = await readState();
  if (paid) {
    state.paid[id] = { paid: true, paid_at: new Date().toISOString(), paid_by: by || null };
  } else {
    delete state.paid[id];
  }
  await writeState(state);
  return { item_id: id, paid: Boolean(paid) };
}
