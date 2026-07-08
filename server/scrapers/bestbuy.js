const axios = require('axios');
const cheerio = require('cheerio');
const USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
let idCounter = 0;
function nextId() { return 'bb-' + (++idCounter); }
async function search(query) {
  try {
    const url = 'https://www.bestbuy.com/site/searchpage.jsp?st=' + encodeURIComponent(query);
    const { data: html } = await axios.get(url, { headers: { 'User-Agent': USER_AGENT, 'Accept-Language': 'en-US' }, timeout: 10000 });
    const $ = cheerio.load(html);
    const products = [];
    $('.sku-item, .list-item').each((i, el) => {
      if (i >= 10) return false;
      const $el = $(el);
      const name = $el.find('.sku-title a, .sku-header a, h4.sku-header').first().text().trim();
      if (!name) return;
      let price = 0;
      const priceText = $el.find('.priceView-customer-price span, .price-view, .price').first().text().replace(/[^0-9.]/g, '');
      price = parseFloat(priceText) || 0;
      let rating = 0;
      const ratingText = $el.find('.ratings-reviews .sr-only, .c-ratings-reviews').first().text();
      const m = ratingText.match(/([\d.]+)/);
      if (m) rating = parseFloat(m[1]);
      let reviews = 0;
      const revText = $el.find('.c-reviews-count, .reviews-count').first().text().replace(/[^0-9]/g, '');
      reviews = parseInt(revText, 10) || 0;
      let url = '';
      const href = $el.find('.sku-title a, .sku-header a').first().attr('href');
      if (href) url = href.startsWith('http') ? href : 'https://www.bestbuy.com' + href;
      let imageUrl = $el.find('.sku-image img, .primary-image img, img.sku-image').first().attr('src') || '';
      const inStock = !$el.text().toLowerCase().includes('sold out');
      products.push({ id: nextId(), name, price, rating, reviews, source: 'Best Buy', url, inStock, imageUrl });
    });
    return products;
  } catch (err) { console.error('[BestBuy]', err.message); return []; }
}
module.exports = { search };
