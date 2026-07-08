const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const searchHandler = require('./routes/search');
const app = express();

app.use(cors());
app.use(express.json());

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(limiter);

app.get('/api/search', searchHandler);
app.get('/api/product/:id', searchHandler);

app.use((err, req, res, next) => {
  console.error('[Error]', err);
  res.status(err.status || 500).json({ error: err.message || 'Internal server error', status: err.status || 500 });
});

const PORT = 3001;
app.listen(PORT, () => console.log('Product Finder API running on http://localhost:' + PORT));
