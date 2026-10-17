import { test } from "node:test";
import assert from "node:assert/strict";
import { hasKnownPricing } from "../pricing.ts";

const zero = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

test("missing and zero rates remain unknown, not free", () => {
  assert.equal(hasKnownPricing(undefined), false);
  assert.equal(hasKnownPricing(zero), false);
  assert.equal(hasKnownPricing({ ...zero, tiers: [] }), false);
  assert.equal(hasKnownPricing({ ...zero, tiers: [{ ...zero, inputTokensAbove: 200000 }] }), false);
});

test("each base or tier rate can establish known pricing", () => {
  for (const key of ["input", "output", "cacheRead", "cacheWrite"] as const) {
    const rates = { ...zero, [key]: 1 };
    assert.equal(hasKnownPricing(rates), true, key);
    assert.equal(
      hasKnownPricing({
        ...zero,
        tiers: [
          { ...zero, inputTokensAbove: 100000 },
          { ...rates, inputTokensAbove: 200000 },
        ],
      }),
      true,
      key,
    );
  }
});
