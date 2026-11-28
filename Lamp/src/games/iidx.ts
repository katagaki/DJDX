export const PLAY_TYPES = ["SP", "DP"] as const;
export const DIFFICULTIES = ["BEGINNER", "NORMAL", "HYPER", "ANOTHER", "LEGGENDARIA"] as const;

export const LAMPS: Record<string, number> = {
  FAILED: 1,
  "ASSIST CLEAR": 2,
  "EASY CLEAR": 3,
  CLEAR: 4,
  "HARD CLEAR": 5,
  "EX HARD CLEAR": 6,
  "FULLCOMBO CLEAR": 7,
};

export const LAMP_COUNT = 7;
export const LAMP_FULL_COMBO = 7;

const MAX_EX_SCORE = 2 * 5000;
const MAX_ARCADE_VERSION = 60;

export interface ScoreRecord {
  songKey: string;
  playType: string;
  difficulty: string;
  lamp: number;
  exScore: number;
  pgreat: number | null;
  great: number | null;
  missCount: number | null;
}

export interface ChartRule {
  maxNotes: number | null;
}

export function normalizeSongKey(title: string): string {
  return title.normalize("NFKC").toLowerCase().replace(/\s+/gu, "");
}

export function isValidSource(source: unknown): source is string {
  if (source === "infinitas") return true;
  if (typeof source !== "string") return false;
  const match = source.match(/^arcade-(\d{1,2})$/);
  return !!match && Number(match[1]) >= 1 && Number(match[1]) <= MAX_ARCADE_VERSION;
}

export function chartRuleKey(songKey: string, playType: string, difficulty: string): string {
  return `${songKey}\u0000${playType}\u0000${difficulty}`;
}

function isCount(value: unknown, max: number): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= max;
}

function optionalCount(value: unknown, max: number): number | null | undefined {
  if (value === undefined || value === null) return null;
  return isCount(value, max) ? value : undefined;
}

export function parseRecord(input: unknown, songKeyFor: (title: string) => string): ScoreRecord | string {
  if (!input || typeof input !== "object") return "not_an_object";
  const record = input as Record<string, unknown>;
  if (typeof record.title !== "string" || record.title.trim().length === 0 || record.title.length > 200) return "invalid_title";
  const songKey = songKeyFor(normalizeSongKey(record.title));
  if (songKey.length === 0) return "invalid_title";
  if (!PLAY_TYPES.includes(record.playType as (typeof PLAY_TYPES)[number])) return "invalid_play_type";
  if (!DIFFICULTIES.includes(record.difficulty as (typeof DIFFICULTIES)[number])) return "invalid_difficulty";
  const lamp = typeof record.clearType === "string" ? LAMPS[record.clearType] : undefined;
  if (!lamp) return "invalid_clear_type";
  if (!isCount(record.exScore, MAX_EX_SCORE)) return "invalid_ex_score";
  const pgreat = optionalCount(record.pgreat, MAX_EX_SCORE);
  const great = optionalCount(record.great, MAX_EX_SCORE);
  const missCount = optionalCount(record.missCount, MAX_EX_SCORE);
  if (pgreat === undefined || great === undefined || missCount === undefined) return "invalid_judgments";
  return {
    songKey,
    playType: record.playType as string,
    difficulty: record.difficulty as string,
    lamp,
    exScore: record.exScore,
    pgreat,
    great,
    missCount,
  };
}

export function validateRecord(record: ScoreRecord, rule: ChartRule | undefined): string | null {
  const judgmentsKnown = record.pgreat !== null && record.great !== null && record.pgreat + record.great > 0;
  if (judgmentsKnown && record.exScore !== 2 * record.pgreat! + record.great!) return "ex_score_mismatch";
  if (record.lamp === LAMP_FULL_COMBO && record.missCount !== null && record.missCount !== 0) return "full_combo_with_misses";
  if (rule?.maxNotes) {
    if (record.exScore > 2 * rule.maxNotes) return "ex_score_above_max";
    if (judgmentsKnown && record.pgreat! + record.great! > rule.maxNotes) return "judgments_above_notes";
    if (record.missCount !== null && record.missCount > rule.maxNotes) return "miss_count_above_notes";
  }
  return null;
}
