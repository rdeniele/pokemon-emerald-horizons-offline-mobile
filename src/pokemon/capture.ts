import type { Rng } from "@/battle/engine/rng";
import type { StatusKind } from "@/battle/types";

/** Ball upgrades: the better the ball, the better the odds. */
export type BallType = "pokeball" | "greatball" | "ultraball";
export const BALL_TYPES: BallType[] = ["pokeball", "greatball", "ultraball"];

export const BALLS: Record<BallType, { name: string; bonus: number; color: number }> = {
  pokeball: { name: "Poké Ball", bonus: 1, color: 0xff3b3b },
  greatball: { name: "Great Ball", bonus: 1.5, color: 0x3b82f6 },
  ultraball: { name: "Ultra Ball", bonus: 2, color: 0xf5c518 },
};

export interface CaptureInput {
  maxHp: number;
  currentHp: number;
  /** species catch rate 0..255 (255 = common and easy, 3 = legendary) */
  catchRate: number;
  ball?: BallType;
  /** statuses currently on the target */
  statuses?: StatusKind[];
}

/** Sleep/freeze-like effects help the most, burns/poison/paralysis a little (Gen 3: x2 / x1.5). */
export function statusBonus(statuses: readonly StatusKind[] = []): number {
  if (statuses.includes("stun")) return 2;
  return statuses.length ? 1.5 : 1;
}

/**
 * Gen 3 modified catch rate `a` (1..255): rises as HP drops, with a better ball, and with a status effect.
 * a = ((3*maxHP - 2*HP) * rate * ball) / (3*maxHP) * status
 */
export function catchValue(i: CaptureInput): number {
  const ball = BALLS[i.ball ?? "pokeball"].bonus;
  const raw = Math.floor(((3 * i.maxHp - 2 * i.currentHp) * i.catchRate * ball) / (3 * i.maxHp)) * statusBonus(i.statuses);
  return Math.max(1, Math.min(255, Math.floor(raw)));
}

/** Probability (0..65535) that ONE of the four shake checks passes. */
export function shakeThreshold(a: number): number {
  if (a >= 255) return 65536;
  return Math.floor(1048560 / Math.floor(Math.sqrt(Math.floor(Math.sqrt(Math.floor(16711680 / a))))));
}

/**
 * Chance that a single throw catches the Pokémon: the ball must survive four shake checks in a row, which is
 * what makes full-health wild Pokémon hard to catch (a common Zigzagoon at full HP is roughly 1 in 3).
 */
export function catchProbability(i: CaptureInput): number {
  const a = catchValue(i);
  if (a >= 255) return 1;
  return (shakeThreshold(a) / 65536) ** 4;
}

export interface CaptureResult {
  success: boolean;
  /** one-throw success chance, for display */
  probability: number;
  /** how many times the ball wobbled before the result (3 on success, 0..3 when it breaks free) */
  shakes: number;
}

export function attemptCapture(i: CaptureInput, rng: Rng): CaptureResult {
  const a = catchValue(i);
  const probability = catchProbability(i);
  if (a >= 255) return { success: true, probability: 1, shakes: 3 };
  const b = shakeThreshold(a);
  let shakes = 0;
  for (let n = 0; n < 4; n++) {
    if (rng.next() * 65536 >= b) return { success: false, probability, shakes };
    if (n < 3) shakes++;
  }
  return { success: true, probability, shakes: 3 };
}
