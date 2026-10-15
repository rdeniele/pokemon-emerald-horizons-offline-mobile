import { emit, type BattleState } from "../engine/BattleState";
import type { BattleUnit } from "../types";
import { deploy } from "./SpawnSystem";

/** When a deployed unit faints, the next reserve takes its slot. The battle keeps running. */
export function replaceFainted(state: BattleState, fainted: BattleUnit): void {
  const next = state.reserves[fainted.side].shift();
  if (!next) return;
  const unit = state.units.get(next)!;
  deploy(state, unit, fainted.slot);
  emit(state, { type: "POKEMON_REPLACED", fainted: fainted.spec.id, replacement: unit.spec.id, side: fainted.side });
}
