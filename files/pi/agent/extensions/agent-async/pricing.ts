import type { ModelCost, ModelCostRates } from "@earendil-works/pi-ai";

/** Thresholds select a tier; only actual rates establish known pricing. */
export function hasKnownPricing(cost: ModelCost | undefined): boolean {
  const hasPositiveRate = (rates: ModelCostRates) =>
    [rates.input, rates.output, rates.cacheRead, rates.cacheWrite].some((v) => v > 0);
  return !!cost && (hasPositiveRate(cost) || (cost.tiers ?? []).some(hasPositiveRate));
}
