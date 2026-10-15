import { dist, opposite, unitsOf, type BattleState } from "../engine/BattleState";
import type { BattleUnit, TargetStrategy } from "../types";

/** Pick a target for `self` using `strategy`. Strategy-specific, never hardcoded in the combat loop. */
export function selectTarget(state: BattleState, self: BattleUnit, strategy: TargetStrategy): BattleUnit | null {
  if (strategy === "lowestHPAlly") {
    return minBy(unitsOf(state, self.side), (u) => u.hp / u.maxHp, self);
  }
  const foes = unitsOf(state, opposite(self.side));
  if (foes.length === 0) return null;
  switch (strategy) {
    case "lowestHP":
      return minBy(foes, (u) => u.hp, self);
    case "highestThreat":
      return minBy(foes, (u) => -u.threat, self);
    case "lowestDefense":
      return minBy(foes, (u) => Math.min(u.spec.stats.def, u.spec.stats.spd), self);
    case "random":
      return state.rng.pick(foes);
    case "manual": {
      const m = self.manualTargetId ? state.units.get(self.manualTargetId) : undefined;
      if (m && m.alive && m.deployed) return m;
      return minBy(foes, (u) => dist(u, self), self);
    }
    case "nearest":
    default:
      return minBy(foes, (u) => dist(u, self), self);
  }
}

/** Stable min: ties broken by distance to self, then id, so results are deterministic. */
function minBy(list: BattleUnit[], score: (u: BattleUnit) => number, self: BattleUnit): BattleUnit | null {
  let best: BattleUnit | null = null;
  let bs = Infinity;
  for (const u of list) {
    const s = score(u);
    if (
      s < bs ||
      (s === bs &&
        best &&
        (dist(u, self) < dist(best, self) || (dist(u, self) === dist(best, self) && u.spec.id < best.spec.id)))
    ) {
      best = u;
      bs = s;
    }
  }
  return best;
}
