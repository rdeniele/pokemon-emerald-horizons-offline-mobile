import {blockedLine} from "../field";
import { dist, emit, type BattleState } from "../engine/BattleState";
import { totalRows, type BattleUnit } from "../types";
import { hasStatus, speedMultiplier } from "./StatusSystem";
export const DODGE_COOLDOWN_MS = 1200;

/** Shared AI/trainer dash. Positions remain continuous, bounded and collision checked. */
export function arenaDash(s: BattleState, u: BattleUnit, target: BattleUnit, dodge: boolean, range = u.spec.attackRange): boolean {
  if (!s.arena || !u.alive || !u.deployed || (hasStatus(u, "stun")||hasStatus(u,"sleep")||hasStatus(u,"root")||!!u.travelMove) || s.time < (u.dashReadyAt ?? 0)) return false;
  const d = dist(u, target) || 1;
  const dx = (target.x - u.x) / d, dy = (target.y - u.y) / d;
  const turn = s.rng.next() < 0.5 ? 1 : -1;
  const length = (dodge ? 1.6 : Math.min(2.2, Math.max(0, d - range * 0.8))) * speedMultiplier(u,s.time);
  const fromX = u.x, fromY = u.y;
  // Try both sides when a wall or another combatant blocks the preferred direction.
  for (const sign of [turn, -turn]) {
    const x = Math.max(0, Math.min(s.grid.cols - 1, u.x + (dodge ? -dy * sign : dx) * length));
    const y = Math.max(0, Math.min(totalRows(s.grid) - 1, u.y + (dodge ? dx * sign : dy) * length));
    if (Math.hypot(x - fromX, y - fromY) < 0.3) continue;
    if (blockedLine(s.obstacles,u,{x,y},.32))continue;
    if ([...s.units.values()].some(v => v !== u && v.alive && v.deployed && dist(v, {x, y}) < 0.75)) continue;
    u.x = x; u.y = y;
    u.dashReadyAt = s.time + DODGE_COOLDOWN_MS;
    if (dodge) u.dodgeUntil = s.time + 300;
    emit(s, {type: "POKEMON_DASHED", unitId: u.spec.id, fromX, fromY, x, y, dodge});
    return true;
  }
  return false;
}

/** Keep moving between exchanges instead of planting in attack range. */
export function circleTarget(s: BattleState, u: BattleUnit, target: BattleUnit, dt: number): void {
  const d = dist(u, target) || 1;
  const direction = s.order.indexOf(u.spec.id) % 2 ? 1 : -1;
  const step = u.spec.movementSpeed * speedMultiplier(u,s.time) * dt * 0.75;
  const x = Math.max(0, Math.min(s.grid.cols - 1, u.x - (target.y - u.y) / d * step * direction));
  const y = Math.max(0, Math.min(totalRows(s.grid) - 1, u.y + (target.x - u.x) / d * step * direction));
  if (blockedLine(s.obstacles,u,{x,y},.32))return;
  if ([...s.units.values()].some(v => v !== u && v.alive && v.deployed && dist(v, {x, y}) < 0.75)) return;
  u.x = x; u.y = y;
  emit(s, {type: "POKEMON_MOVED", unitId: u.spec.id, x, y});
}

/** Create space for a ranged follow-up; blocked retreats still allow the move to fire. */
export function retreatFrom(s: BattleState, u: BattleUnit, target: BattleUnit, dt: number): boolean {
  const d = dist(u, target) || 1;
  const step = u.spec.movementSpeed * speedMultiplier(u,s.time) * dt * 1.2;
  const x = Math.max(0, Math.min(s.grid.cols - 1, u.x + (u.x - target.x) / d * step));
  const y = Math.max(0, Math.min(totalRows(s.grid) - 1, u.y + (u.y - target.y) / d * step));
  if (blockedLine(s.obstacles,u,{x,y},.32) || Math.hypot(x - u.x, y - u.y) < 0.001 || [...s.units.values()].some(v => v !== u && v.alive && v.deployed && dist(v, {x, y}) < 0.75)) return false;
  u.x = x; u.y = y;
  emit(s, {type: "POKEMON_MOVED", unitId: u.spec.id, x, y});
  return true;
}
