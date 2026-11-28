import { describe, expect, it } from "vitest";
import { isValidSource, normalizeSongKey, parseRecord, validateRecord, type ScoreRecord } from "../src/games/iidx";

const identity = (key: string) => key;

function record(overrides: Record<string, unknown> = {}): ScoreRecord {
  const parsed = parseRecord(
    { title: "Verflucht", playType: "SP", difficulty: "ANOTHER", clearType: "HARD CLEAR", exScore: 2500, pgreat: 1000, great: 500, missCount: 12, ...overrides },
    identity,
  );
  if (typeof parsed === "string") throw new Error(parsed);
  return parsed;
}

describe("normalizeSongKey", () => {
  it("folds width, case and whitespace", () => {
    expect(normalizeSongKey("Ｖｅｒｆｌｕｃｈｔ ")).toBe("verflucht");
    expect(normalizeSongKey("灼熱 Pt.2 Long Train Running")).toBe("灼熱pt.2longtrainrunning");
  });
});

describe("isValidSource", () => {
  it("accepts arcade versions and INFINITAS", () => {
    expect(isValidSource("arcade-33")).toBe(true);
    expect(isValidSource("infinitas")).toBe(true);
    expect(isValidSource("arcade-0")).toBe(false);
    expect(isValidSource("arcade-x")).toBe(false);
    expect(isValidSource("../index")).toBe(false);
  });
});

describe("parseRecord", () => {
  it("rejects unknown clear types and NO PLAY", () => {
    expect(parseRecord({ ...{ title: "a", playType: "SP", difficulty: "HYPER", exScore: 1 }, clearType: "NO PLAY" }, identity)).toBe("invalid_clear_type");
  });

  it("rejects negative or fractional counts", () => {
    expect(parseRecord({ title: "a", playType: "SP", difficulty: "HYPER", clearType: "CLEAR", exScore: -1 }, identity)).toBe("invalid_ex_score");
    expect(parseRecord({ title: "a", playType: "SP", difficulty: "HYPER", clearType: "CLEAR", exScore: 1, missCount: 1.5 }, identity)).toBe(
      "invalid_judgments",
    );
  });

  it("applies aliases", () => {
    const parsed = parseRecord({ title: "Old Title", playType: "DP", difficulty: "HYPER", clearType: "CLEAR", exScore: 10 }, () => "canonical");
    expect(typeof parsed !== "string" && parsed.songKey).toBe("canonical");
  });
});

describe("validateRecord", () => {
  it("accepts consistent records", () => {
    expect(validateRecord(record(), undefined)).toBeNull();
  });

  it("requires EX score to match judgments", () => {
    expect(validateRecord(record({ exScore: 2501 }), undefined)).toBe("ex_score_mismatch");
  });

  it("skips the EX check when judgments are unknown", () => {
    expect(validateRecord(record({ pgreat: 0, great: 0 }), undefined)).toBeNull();
    expect(validateRecord(record({ pgreat: null, great: null }), undefined)).toBeNull();
  });

  it("requires full combos to have no misses", () => {
    expect(validateRecord(record({ clearType: "FULLCOMBO CLEAR", missCount: 1 }), undefined)).toBe("full_combo_with_misses");
    expect(validateRecord(record({ clearType: "FULLCOMBO CLEAR", missCount: 0 }), undefined)).toBeNull();
  });

  it("enforces note caps from chart rules", () => {
    expect(validateRecord(record(), { maxNotes: 1200 })).toBe("ex_score_above_max");
    expect(validateRecord(record({ exScore: 2000, pgreat: 900, great: 200 }), { maxNotes: 1000 })).toBe("judgments_above_notes");
    expect(validateRecord(record(), { maxNotes: 2000 })).toBeNull();
  });
});
