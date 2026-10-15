import {blockedLine} from "../field";
import { dist, emit, type BattleState } from "../engine/BattleState";
import { totalRows, type BattleUnit } from "../types";
import { speedMultiplier } from "./StatusSystem";

const MIN_SEPARATION = 0.75;
const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

function blocked(state: BattleState, self: BattleUnit, x: number, y: number): boolean {
  if(blockedLine(state.obstacles,self,{x,y},.32))return true;
  for (const id of state.order) {
    const o = state.units.get(id)!;
    if (o === self || !o.alive || !o.deployed) continue;
    const d = dist(o, { x, y });
    // only block if the move brings us closer than we already are
    if (d < MIN_SEPARATION && d < dist(o, self)) return true;
  }
  return false;
}

/** Move `self` toward `target` by speed*dt cells; sidestep when blocked. Stops at `stopDistance`. */
export function moveToward(state: BattleState, self: BattleUnit, target: BattleUnit, dt: number, stopDistance: number): void {
  const d = dist(self, target);
  if (d <= stopDistance) return;
  const step = Math.min(self.spec.movementSpeed * speedMultiplier(self,state.time) * dt, d - stopDistance);
  const dx = (target.x - self.x) / d;
  const dy = (target.y - self.y) / d;
  const maxY = totalRows(state.grid) - 1;
  const candidates: [number, number][] = [
    [dx, dy],
    [-dy, dx],
    [dy, -dx],
  ];
  for (const [cx, cy] of candidates) {
    const nx = clamp(self.x + cx * step, 0, state.grid.cols - 1);
    const ny = clamp(self.y + cy * step, 0, maxY);
    if (!blocked(state, self, nx, ny)) {
      if (nx !== self.x || ny !== self.y) {
        self.x = nx;
        self.y = ny;
        emit(state, { type: "POKEMON_MOVED", unitId: self.spec.id, x: nx, y: ny });
      }
      return;
    }
  }
}
