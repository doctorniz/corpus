# ADR 0006: Bundle USDA SR Legacy as the offline food database

- Status: Accepted
- Date: 2026-11-17

## Decision
Ship USDA FoodData Central "SR Legacy" (April 2018; 7,793 foods) inside the app as `assets/foods.bin`, about 210 KB compressed. It holds energy, protein, carbohydrate, fat, fibre, sugar and sodium per 100 g, plus one typical serving per food.

## Rationale
- Public domain, so compatible with AGPL and app-store distribution.
- Small enough that food search stays fully offline at negligible app-size cost.

## Consequences
- Generic foods only: no branded products and no barcodes. USDA's branded dataset is hundreds of MB; Open Food Facts would need the network or a large download and is ODbL-licensed.
- US naming ("Bananas, raw") and US-centric foods. Users can add their own foods, and quick add needs no food at all.
- SR Legacy is no longer updated. Rebuild with `tool/build_foods.dart` if a better source is chosen, and bump `bundledFoodsVersion`.
