import {ARENA_OBSTACLES,type Obstacle} from "./field";
import regionalRoutes from "@/data/pokemon/regional-routes.json";

export interface ArenaDefinition {id:string;name:string;type:string;floor:string;tile:string;edge:string;line:string;cover:string;highlight:string;obstacleStyle:"rock"|"pillar"|"crate"|"crystal"|"tree";obstacles:Obstacle[]}
// Rotational symmetry gives both spawns the same cover opportunities.
const pairs=(...walls:Obstacle[])=>walls.flatMap(o=>[o,{x:17-o.x-o.w,y:11-o.y-o.h,w:o.w,h:o.h}]);
const HOENN_ARENAS:readonly ArenaDefinition[]=[
  {id:"meadow",name:"Training meadow",type:"grass",floor:"#90b878",tile:"#88b070",edge:"#557d54",line:"#d8dea0",cover:"#9caa94",highlight:"#d0d4b4",obstacleStyle:"rock",obstacles:ARENA_OBSTACLES},
  {id:"rustboro",name:"Rustboro · Rock",type:"rock",floor:"#b6a078",tile:"#aa946d",edge:"#685641",line:"#eee0b4",cover:"#84755f",highlight:"#cbbb9a",obstacleStyle:"rock",obstacles:pairs({x:5,y:2,w:2,h:2},{x:7,y:7,w:1.2,h:1.5})},
  {id:"dewford",name:"Dewford · Fighting",type:"fighting",floor:"#bb8766",tile:"#ad795b",edge:"#743d35",line:"#f4d49b",cover:"#8b563e",highlight:"#ddb77b",obstacleStyle:"crate",obstacles:pairs({x:4.5,y:3,w:1.2,h:3},{x:8,y:1,w:1,h:1.5})},
  {id:"mauville",name:"Mauville · Electric",type:"electric",floor:"#b8b079",tile:"#aaa269",edge:"#4b6260",line:"#fff3a0",cover:"#637a77",highlight:"#f4dc68",obstacleStyle:"pillar",obstacles:pairs({x:5,y:2,w:1,h:3},{x:7.5,y:7,w:2,h:1})},
  {id:"lavaridge",name:"Lavaridge · Fire",type:"fire",floor:"#b77d62",tile:"#a96e57",edge:"#683c38",line:"#ffd39a",cover:"#765347",highlight:"#e5a160",obstacleStyle:"rock",obstacles:pairs({x:4,y:3,w:2.5,h:1.2},{x:8,y:1.5,w:1,h:2})},
  {id:"petalburg",name:"Petalburg · Normal",type:"normal",floor:"#baa67f",tile:"#b09b74",edge:"#655947",line:"#f8eacd",cover:"#8a7150",highlight:"#d9be87",obstacleStyle:"crate",obstacles:pairs({x:5,y:2,w:1.8,h:1.4},{x:6,y:7,w:2,h:1.2})},
  {id:"fortree",name:"Fortree · Flying",type:"flying",floor:"#91b7a0",tile:"#85aa94",edge:"#456b62",line:"#e1f0cd",cover:"#648566",highlight:"#b6d09b",obstacleStyle:"tree",obstacles:pairs({x:4.5,y:2.5,w:1.5,h:2},{x:8,y:7,w:1,h:2})},
  {id:"mossdeep",name:"Mossdeep · Psychic",type:"psychic",floor:"#a89bbd",tile:"#9b8ead",edge:"#62517a",line:"#f2d6ed",cover:"#7d689c",highlight:"#dfb6e0",obstacleStyle:"crystal",obstacles:pairs({x:5.5,y:2,w:1.4,h:1.4},{x:8,y:6.5,w:1,h:2.5})},
  {id:"sootopolis",name:"Sootopolis · Water",type:"water",floor:"#80b6bc",tile:"#74a8b0",edge:"#386876",line:"#d9f0db",cover:"#648d9b",highlight:"#bcdfda",obstacleStyle:"pillar",obstacles:pairs({x:5,y:2.5,w:1.5,h:2.5},{x:7,y:7.5,w:2,h:1})},
  {id:"sidney",name:"Sidney · Dark",type:"dark",floor:"#9e9294",tile:"#908486",edge:"#51464e",line:"#e8cba9",cover:"#685c66",highlight:"#b9a0a4",obstacleStyle:"pillar",obstacles:pairs({x:4,y:3,w:2,h:1.5},{x:7,y:1.5,w:2,h:1.2})},
  {id:"phoebe",name:"Phoebe · Ghost",type:"ghost",floor:"#a298b5",tile:"#948ba7",edge:"#544664",line:"#e0cfed",cover:"#78678c",highlight:"#c3acd3",obstacleStyle:"pillar",obstacles:pairs({x:5,y:1.5,w:1,h:3},{x:7,y:7,w:2.5,h:1})},
  {id:"glacia",name:"Glacia · Ice",type:"ice",floor:"#accbce",tile:"#9dbec4",edge:"#547f8d",line:"#f0fbeb",cover:"#83aebd",highlight:"#e2f4ed",obstacleStyle:"crystal",obstacles:pairs({x:4.5,y:2,w:2,h:1.5},{x:8,y:6.5,w:1,h:2})},
  {id:"drake",name:"Drake · Dragon",type:"dragon",floor:"#a4a6b9",tile:"#9699ac",edge:"#525c7d",line:"#ecd9ac",cover:"#727b99",highlight:"#b9c3d6",obstacleStyle:"rock",obstacles:pairs({x:4,y:3,w:1.8,h:2},{x:7,y:1,w:2,h:1})},
  {id:"champion",name:"Wallace · Champion",type:"water",floor:"#91bfbd",tile:"#83b1b0",edge:"#3d7377",line:"#fff1b5",cover:"#698f9c",highlight:"#ebda9b",obstacleStyle:"pillar",obstacles:pairs({x:5.5,y:2,w:1,h:2},{x:8,y:7,w:2,h:1.5})},
];
export const STAGE_ARENAS=HOENN_ARENAS.slice(1).map(a=>a.id);
const extraPalettes:Record<string,Partial<ArenaDefinition>>={
  grass:{floor:"#91b878",tile:"#83aa6c",edge:"#42653d",line:"#e4efb7",cover:"#668452",highlight:"#c1d99a",obstacleStyle:"tree"},
  bug:{floor:"#b4bb74",tile:"#a4ac65",edge:"#596337",line:"#f0edb0",cover:"#7d894f",highlight:"#d9dfa3",obstacleStyle:"tree"},
  poison:{floor:"#b395b5",tile:"#a486a9",edge:"#6c4274",line:"#eed1e8",cover:"#89618e",highlight:"#d4b4dc",obstacleStyle:"crystal"},
  ground:{floor:"#c4a87d",tile:"#b69a70",edge:"#74553d",line:"#f4deb1",cover:"#967853",highlight:"#dfc99c",obstacleStyle:"rock"},
  steel:{floor:"#a4b4b7",tile:"#95a6aa",edge:"#4f646e",line:"#e1eaec",cover:"#70858e",highlight:"#c2d5d9",obstacleStyle:"pillar"},
  fairy:{floor:"#d0a8c0",tile:"#c39ab4",edge:"#83576e",line:"#fff0dc",cover:"#ad7e9f",highlight:"#efd4e3",obstacleStyle:"crystal"},
};
export const ARENAS:readonly ArenaDefinition[]=[...HOENN_ARENAS,...regionalRoutes.flatMap((route,ri)=>route.stages.map((stage,i)=>{
  const base=HOENN_ARENAS.find(a=>a.type===stage.type)??HOENN_ARENAS[0];
  // A distinct, rotationally symmetric layout per regional opponent; clear spawn lanes.
  const n=ri*13+i;
  return {...base,...extraPalettes[stage.type],id:stage.arenaId,name:`${route.name} · ${stage.name} · ${stage.type}`,type:stage.type,
    obstacles:pairs({x:4.2+(n%5)*.21,y:2+(n%7)*.13,w:1.1+(n%3)*.3,h:1.4+(n%4)*.25},{x:7.5+(n%4)*.15,y:7.1+(n%3)*.14,w:1+(n%6)*.12,h:1})};
}))];
export const isArenaId=(value:unknown):value is string=>typeof value==="string"&&ARENAS.some(a=>a.id===value);
export const getArena=(id:unknown)=>ARENAS.find(a=>a.id===id)??ARENAS[0];
/** Match preferences never split matchmaking; one of the two preferences wins a seeded coin flip. */
export function chooseMatchArena(a:string,b:string,seed:number):string {
  const choices=[a,b].filter(isArenaId);
  return choices.length?choices[(seed>>>0)%choices.length]:ARENAS[1+(seed>>>0)%(ARENAS.length-1)].id;
}
