export class TTLCache {
  #store = new Map();
  #inflight = new Map();

  // Mutations detach a flight: new readers cannot join it and its old result
  // cannot repopulate the cache after a successful write.
  async load(key, producer, ttlMs, maxStaleMs) {
    const hit = this.get(key);
    if (hit !== null) return { payload: hit, stale: false };
    if (this.#inflight.has(key)) return this.#inflight.get(key).promise;

    const flight = {};
    this.#inflight.set(key, flight);
    flight.promise = Promise.resolve().then(producer).then((payload) => {
      if (this.#inflight.get(key) === flight) this.set(key, payload, ttlMs);
      return { payload, stale: false };
    }).catch((error) => {
      const stale = this.getStale(key, maxStaleMs);
      if (stale !== null) return { payload: stale, stale: true };
      throw error;
    }).finally(() => {
      if (this.#inflight.get(key) === flight) this.#inflight.delete(key);
    });
    return flight.promise;
  }

  get(key) {
    const hit = this.#store.get(key);
    if (!hit) return null;
    if (Date.now() > hit.expiresAt) {
      return null;
    }
    return hit.value;
  }

  getStale(key, maxStaleMs) {
    const hit = this.#store.get(key);
    if (!hit) return null;
    if (Date.now() > hit.expiresAt + maxStaleMs) {
      this.#store.delete(key);
      return null;
    }
    return hit.value;
  }

  set(key, value, ttlMs) {
    this.#store.set(key, { value, expiresAt: Date.now() + ttlMs });
  }

  delete(key) {
    this.#store.delete(key);
    this.#inflight.delete(key);
  }

  clear() {
    this.#store.clear();
    this.#inflight.clear();
  }
}
