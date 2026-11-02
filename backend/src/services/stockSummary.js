import { fetchWithRetry, withUpstreamDeadline } from '../utils/http.js';

const countKeys = ['drafts', 'active', 'reserved', 'pendingManual', 'doubleSales', 'failedListings', 'openQuestions'];

// No seller selector, financial adapter or stock commands. Configuration is
// captured once per process so an old flight cannot cross a scope change.
export function createStockSummary(bridge, { allowLoopback = false, timeoutMs = 5000 } = {}) {
  let flight;
  const disabled = { schemaVersion: 1, status: 'disabled', complete: false, data: null };
  if (!bridge.enabled) return async () => disabled;
  let base;
  try {
    base = new URL(bridge.baseUrl);
    const loopback = allowLoopback && base.protocol === 'http:' && ['127.0.0.1', '[::1]'].includes(base.hostname);
    if ((!loopback && base.protocol !== 'https:') || base.username || base.password || base.search || base.hash || base.pathname !== '/') throw new Error('invalid origin');
    if (!bridge.sellerId || !bridge.token || bridge.token.trim().length < 32) throw new Error('incomplete bridge');
  } catch {
    return async () => ({ ...disabled, status: 'unavailable' });
  }
  const unavailable = (status = 'unavailable') => ({
    schemaVersion: 1, status, complete: false, sellerId: bridge.sellerId, data: null,
  });
  const read = async () => {
    try {
      return await withUpstreamDeadline(async () => {
        const response = await fetchWithRetry(new URL('/integrations/fitsin/stock-summary', base), {
          headers: { Authorization: `Bearer ${bridge.token}`, Accept: 'application/json' },
          redirect: 'error', retrySafe: false,
        }, 0);
        if (response.status === 401 || response.status === 403) {
          await response.body?.cancel();
          return unavailable('unauthorized');
        }
        if (!response.ok) { await response.body?.cancel(); return unavailable(); }
        // Bound even a malformed upstream response; timeout also covers bodies.
        const reader = response.body.getReader();
        const chunks = [];
        let size = 0;
        try {
          for (;;) {
            const { value, done } = await reader.read();
            if (done) break;
            size += value.byteLength;
            if (size > 16384) throw new Error('oversized summary');
            chunks.push(Buffer.from(value));
          }
        } finally { await reader.cancel(); }
        const payload = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        if (payload.schemaVersion !== 1 || payload.sellerId !== bridge.sellerId ||
            typeof payload.generatedAt !== 'string' || !Number.isFinite(Date.parse(payload.generatedAt)) ||
            !countKeys.every((key) => Number.isSafeInteger(payload.counts?.[key]) && payload.counts[key] >= 0)) {
          // A scope mismatch must also discard the client's previous stock.
          return unavailable('unauthorized');
        }
        return {
          schemaVersion: 1, status: 'fresh', complete: true, sellerId: bridge.sellerId,
          lastSuccessAt: new Date().toISOString(), sourceObservedAt: payload.generatedAt,
          url: base.origin,
          data: Object.fromEntries(countKeys.map((key) => [key, payload.counts[key]])),
        };
      }, timeoutMs);
    } catch { return unavailable(); }
  };
  // Share simultaneous reads only. No disk/stale server cache or credential
  // response is persisted; a later refresh always checks the source again.
  return () => {
    if (!flight) flight = read().finally(() => { flight = null; });
    return flight;
  };
}
