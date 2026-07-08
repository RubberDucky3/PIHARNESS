const axios = require('axios');
const cheerio = require('cheerio');

const USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

let idCounter = 0;

function nextId() {
  return 'amz-' + (++idCounter);
}

async function search(query) {
  try {
    const url = `https://www.amazon.com/s?k=${encodeURIComponent(query)}`;
    const { data: html } = await axios.get(url, {
      headers: {
        'User-Agent': USER_AGENT,
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
      timeout: 10000,
    });

    const $ = cheerio.load(html);
    const products = [];

    $('div[data-component-type="s-search-result"]').each((i, el) => {
      if (i >= 10) return false; // limit to 10 results

      const titleEl = $(el).find('h2 a span').first();
      const name = titleEl.text().trim();
      if (!name) return;

      // Price
      let price = 0;
      const priceWhole = $(el).find('.a-price-whole').first().text().replace(/[^0-9.]/g, '');
      const priceFraction = $(el).find('.a-price-fraction').first().text().replace(/[^0-9]/g, '');
      if (priceWhole) {
        price = parseFloat(priceWhole + '.' + (priceFraction || '0'));
      }
      if (!price) {
        const offscreenPrice = $(el).find('.a-price .a-offscreen').first().text().replace(/[^0-9.]/g, '');
        price = parseFloat(offscreenPrice) || 0;
      }

      // Rating
      let rating = 0;
      const ratingText = $(el).find('.a-icon-alt').first().text();
      const ratingMatch = ratingText.match(/([\d.]+)/);
      if (ratingMatch) rating = parseFloat(ratingMatch[1]);

      // Reviews
      let reviews = 0;
      const reviewsText = $(el).find('.a-size-base.s-underline-text').first().text().replace(/[^0-9]/g, '');
      if (reviewsText) reviews = parseInt(reviewsText, 10) || 0;
      if (!reviews) {
        const reviewCount = $(el).find('a[href*="customer-reviews"] span').last().text().replace(/[^0-9]/g, '');
        reviews = parseInt(reviewCount, 10) || 0;
      }

      // URL
      let url = '';
      const linkEl = $(el).find('h2 a').first();
      const href = linkEl.attr('href');
      if (href) {
        url = href.startsWith('http') ? href : 'https://www.amazon.com' + href;
      }

      // Image
      let imageUrl = '';
      const imgEl = $(el).find('.s-image').first();
      if (imgEl.length) imageUrl = imgEl.attr('src') || '';

      // In stock check
      const outOfStockText = $(el).text().toLowerCase();
      const inStock = !outOfStockText.includes('currently unavailable') && !outOfStockText.includes('out of stock');

      products.push({
        id: nextId(),
        name,
        price,
        rating,
        reviews,
        source: 'Amazon',
        url,
        inStock,
        imageUrl,
      });
    });

    return products;
  } catch (err) {
    console.error('[Amazon scraper] Error:', err.message);
    return [];
  }
}

module.exports = { search };
