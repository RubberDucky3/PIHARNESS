const axios = require('axios');
const cheerio = require('cheerio');
const USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
let idCounter = 0;
function nextId() { return 'ng-' + (++idCounter); }
async function search(query) {
  try {
    const url = 'https://www.newegg.com/p/pl?d=' + encodeURIComponent(query);
    const { data: html } = await axios.get(url, { headers: { 'User-Agent': USER_AGENT, 'Accept-Language': 'en-US' }, timeout: 10000 });
    const $ = cheerio.load(html);
    const products = [];
    $('.item-cell, .item-container').each((i, el) => {
      if (i >= 10) return false;
      const $el = $(el);
      const name = $el.find('.item-title').first().text().trim();
      if (!name) return;
      const dollars = $el.find('.price-current strong').first().text().replace(/[^0-9]/g, '');
      const cents = $el.find('.price-current sup').first().text().replace(/[^0-9]/g, '');
      let price = parseFloat(dollars + '.' + (cents || '0')) || 0;
      let rating = 0;
      const ratingEl = $el.find('.item-rating');
      const ratingText = ratingEl.attr('aria-label') || ratingEl.text() || '';
      const m = ratingText.match(/([\d.]+)/);
      if (m) rating = parseFloat(m[1]);
      let reviews = 0;
      const revEl = $el.find('.item-rating .count, .item-rating .rating-num');
      reviews = parseInt(revEl.text().replace(/[^0-9]/g, ''), 10) || 0;
      let url = '';
      const href = $el.find('.item-title a').first().attr('href');
      if (href) url = href.startsWith('http') ? href : 'https://www.newegg.com' + href;
      let imageUrl = $el.find('.item-img img').first().attr('src') || '';
      const inStock = !$el.text().toLowerCase().includes('out of stock');
      products.push({ id: nextId(), name, price, rating, reviews, source: 'Newegg', url, inStock, imageUrl });
    });
    return products;
  } catch (err) { console.error('[Newegg]', err.message); return []; }
}
module.exports = { search };
