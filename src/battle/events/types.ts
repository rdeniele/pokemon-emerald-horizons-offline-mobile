import type { Side, StatusKind } from "../types";

/** All times are battle-clock milliseconds (deterministic, independent of wall clock). */
interface Base {
  timestamp: number;
}

export type BattleEvent =
  | (Base & {type:"CLASH_RESOLVED";x:number;y:number;winner?:string;moveType?:import("@/pokemon/types/typeChart").PokemonType})
  | (Base & {type:"ATTACK_CLASH";x:number;y:number;sources:string[];attackIds:number[];duration?:number;kind?:"beam"|"sphere"|"melee"|"projectile"})
  | (Base & {type:"MOVE_ENDED";attackId:number})
  | (Base & {type:"POTION_PICKED_UP";unitId:string;x:number;y:number;amount:number})
  | (Base & {type:"MOVE_AIMED";source:string;fromX:number;fromY:number;x:number;y:number;delivery:"melee"|"ranged";moveType:import("@/pokemon/types/typeChart").PokemonType;travel:number;attackId?:number;behavior?:import("@/pokemon/moves/behavior").MoveBehavior;radius?:number;moveName?:string})
  | (Base & { type: "POKEMON_WITHDRAWN"; unitId: string; replacement: string })
  | (Base & { type: "POKEMON_DASHED"; unitId: string; fromX: number; fromY: number; x: number; y: number; dodge: boolean })
  | (Base & { type: "ATTACK_DODGED"; source: string; target: string })
  | (Base & { type: "POKEMON_SPAWNED"; unitId: string; side: Side; x: number; y: number })
  | (Base & { type: "POKEMON_MOVED"; unitId: string; x: number; y: number })
  | (Base & { type: "POKEMON_TARGETED"; source: string; target: string })
  | (Base & { type: "ATTACK_STARTED"; source: string; target: string; move: string; aimed?:boolean })
  | (Base & {
      type: "DAMAGE_DEALT";
      source: string;
      target: string;
      amount: number;
      effectiveness: number;
      move: string;
      targetHp: number;
    })
  | (Base & { type: "HEAL_APPLIED"; source: string; target: string; amount: number; targetHp: number })
  | (Base & { type: "SKILL_USED"; source: string; skillId: string; name: string; manual: boolean; aimed?:boolean })
  | (Base & { type: "STATUS_APPLIED"; target: string; status: StatusKind; duration: number })
  | (Base & { type: "POKEMON_FAINTED"; unitId: string; side: Side })
  | (Base & { type: "POKEMON_REPLACED"; fainted: string; replacement: string; side: Side })
  | (Base & { type: "POKEMON_CAPTURED"; unitId: string })
  | (Base & { type: "BATTLE_WON"; timeElapsed: number })
  | (Base & { type: "BATTLE_LOST"; timeElapsed: number; reason: "wiped" | "timeout" });

export type BattleEventType = BattleEvent["type"];
