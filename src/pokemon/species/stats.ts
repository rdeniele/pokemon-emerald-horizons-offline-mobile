import type { BaseStats } from "@/battle/types";

/** Gen-3 stat formula with fixed IV 15 / EV 0 (no natures yet). */
export function computeStats(base: BaseStats, level: number): BaseStats {
  const core = (b: number) => Math.floor(((2 * b + 15) * level) / 100) + 5;
  return {
    hp: Math.floor(((2 * base.hp + 15) * level) / 100) + level + 10,
    atk: core(base.atk),
    def: core(base.def),
    spa: core(base.spa),
    spd: core(base.spd),
    spe: core(base.spe),
  };
}

export const MAX_LEVEL = 100;

/** Medium-fast growth: total EXP to *reach* a level. */
export const expForLevel = (level: number): number => level ** 3;

export function levelForExp(exp: number): number {
  let l = 1;
  while (l < MAX_LEVEL && expForLevel(l + 1) <= exp) l++;
  return l;
}

/** EXP awarded for defeating a wild Pokémon (mainline-style, no trainer bonus). */
export const expYield = (baseExp: number, enemyLevel: number): number =>
  Math.max(1, Math.floor((baseExp * enemyLevel) / 7));
