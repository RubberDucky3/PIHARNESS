# Plan: Product Finder Webpage — Multi-Agent Build

## Requirements Summary

A single-file `product-finder.html` webpage that:
- Lets users search for electronics/tech products
- Simulates scraping 3 sources: Amazon, Best Buy, Newegg
- Displays ranked results scored on: lowest price, highest rating, best value, most reviews
- Shows which product is "best" with clear badges and visual scoring
- Demonstrates the PIHARNESS multi-agent pattern (3 implementers → 1 reviewer)

## Acceptance Criteria

- [ ] Search input accepts any electronics query (e.g. "RTX 4090", "MacBook Pro")
- [ ] 3 "source agents" each return 3–5 mock products with: name, price, rating (0–5), review count, source
- [ ] Ranking engine scores every product on 4 criteria: price rank, rating rank, value score (rating/price×1000), review count rank
- [ ] Combined score surfaces a single "BEST PICK" badge on the top result
- [ ] Results display in a grid with source badges (Amazon/Best Buy/Newegg colored)
- [ ] Agent status panel shows each worker's label + "done" status (simulated in UI)
- [ ] Page is self-contained — no external dependencies except CDN (Tailwind or similar)
- [ ] File saved as `product-finder.html` in repo root

## Architecture (3:1 Worker Ratio)

```
Worker 1 (implementer) — mock-data module
  → JS object: generateAmazonProducts(query), generateBestBuyProducts(query), generateNeweggProducts(query)
  → Each returns array of {name, price, rating, reviews, url, source}

Worker 2 (implementer) — ranking engine
  → scoreProducts(allProducts) → sorted array with combinedScore + badge labels
  → Criteria weights: price (25%), rating (25%), value (25%), reviews (25%)

Worker 3 (implementer) — frontend UI
  → HTML/CSS layout: search bar, agent status panel, results grid with cards
  → Card shows: product name, source badge, price, stars, review count, score bar
  → "BEST PICK" highlighted card at top

Worker 4 (reviewer) — integration
  → Receives all 3 outputs
  → Merges into single product-finder.html
  → Verifies all criteria pass
  → Fixes any integration issues
```

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Workers produce incompatible JS interfaces | Reviewer gets all 3 outputs + explicit interface contract |
| Mock data is too generic | Worker 1 prompt includes query-aware product name generation |
| UI looks rough | Worker 3 uses Tailwind CDN for polish |
| Integration fails | Reviewer is Claude fallback (highest quality) |

## Verification Steps

1. Open `product-finder.html` in browser — no console errors
2. Type "RTX 4090" → results appear from all 3 sources
3. "BEST PICK" badge is visible on top result
4. Scores vary meaningfully between products
5. Source badges show correct colors (Amazon=orange, Best Buy=blue, Newegg=red)

## Changelog
- Initial plan created 2026-07-07
