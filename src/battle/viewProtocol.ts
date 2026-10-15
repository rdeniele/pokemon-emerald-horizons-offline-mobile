import type {BattleUnit, Side} from "@/battle/types";
import type {BattleEvent} from "@/battle/events/types";
export interface ArenaSnapshot {
  arenaId?:string;
  potions?:import("@/battle/engine/BattleState").BattleState["potions"];
  tick:number; time:number; units:BattleUnit[]; events:BattleEvent[];
  result: {winner:Side; reason:string}|null;
}
export interface FriendRoomState {code:string;host:string;ranked:boolean;arenaId?:string;you:string;members:{id:string;name:string;x:number;y:number}[];challenge:{from:string;to:string}|null;fight:{a:string;b:string}|null}
export type ServerMessage =
  | {type:"room"; room:FriendRoomState}
  | {type:"watch"; id:string; snapshot:ArenaSnapshot}
  | {type:"roomResult"; winner:string; reason:string}

  | {type:"queued"; mmr:number; rank:string}
  | {type:"match"; id:string; side:Side; opponent:string; snapshot:ArenaSnapshot}
  | {type:"state"; snapshot:ArenaSnapshot}
  | {type:"result"; winner:Side|"draw"; reason:string; mmr:number|null; rank:string|null; error?:string}
  | {type:"error"; message:string}
  | {type:"profile"; mmr:number; rank:string; wins:number; losses:number};
export interface ClientInput {type:"input"; seq:number; x:number; y:number; aim?:{x:number;y:number}; move?:number; dodge?:boolean; switchId?:string}
