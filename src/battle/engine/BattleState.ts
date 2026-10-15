import type { BattleEvent } from "../events/types";
import type { AutoConfig, BattleUnit, GridConfig, Side } from "../types";
import type { Rng } from "./rng";

export type BattleResult = null | { winner: Side; reason: "wiped" | "timeout" };

export interface BattleState {
  potions?: {id:number;x:number;y:number;expires:number}[];
  nextPotionAt?:number;
  arena?: boolean;
  arenaId?: string;
  obstacles?: import("../field").Obstacle[];
  grid: GridConfig;
  /** battle clock in ms */
  time: number;
  units: Map<string, BattleUnit>;
  /** insertion order => deterministic iteration */
  order: string[];
  /** undeployed unit ids waiting to replace fainted units, in priority order */
  reserves: Record<Side, string[]>;
  maxUnits: Record<Side, number>;
  events: BattleEvent[];
  rng: Rng;
  auto: Record<Side, AutoConfig>;
  timeLimit: number;
  result: BattleResult;
}

type DistributiveOmit<T, K extends keyof never> = T extends unknown ? Omit<T, K> : never;

export function emit(state: BattleState, e: DistributiveOmit<BattleEvent, "timestamp">): void {
  state.events.push({ ...e, timestamp: state.time } as BattleEvent);
}

export function unitsOf(state: BattleState, side: Side, opts: { aliveOnly?: boolean } = {}): BattleUnit[] {
  const out: BattleUnit[] = [];
  for (const id of state.order) {
    const u = state.units.get(id)!;
    if (u.side !== side || !u.deployed) continue;
    if (opts.aliveOnly !== false && !u.alive) continue;
    out.push(u);
  }
  return out;
}

export const opposite = (s: Side): Side => (s === "player" ? "enemy" : "player");

export const dist = (a: { x: number; y: number }, b: { x: number; y: number }) =>
  Math.hypot(a.x - b.x, a.y - b.y);
