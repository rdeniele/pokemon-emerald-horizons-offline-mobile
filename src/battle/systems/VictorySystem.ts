import { emit, unitsOf, type BattleState } from "../engine/BattleState";
import type { Side } from "../types";

/** Sets state.result when a side has no living deployed units and no reserves (or the clock runs out). */
export function checkVictory(state: BattleState): void {
  if (state.result) return;
  const remaining = (s: Side) => unitsOf(state, s).length + state.reserves[s].length;
  const p = remaining("player");
  const e = remaining("enemy");
  if (p === 0) {
    state.result = { winner: "enemy", reason: "wiped" };
    emit(state, { type: "BATTLE_LOST", timeElapsed: state.time, reason: "wiped" });
  } else if (e === 0) {
    state.result = { winner: "player", reason: "wiped" };
    emit(state, { type: "BATTLE_WON", timeElapsed: state.time });
  } else if (state.time >= state.timeLimit * 1000) {
    state.result = { winner: "enemy", reason: "timeout" };
    emit(state, { type: "BATTLE_LOST", timeElapsed: state.time, reason: "timeout" });
  }
}
