const http = require('http');

const BASE = 'http://localhost:3001';
let passed = 0, failed = 0;

function test(name, fn) {
  return new Promise(resolve => {
    fn()
      .then(() => { console.log('  PASS:', name); passed++; resolve(); })
      .catch(err => { console.log('  FAIL:', name, '-', err.message); failed++; resolve(); });
  });
}

function get(path) {
  return new Promise((resolve, reject) => {
    http.get(BASE + path, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(data) }); }
        catch (e) { reject(new Error('Invalid JSON: ' + data.slice(0, 100))); }
      });
    }).on('error', reject);
  });
}

(async () => {
  console.log('API Test Suite');
  console.log('==============');

  await test('Missing query returns 400', async () => {
    const r = await get('/api/search');
    if (r.status !== 400) throw new Error('Expected 400, got ' + r.status);
    if (!r.data.error) throw new Error('Expected error message');
  });

  await test('Search returns results array', async () => {
    const r = await get('/api/search?q=RTX+4090');
    if (r.status !== 200) throw new Error('Expected 200, got ' + r.status);
    if (!Array.isArray(r.data.results)) throw new Error('results is not an array');
  });

  await test('Results have required properties', async () => {
    const r = await get('/api/search?q=RTX+4090');
    if (!r.data.results.length) {
      console.log('  INFO: No results returned (stores may block scraping)');
      return;
    }
    r.data.results.forEach((p, i) => {
      ['id', 'name', 'price', 'source'].forEach(prop => {
        if (p[prop] === undefined || p[prop] === null)
          throw new Error('Result ' + i + ' missing property: ' + prop);
      });
      if (typeof p.price !== 'number') throw new Error('Result ' + i + ' price is not a number');
    });
  });

  await test('Error object present for each store', async () => {
    const r = await get('/api/search?q=RTX+4090');
    ['amazon', 'bestbuy', 'newegg'].forEach(s => {
      if (!(s in r.data.errors)) throw new Error('Missing error field: ' + s);
    });
  });

  await test('Timestamp is valid ISO string', async () => {
    const r = await get('/api/search?q=RTX+4090');
    if (!r.data.timestamp) throw new Error('Missing timestamp');
    if (isNaN(new Date(r.data.timestamp).getTime())) throw new Error('Invalid timestamp');
  });

  console.log('==============');
  console.log('Results:', passed, 'passed,', failed, 'failed');
  process.exit(failed > 0 ? 1 : 0);
})();
