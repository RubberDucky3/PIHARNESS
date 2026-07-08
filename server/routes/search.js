const cache = require('../cache');
const amazon = require('../scrapers/amazon');
const bestbuy = require('../scrapers/bestbuy');
const newegg = require('../scrapers/newegg');

async function searchAll(query) {
  const cacheKey = 'search_' + query.toLowerCase().trim();
  const cached = cache.get(cacheKey);
  if (cached) { console.log('[Search] Cache hit for', query); return cached; }

  const [amzRes, bbRes, ngRes] = await Promise.allSettled([
    amazon.search(query),
    bestbuy.search(query),
    newegg.search(query),
  ]);

  const results = [];
  const errors = { amazon: null, bestbuy: null, newegg: null };

  if (amzRes.status === 'fulfilled') { results.push(...amzRes.value); }
  else { errors.amazon = amzRes.reason?.message || 'Amazon scrape failed'; }

  if (bbRes.status === 'fulfilled') { results.push(...bbRes.value); }
  else { errors.bestbuy = bbRes.reason?.message || 'Best Buy scrape failed'; }

  if (ngRes.status === 'fulfilled') { results.push(...ngRes.value); }
  else { errors.newegg = ngRes.reason?.message || 'Newegg scrape failed'; }

  const output = { results, errors, timestamp: new Date().toISOString() };
  cache.set(cacheKey, output);
  console.log('[Search]', query, '-', results.length, 'results, errors:', JSON.stringify(errors));
  return output;
}

function findProductById(productId) {
  const entries = cache.getAll();
  for (const entry of entries) {
    if (entry.data && entry.data.results) {
      const product = entry.data.results.find(p => p.id === productId);
      if (product) return product;
    }
  }
  return null;
}

async function handleSearch(req, res) {
  const query = (req.query.q || '').trim();
  if (!query) return res.status(400).json({ error: 'Missing query parameter: q' });
  try {
    const data = await searchAll(query);
    res.json(data);
  } catch (err) {
    console.error('[Search] Error:', err);
    res.status(500).json({ error: err.message });
  }
}

async function handleProduct(req, res) {
  const productId = req.params.id;
  if (!productId) {
    return res.status(400).json({ error: 'Missing product id' });
  }
  try {
    const product = findProductById(productId);
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json(product);
  } catch (err) {
    console.error('[Product] Error:', err);
    res.status(500).json({ error: err.message });
  }
}

module.exports = async function handler(req, res, next) {
  if (req.url.startsWith('/api/product/')) {
    return handleProduct(req, res);
  }
  return handleSearch(req, res, next);
};
