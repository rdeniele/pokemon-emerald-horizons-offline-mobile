import type { EmeraldState, EmeraldSession } from './emerald-script-vm';

export type EmeraldDirection='up'|'down'|'left'|'right';
export type EmeraldPosition={map:string;x:number;y:number;facing:EmeraldDirection};
export type EmeraldTileOverride={id:number;collision?:number;elevation?:number;behavior?:number};
export type EmeraldObjectOverride={x?:number;y?:number;hidden?:boolean;facing?:EmeraldDirection;movement?:string};
export type EmeraldBerryTree={item:string;stage:number;watered:number;yield:number;seenAt:number;regrowths:number};
/** JSON-only state: scripts and map mutations survive Android process death. */
export type EmeraldWorldState=EmeraldState & EmeraldPosition & {
 version:1;trainerFlags:Record<string,boolean>;inventory:Record<string,number>;money:number;
 lastHeal:EmeraldPosition;dynamicWarps:Record<string,EmeraldPosition>;
 objects:Record<string,EmeraldObjectOverride>;metatiles:Record<string,EmeraldTileOverride>;
 surfing:boolean;diving:boolean;bike:'none'|'mach'|'acro';strength:boolean;
 weather:string;flashLevel:number;stepCallback:string;steps:number;berryTrees?:Record<string,EmeraldBerryTree>;
 strings:Record<string,string>;session?:EmeraldSession;starter?:number;registeredItem?:string;lastBattleOutcome?:number;lastBattle?:number;clockStartedAt?:number;hallOfFameCount?:number;playerHidden?:boolean;previousMap?:string;gabbyBattleNum?:number;mirageRandom?:number;nativeState?:Record<string,unknown>;trainerId?:number;activeTrainer?:string;rematches?:Record<string,{ready:boolean;secondWon?:boolean}>;
};
export function createEmeraldWorldState(resetFlags:string[]=[]):EmeraldWorldState{
 const start:EmeraldPosition={map:'MAP_INSIDE_OF_TRUCK',x:3,y:3,facing:'down'};
 return{version:1,...start,flags:Object.fromEntries(resetFlags.map(flag=>[flag,true])),vars:{},trainerFlags:{},inventory:{},money:3000,lastHeal:{map:'MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_1F',x:5,y:8,facing:'down'},dynamicWarps:{},objects:{},metatiles:{},surfing:false,diving:false,bike:'none',strength:false,weather:'WEATHER_NONE',flashLevel:0,stepCallback:'STEP_CB_DUMMY',steps:0,strings:{},playerName:'TRAINER',rivalName:'MAY',gender:0};
}
export const emeraldTileKey=(map:string,x:number,y:number)=>`${map}:${x},${y}`;
export const emeraldObjectKey=(map:string,id:string|number)=>`${map}:${id}`;
