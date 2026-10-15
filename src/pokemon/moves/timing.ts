import profiles from "@/data/pokemon/empress-moves.generated.json";
import {isTravelMove,moveBehavior} from "./behavior";
const data=profiles as Record<string,{cooldown:number;speed:number;power:number;priority:number}>;
export const moveKey=(name:string)=>name.toLowerCase().replace(/[^a-z0-9]/g,"");
/** Empress uses pixel units; our authoritative arena uses grid units. */
export function projectileSpeed(name:string):number {
  const speed=data[moveKey(name)]?.speed;
  return speed?Math.max(8,Math.min(24,speed/40)):14;
}
export function arenaCooldown(name:string,slot:"skill1"|"skill2"|"ultimate",kind:string):number {
  const imported=data[moveKey(name)]?.cooldown;
  if(isTravelMove(moveBehavior(name)))return 8;
  if(kind!=="damage")return imported?Math.max(7,Math.min(13,imported)):8;
  if(slot==="ultimate")return imported?Math.max(6,Math.min(10,imported*2)):8;
  return imported?Math.max(2,Math.min(6,imported)):3;
}
