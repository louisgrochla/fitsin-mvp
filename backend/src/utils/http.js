import { AsyncLocalStorage } from 'node:async_hooks';
import { setTimeout as delay } from 'node:timers/promises';

const context = new AsyncLocalStorage();

// Every upstream page/parallel branch of a cached response shares this budget,
// below the app's 20-second timeout. Abort also reaches response body reads.
export async function withUpstreamDeadline(producer, timeoutMs = 18000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(new DOMException('Upstream deadline exceeded', 'TimeoutError')), timeoutMs);
  try {
    const result = await context.run(controller.signal, producer);
    controller.signal.throwIfAborted();
    return result;
  } finally {
    clearTimeout(timer);
    controller.abort();
  }
}

export async function fetchWithRetry(url, options = {}, retries = 2) {
  const { retrySafe = ['GET', 'HEAD'].includes((options.method || 'GET').toUpperCase()), ...fetchOptions } = options;
  const signal = AbortSignal.any([context.getStore(), options.signal, AbortSignal.timeout(15000)].filter(Boolean));
  const attempts = retrySafe ? retries : 0;
  for (let attempt = 0; ; attempt += 1) {
    signal.throwIfAborted();
    try {
      const response = await fetch(url, { ...fetchOptions, signal });
      if (response.status >= 500 && attempt < attempts) {
        await response.body?.cancel();
      } else {
        return response;
      }
    } catch (error) {
      signal.throwIfAborted();
      if (attempt >= attempts) throw error;
    }
    await delay(400 * (attempt + 1), undefined, { signal });
  }
}
