import { emit, type BattleState } from "../engine/BattleState";
import type { BattleUnit, FormationSlot, Side, UnitSpec } from "../types";

export function createBattleUnit(spec: UnitSpec, side: Side, slot: { x: number; y: number }): BattleUnit {
  return {
    spec,
    side,
    x: slot.x,
    y: slot.y,
    hp: spec.stats.hp,
    maxHp: spec.stats.hp,
    alive: true,
    deployed: false,
    // small stagger so everyone doesn't fire on tick 0
    basicCooldown: 0.3,
    skillCooldowns: Object.fromEntries(
      spec.skills.map((s) => [s.id, s.slot === "ultimate" ? s.cooldown * 0.5 : s.cooldown * 0.3]),
    ),
    statuses: [],
    threat: 0,
    dotRemainder: 0,
    targetId: null,
    manualTargetId: null,
    slot: { ...slot },
  };
}

export function deploy(state: BattleState, unit: BattleUnit, slot: { x: number; y: number }): void {
  unit.deployed = true;
  unit.x = slot.x;
  unit.y = slot.y;
  unit.slot = { ...slot };
  emit(state, { type: "POKEMON_SPAWNED", unitId: unit.spec.id, side: unit.side, x: unit.x, y: unit.y });
}

/** Initial deployment: formation slots take the field (up to maxUnits); everyone else becomes a reserve. */
export function spawnSide(
  state: BattleState,
  side: Side,
  roster: UnitSpec[],
  formation: FormationSlot[],
  maxUnits: number,
): void {
  const placed = formation.slice(0, maxUnits);
  for (const spec of roster) {
    const slot = placed.find((f) => f.unitId === spec.id);
    const unit = createBattleUnit(spec, side, slot ?? { x: 0, y: 0 });
    state.units.set(spec.id, unit);
    state.order.push(spec.id);
    if (slot) deploy(state, unit, slot);
    else state.reserves[side].push(spec.id);
  }
}
