import type {EmeraldWorldState,EmeraldPosition} from './emerald-state';

export type EmeraldFishingSlot={species:string;min_level:number;max_level:number};
export type EmeraldFishingProfile={encounter_rate:number;mons:EmeraldFishingSlot[]};
export type EmeraldRod='old'|'good'|'super';
export type EmeraldFieldItemContext={
 map:{allow_cycling?:boolean;allow_escaping?:boolean};
 facingWater?:boolean;facingWaterfall?:boolean;facingWaterCollision?:number;facingBridgeWater?:boolean;
 currentRail?:boolean;fishingProfile?:EmeraldFishingProfile;
};
export type EmeraldFieldItemEffect=
 |{kind:'bike';bike:EmeraldWorldState['bike']}
 |{kind:'repel';steps:number}
 |{kind:'escape';destination:EmeraldPosition}
 |{kind:'fishing';rod:EmeraldRod;rate:number;slots:EmeraldFishingSlot[]}
 |{kind:'encounter-flute';direction:'up'|'down'};
export type EmeraldFieldItemResult=
 |{handled:false;used:false;reason:string}
 |{handled:true;used:false;reason:string}
 |{handled:true;used:true;next:EmeraldWorldState;effect:EmeraldFieldItemEffect;message:string};
const repelSteps:Record<string,number>={ITEM_REPEL:100,ITEM_SUPER_REPEL:200,ITEM_MAX_REPEL:250};
const rods:Record<string,EmeraldRod>={ITEM_OLD_ROD:'old',ITEM_GOOD_ROD:'good',ITEM_SUPER_ROD:'super'};
const supported=new Set([...Object.keys(repelSteps),...Object.keys(rods),'ITEM_MACH_BIKE','ITEM_ACRO_BIKE','ITEM_ESCAPE_ROPE','ITEM_BLACK_FLUTE','ITEM_WHITE_FLUTE']);

/** Source item_use.c checks and effects, without mutating a live save or starting a battle. */
export function useEmeraldFieldItem(state:EmeraldWorldState,item:string,context:EmeraldFieldItemContext):EmeraldFieldItemResult{
 if(!supported.has(item))return{handled:false,used:false,reason:'This item needs its own field service.'};
 const reject=(reason:string):EmeraldFieldItemResult=>({handled:true,used:false,reason});
 if(!(state.inventory[item]>0))return reject('You do not have this item.');
 const next=structuredClone(state);
 const done=(effect:EmeraldFieldItemEffect,message:string,consume=false):EmeraldFieldItemResult=>{if(consume)next.inventory[item]--;return{handled:true,used:true,next,effect,message};};
 if(repelSteps[item]){if((state.vars.VAR_REPEL_STEP_COUNT||0)>0)return reject('The Repel’s effect still lingers.');next.vars.VAR_REPEL_STEP_COUNT=repelSteps[item];return done({kind:'repel',steps:repelSteps[item]},'Wild Pokémon weaker than your first Pokémon will be repelled.',true);}
 if(item==='ITEM_MACH_BIKE'||item==='ITEM_ACRO_BIKE'){
  if(state.flags.FLAG_SYS_CYCLING_ROAD||context.currentRail)return reject('You cannot get off your bike here.');
  if(!context.map.allow_cycling||state.surfing||state.diving||state.playerHidden)return reject('You cannot ride a bike here.');
  next.bike=state.bike==='none'?(item==='ITEM_MACH_BIKE'?'mach':'acro'):'none';
  return done({kind:'bike',bike:next.bike},next.bike==='none'?'Got off the bike.':'Got on the '+(next.bike==='mach'?'Mach':'Acro')+' Bike.');
 }
 if(item==='ITEM_ESCAPE_ROPE'){
  const destination=state.dynamicWarps.escape;
  if(!context.map.allow_escaping||!destination)return reject('You cannot use an Escape Rope here.');
  return done({kind:'escape',destination:structuredClone(destination)},'Used an Escape Rope.',true);
 }
 const rod=rods[item];
 if(rod){
  if(state.diving||context.facingWaterfall||!context.facingWater&&!context.facingBridgeWater||state.surfing&&context.facingWaterCollision!==undefined&&context.facingWaterCollision!==0&&!context.facingBridgeWater)return reject('You cannot fish here.');
  const range=rod==='old'?[0,2]:rod==='good'?[2,5]:[5,10],profile=context.fishingProfile,slots=profile?.mons.slice(...range);
  if(!profile||!slots?.length)return reject('There are no fishing encounters here.');
  return done({kind:'fishing',rod,rate:profile.encounter_rate,slots},'Cast the line into the water.');
 }
 const direction=item==='ITEM_WHITE_FLUTE'?'up':'down';next.flags.FLAG_SYS_ENC_UP_ITEM=direction==='up';next.flags.FLAG_SYS_ENC_DOWN_ITEM=direction==='down';
 return done({kind:'encounter-flute',direction},direction==='up'?'Wild Pokémon were lured closer.':'Wild Pokémon were repelled.');
}

/** Run after successful steps, including while mounted; save VAR_REPEL_STEP_COUNT exactly. */
export function stepEmeraldRepel(state:EmeraldWorldState):{next:EmeraldWorldState;expired:boolean}{const next=structuredClone(state),before=Math.max(0,state.vars.VAR_REPEL_STEP_COUNT||0);next.vars.VAR_REPEL_STEP_COUNT=Math.max(0,before-1);return{next,expired:before===1};}
export function emeraldRepelBlocks(state:EmeraldWorldState,wildLevel:number,leadLevel:number){return(state.vars.VAR_REPEL_STEP_COUNT||0)>0&&wildLevel<leadLevel;}
export function normalizeEmeraldFieldMove(move:string){const key=move.replace(/^MOVE_/i,'').replace(/[^a-z]/gi,'').toUpperCase();return key==='ROCKSMASH'?'ROCK_SMASH':key;}
