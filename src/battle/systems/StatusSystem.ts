import { emit, type BattleState } from "../engine/BattleState";
import type { BattleUnit, StatusApplication, StatusKind } from "../types";

export const BURN_DPS = 0.04; // fraction of max HP per second
export const POISON_DPS = 0.03;

export function hasStatus(u: BattleUnit, kind: StatusKind): boolean {
  return u.statuses.some((s) => s.kind === kind);
}

/** Paralysis halves movement and attack speed. */
export const speedMultiplier = (u: BattleUnit, at=Infinity): number =>
  (hasStatus(u,"sleep")||hasStatus(u,"root")?0:hasStatus(u,"paralysis") ? 0.5 : hasStatus(u,"slow")?.65:1)*(u.buff?.kind==="speed"&&at<u.buff.until?1.45:1);

export function applyStatus(state: BattleState, target: BattleUnit, app: StatusApplication): void {
  if (!target.alive) return;
  if (state.rng.next() > app.chance) return;
  const existing = target.statuses.find((s) => s.kind === app.kind);
  if (existing) existing.remaining = Math.max(existing.remaining, app.duration);
  else target.statuses.push({ kind: app.kind, remaining: app.duration });
  emit(state, { type: "STATUS_APPLIED", target: target.spec.id, status: app.kind, duration: app.duration });
}

/** Ticks durations; returns damage-over-time for this tick (caller applies it via CombatSystem). */
export function tickStatuses(u: BattleUnit, dt: number): number {
  let dot = 0;
  for (const s of u.statuses) {
    if (s.kind === "burn") dot += u.maxHp * BURN_DPS * dt;
    if (s.kind === "poison") dot += u.maxHp * POISON_DPS * dt;
    s.remaining -= dt;
  }
  u.statuses = u.statuses.filter((s) => s.remaining > 0);
  return dot;
}
