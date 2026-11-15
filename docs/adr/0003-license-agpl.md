# ADR 0003: License under AGPL-3.0

- Status: Accepted
- Date: 2026-11-13

## Decision
Corpus is licensed under the GNU Affero General Public License v3.0 (`LICENSE`).

## Rationale
For a privacy-focused health tool, anyone who modifies Corpus and runs it as a service (e.g. a hosted sync relay) must publish their changes. This keeps derivatives auditable.

## Consequences
- Every dependency must be AGPL-compatible. MIT, BSD and Apache-2.0 are fine.
- Bundled datasets (e.g. food databases) need licenses checked separately. Open Food Facts is ODbL; USDA FoodData Central is public domain.
