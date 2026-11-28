import { describe, expect, it } from "vitest";
import { mergeSmallBuckets } from "../src/snapshots";

describe("mergeSmallBuckets", () => {
  it("folds small buckets downward so no published bucket has fewer than 3 players", () => {
    expect(mergeSmallBuckets([[100, 4], [110, 2], [120, 1], [130, 1]])).toEqual([[100, 4], [110, 4]]);
    expect(mergeSmallBuckets([[100, 5], [200, 3]])).toEqual([[100, 5], [200, 3]]);
  });

  it("merges a small remainder at the bottom into the lowest bucket", () => {
    expect(mergeSmallBuckets([[50, 1], [100, 5], [200, 4]])).toEqual([[50, 6], [200, 4]]);
  });

  it("keeps the total count", () => {
    const buckets: [number, number][] = [[0, 1], [10, 2], [20, 1], [30, 1], [40, 1], [50, 4], [60, 1]];
    const merged = mergeSmallBuckets(buckets);
    expect(merged.reduce((sum, [, n]) => sum + n, 0)).toBe(11);
    expect(merged.every(([, n]) => n >= 3)).toBe(true);
  });
});
