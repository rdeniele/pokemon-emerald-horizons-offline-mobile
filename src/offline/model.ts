import * as Core from '../../web/engine.js';
import sourceRoster from '@/data/pokemon/species.generated.json';
import sourceKits from '@/data/pokemon/arena-kits.generated.json';
import sourceLearnsets from '@/data/pokemon/arena-learnsets.generated.json';
import { BattleEngine } from '@/battle/engine/BattleEngine';
import { ARENA_GRID } from '@/battle/field';
import {getArena,STAGE_ARENAS} from '@/battle/arenas';
import {toUnitSpec} from '@/pokemon/instance';
import {applyArenaKit} from '@/pokemon/moves/arenaKit';
import {arenaCooldown} from '@/pokemon/moves/timing';
import {arenaMoveProfile} from '@/pokemon/moves/arenaProfile';
import type {PokemonType} from '@/pokemon/types/typeChart';
import type {Skill,UnitSpec} from '@/battle/types';

// The earlier offline work is reused only for local progression, economy and saves.
// All combat and rendering now come from the copied original game.
export const E:any=Core;
// Preserve the source roster's regional/Mega/Gigantamax variants as well as its base species.
// Ordinary national species retain the first pass's progression data; extra forms use source stats/kits.
for(const raw of Object.values(sourceRoster) as any[]){
 if(E.species[raw.id])continue;
 const national=raw.nationalDexNumber??raw.id;
 const base=E.species[national];if(!base)continue;
 const kit=(sourceKits.kits as any)[raw.id]||[];
 const chosen=kit.map((m:any)=>m.name.toLowerCase().replace(/[^a-z0-9]/g,''));
 const valid=chosen.filter((id:string)=>E.moves[id]);while(valid.length<4)valid.push(base.moves[valid.length%base.moves.length]);
 E.species[raw.id]={...base,id:raw.id,nationalDexNumber:national,name:raw.name||raw.slug,types:raw.types,baseStats:raw.baseStats,gen:base.gen,form:raw.form||'regional',moves:valid.slice(0,4),learnset:[...new Set([...(((sourceLearnsets as any)[raw.id]||[]) as string[]).map(id=>id.replace(/[^a-z0-9]/g,'')).filter(id=>E.moves[id]),...valid])],evolutions:[]};
}
export type Mon={uid:string;species:number;level:number;xp:number;moves:string[];upgrades:Record<string,number>;held:string|null};
export type Battle={id:string;kind:'wild'|'gym'|'quick';index:number;team:Mon[];active:number;paused:boolean;engineSnapshot?:string;[key:string]:any};
export type Save={version:1;revision:number;rng:number;party:Mon[];pc:Mon[];gold:number;inventory:Record<string,number>;cleared:number[];chapter:number;seen:number[];pending:null|{id:string;mon:Mon;attempts:number};battle:Battle|null;claimed:string[];settings:{auto:boolean;sound:boolean};journal:string[]};
export const ORIGINAL_LEADERS=['Roxanne','Brawly','Wattson','Flannery','Norman','Winona','Tate & Liza','Juan','Sidney','Phoebe','Glacia','Drake','Wallace'];
export const ORIGINAL_TYPES=['rock','fighting','electric','fire','normal','flying','psychic','water','dark','ghost','ice','dragon','water'];
// Keep the original Hoenn journey and leaders; the new level progression is applied to it.
E.GYMS.forEach((g:string[],i:number)=>{g[0]=ORIGINAL_LEADERS[i];g[1]=ORIGINAL_TYPES[i];});
for(const scene of E.CHAPTERS)for(const [oldName,newName] of [['Fern','Roxanne'],['Maris','Brawly'],['Flint','Wattson'],['Volt','Flannery'],['Opal','Norman'],['Shade','Winona'],['Glacier','Tate & Liza'],['Aster','Juan']]){scene[0]=scene[0].replaceAll(oldName,newName);scene[1]=scene[1].replaceAll(oldName,newName);}
E.CHAPTERS[12]=['Drake','The Prism engine is silent and the rare Pokémon are free. Wallace waits beyond this chamber. Show the Champion what your journey taught you.'];
E.CHAPTERS[13]=['Wallace','The beacons shine again. Your rival Rowan is watching from the stands. Let this final battle celebrate the partners who brought us here.'];
export const SPECIES:any=E.species;
export function speciesName(p:Mon){return SPECIES[p.species].name as string;}
declare global {interface Window {Native?:{load:(key:string)=>string;save:(key:string,value:string)=>boolean;exportSave:(data:string)=>void;importSave:()=>void};pauseGame?:()=>void;importNativeSave?:(data:string)=>void;}}
export function makeStore(){return new E.SaveStore({get:(k:string)=>window.Native?window.Native.load(k):localStorage.getItem('emerald-'+k),set:(k:string,v:string)=>{if(window.Native){if(!window.Native.save(k,v))throw Error('Device storage write failed');}else localStorage.setItem('emerald-'+k,v);}});}
export function originalUnit(p:Mon):UnitSpec{
  const unit=toUnitSpec({id:p.uid,speciesId:p.species,level:p.level,exp:p.xp,shiny:false});
  applyArenaKit(unit);
  const stats=E.stats(p);unit.stats={...stats,hp:stats.hp*10};
  unit.movementSpeed=3.2+stats.spe/160;unit.damageDealtMultiplier=p.held==='charm'?1.1:1;
  const selected=p.moves.map((id:string)=>E.moves[id]);
  const basic=selected[0];unit.basic={name:basic.name,type:basic.type,category:basic.category==='physical'?'physical':'special',power:basic.power};unit.attackRange=arenaMoveProfile(basic.name).range;unit.attackCooldown=Math.max(.8,1.8-stats.spe/300);
  unit.skills=selected.slice(1,4).map((m:any,i:number):Skill=>{const inherited=unit.skills.find(sk=>sk.name===m.name);const buff=m.boosts?(m.boosts.spe?'speed':m.boosts.def||m.boosts.spd?'defense':'attack'):undefined;const status=m.status?{kind:({slp:'sleep',par:'paralysis',brn:'burn',psn:'poison',tox:'poison',frz:'stun'} as Record<string,any>)[m.status]||'slow',chance:1,duration:3}:undefined;const kind=m.power?'damage':buff?'buff':status?'control':/recover|roost|rest|synthesis|wish|heal|moonlight|morning sun/i.test(m.name)?'heal':inherited?.kind||'buff';const slot=(['skill1','skill2','ultimate'] as const)[i];return {...inherited,id:p.moves[i+1],name:m.name,type:m.type as PokemonType,category:m.category==='physical'?'physical':'special',kind,buff,power:kind==='heal'?25:m.power,cooldown:arenaCooldown(m.name,slot,kind),range:kind==='buff'||kind==='heal'?99:arenaMoveProfile(m.name).range,slot,aoeRadius:inherited?.aoeRadius??0,targetStrategy:'nearest',status:status??inherited?.status};});
  return unit;
}
export function buildOriginalBattle(save:Save):BattleEngine{
  const b=save.battle;if(!b)throw Error('No active battle');
  const arena=getArena(b.kind==='gym'?STAGE_ARENAS[b.index]:'meadow');
  const player=save.party.map(originalUnit),enemy=b.team.map(originalUnit);
  const engine=new BattleEngine({arena:true,arenaId:arena.id,seed:save.rng,grid:ARENA_GRID,obstacles:arena.obstacles.map(o=>({...o})),timeLimit:600,player:{roster:player,formation:[{unitId:player[0].id,x:3,y:9}],maxUnits:1},enemy:{roster:enemy,formation:[{unitId:enemy[0].id,x:14,y:2}],maxUnits:1}});
  engine.setControlled('player',!save.settings.auto);engine.setAuto('player',{basic:true,skills:true,ultimate:true});
  if(b.engineSnapshot)engine.restore(b.engineSnapshot);
  return engine;
}
