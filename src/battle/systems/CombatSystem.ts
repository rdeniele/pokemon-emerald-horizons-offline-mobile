import {blockedLine} from "../field";
import { emit, type BattleState } from "../engine/BattleState";
import { typeEffectiveness, type PokemonType } from "@/pokemon/types/typeChart";
import { totalRows, type BattleUnit, type MoveCategory } from "../types";

export interface DamageInput {
  level: number;
  attack: number;
  defense: number;
  power: number;
  moveType: PokemonType;
  attackerTypes: readonly PokemonType[];
  defenderTypes: readonly PokemonType[];
  /** 0.85..1 random roll; injectable for tests */
  roll: number;
}

/** Gen-3-style damage formula. Pure. Integer >= 1 unless the target is immune (0). */
export function calcDamage(i: DamageInput): { amount: number; effectiveness: number } {
  const effectiveness = typeEffectiveness(i.moveType, i.defenderTypes);
  if (effectiveness === 0) return { amount: 0, effectiveness };
  const stab = i.attackerTypes.includes(i.moveType) ? 1.5 : 1;
  const base =
    Math.floor((Math.floor((2 * i.level) / 5 + 2) * i.power * i.attack) / Math.max(1, i.defense) / 50) + 2;
  const amount = Math.max(1, Math.floor(base * stab * effectiveness * i.roll));
  return { amount, effectiveness };
}

type MoveLike = { name: string; type: PokemonType; category: MoveCategory; power: number };

export function dealDamage(state: BattleState, source: BattleUnit, target: BattleUnit, move: MoveLike, origin:{x:number;y:number}=source,scale=1,knockbackScale=1): number {
  if(blockedLine(state.obstacles,origin,target))return 0;
  if(target.travelMove&&state.time<target.travelMove.until)return 0;
  if (state.arena && state.time < (target.dodgeUntil ?? 0)) {
    emit(state, {type: "ATTACK_DODGED", source: source.spec.id, target: target.spec.id});
    return 0;
  }
  const phys = move.category === "physical";
  const { amount: baseAmount, effectiveness } = calcDamage({
    level: source.spec.level,
    attack: (phys ? source.spec.stats.atk : source.spec.stats.spa)*(source.buff?.kind==="attack"&&state.time<source.buff.until?1.3:1),
    defense: (phys ? target.spec.stats.def : target.spec.stats.spd)*(target.buff?.kind==="defense"&&state.time<target.buff.until?1.4:1),
    power: move.power,
    moveType: move.type,
    attackerTypes: source.spec.types,
    defenderTypes: target.spec.types,
    roll: state.rng.range(0.85, 1),
  });
  const amount = baseAmount === 0 ? 0 : Math.max(1, Math.floor(baseAmount * (source.spec.damageDealtMultiplier ?? 1)*scale));
  applyDamage(state, source, target, amount, effectiveness, move.name);
  if (state.arena && amount > 0 && target.alive) {
    const distance = Math.hypot(target.x - source.x, target.y - source.y) || 1;
    const push = (move.power >= 80 ? 0.65 : 0.25)*knockbackScale;
    const x = Math.max(0, Math.min(state.grid.cols - 1, target.x + (target.x - source.x) / distance * push));
    const y = Math.max(0, Math.min(totalRows(state.grid) - 1, target.y + (target.y - source.y) / distance * push));
    if (!blockedLine(state.obstacles,target,{x,y},.32) && ![...state.units.values()].some(v => v !== target && v.alive && v.deployed && Math.hypot(v.x - x, v.y - y) < 0.75)) {
      target.x = x; target.y = y;
      emit(state, {type: "POKEMON_MOVED", unitId: target.spec.id, x, y});
    }
  }
  return amount;
}

export function applyDamage(
  state: BattleState,
  source: BattleUnit | null,
  target: BattleUnit,
  amount: number,
  effectiveness: number,
  moveName: string,
): void {
  if (!target.alive) return;
  if(amount>0&&source)target.statuses=target.statuses.filter(s=>s.kind!=="sleep");
  target.hp = Math.max(0, target.hp - amount);
  if (source) source.threat += amount;
  emit(state, {
    type: "DAMAGE_DEALT",
    source: source?.spec.id ?? "status",
    target: target.spec.id,
    amount,
    effectiveness,
    move: moveName,
    targetHp: target.hp,
  });
  if (target.hp <= 0) {
    target.alive = false;
    emit(state, { type: "POKEMON_FAINTED", unitId: target.spec.id, side: target.side });
  }
}

export function heal(state: BattleState, source: BattleUnit, target: BattleUnit, amount: number): void {
  if (!target.alive) return;
  const real = Math.min(amount, target.maxHp - target.hp);
  target.hp += real;
  emit(state, { type: "HEAL_APPLIED", source: source.spec.id, target: target.spec.id, amount: real, targetHp: target.hp });
}
