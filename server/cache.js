// Simple in-memory cache with TTL
const cache = new Map();
const TTL = 5 * 60 * 1000; // 5 minutes

module.exports = {
  get(key) {
    const entry = cache.get(key);
    if (!entry) return null;
    if (Date.now() - entry.timestamp > TTL) {
      cache.delete(key);
      return null;
    }
    return entry.data;
  },
  set(key, data) {
    cache.set(key, { data, timestamp: Date.now() });
  },
  getAll() {
    const entries = [];
    for (const [key, entry] of cache.entries()) {
      if (Date.now() - entry.timestamp <= TTL) {
        entries.push({ key, data: entry.data });
      } else {
        cache.delete(key);
      }
    }
    return entries;
  },
  clear() {
    cache.clear();
  }
};
