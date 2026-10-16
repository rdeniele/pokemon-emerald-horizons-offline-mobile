import {emeraldObjectKey,emeraldTileKey,type EmeraldWorldState,type EmeraldDirection,type EmeraldPosition} from './emerald-state';
import {emeraldRandom} from './emerald-script-vm';
import {normalizeEmeraldFieldMove} from './emerald-items';

export type EmeraldMap={width:number;height:number;tiles:string[];rawCells?:number[];collision?:number[];elevations?:number[];behaviors?:number[];metatileAttributes?:number[];connections?:{dir:string;to:string;offset:number|string}[];npcs?:{localId:number;x:number;y:number;flag?:string;flag_id?:string;graphics_id?:string;trainer_sight_or_berry_tree_id?:string}[]};
export type EmeraldEffect={kind:string;[key:string]:unknown};
export type EmeraldMechanicResult={handled:boolean;result?:number;effect?:EmeraldEffect;reason?:string};
export type EmeraldMechanicContext={resolve?:(value:string)=>number;maps?:Record<string,EmeraldMap>;constants?:Record<string,number>;toInternalSpecies?:(national:number)=>number;party?:{species:number;level:number;moves?:string[];hp?:number;personality?:number;pokerus?:number}[];now?:Date};
// min yield, max yield, stage hours from canonical berry.c.
const berryInfo:Record<string,number[]>={"ITEM_CHERI_BERRY":[2,3,3],"ITEM_CHESTO_BERRY":[2,3,3],"ITEM_PECHA_BERRY":[2,3,3],"ITEM_RAWST_BERRY":[2,3,3],"ITEM_ASPEAR_BERRY":[2,3,3],"ITEM_LEPPA_BERRY":[2,3,4],"ITEM_ORAN_BERRY":[2,3,3],"ITEM_PERSIM_BERRY":[2,3,3],"ITEM_LUM_BERRY":[1,2,12],"ITEM_SITRUS_BERRY":[2,3,6],"ITEM_FIGY_BERRY":[2,3,6],"ITEM_WIKI_BERRY":[2,3,6],"ITEM_MAGO_BERRY":[2,3,6],"ITEM_AGUAV_BERRY":[2,3,6],"ITEM_IAPAPA_BERRY":[2,3,6],"ITEM_RAZZ_BERRY":[3,6,1],"ITEM_BLUK_BERRY":[3,6,1],"ITEM_NANAB_BERRY":[3,6,1],"ITEM_WEPEAR_BERRY":[3,6,1],"ITEM_PINAP_BERRY":[3,6,1],"ITEM_POMEG_BERRY":[2,6,3],"ITEM_KELPSY_BERRY":[2,6,3],"ITEM_QUALOT_BERRY":[2,6,3],"ITEM_HONDEW_BERRY":[2,6,3],"ITEM_GREPA_BERRY":[2,6,3],"ITEM_TAMATO_BERRY":[2,4,6],"ITEM_CORNN_BERRY":[2,4,6],"ITEM_MAGOST_BERRY":[2,4,6],"ITEM_RABUTA_BERRY":[2,4,6],"ITEM_NOMEL_BERRY":[2,4,6],"ITEM_SPELON_BERRY":[1,2,18],"ITEM_PAMTRE_BERRY":[1,2,18],"ITEM_WATMEL_BERRY":[1,2,18],"ITEM_DURIN_BERRY":[1,2,18],"ITEM_BELUE_BERRY":[1,2,18],"ITEM_LIECHI_BERRY":[1,2,24],"ITEM_GANLON_BERRY":[1,2,24],"ITEM_SALAC_BERRY":[1,2,24],"ITEM_PETAYA_BERRY":[1,2,24],"ITEM_APICOT_BERRY":[1,2,24],"ITEM_LANSAT_BERRY":[1,2,24],"ITEM_STARF_BERRY":[1,2,24],"ITEM_ENIGMA_BERRY":[1,2,24]};
const applied=(result?:number):EmeraldMechanicResult=>({handled:true,...(result===undefined?{}:{result})});
const effect=(kind:string,extra:Record<string,unknown>={}):EmeraldMechanicResult=>({handled:true,effect:{kind,...extra}});
const unsupported=(name:string):EmeraldMechanicResult=>({handled:false,reason:`Canonical Emerald native handler ${name} has not been implemented; script must remain suspended.`});
const directions:Record<EmeraldDirection,[number,number]>={up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]};
/** field_player_avatar.c sForcedMovementTestFuncs; arrow warp tiles are warps,
 * not conveyor floor tiles and intentionally remain the warp dispatcher's job. */
export function emeraldForcedDirection(behavior:string,entered:EmeraldDirection):EmeraldDirection|undefined{
 if(behavior==='MB_ICE'||behavior==='MB_TRICK_HOUSE_PUZZLE_8_FLOOR')return entered;
 const directionsByBehavior:Record<string,EmeraldDirection>={MB_WALK_NORTH:'up',MB_WALK_SOUTH:'down',MB_WALK_WEST:'left',MB_WALK_EAST:'right',MB_NORTHWARD_CURRENT:'up',MB_SOUTHWARD_CURRENT:'down',MB_WESTWARD_CURRENT:'left',MB_EASTWARD_CURRENT:'right',MB_SLIDE_NORTH:'up',MB_SLIDE_SOUTH:'down',MB_SLIDE_WEST:'left',MB_SLIDE_EAST:'right',MB_WATERFALL:'down'};
 return directionsByBehavior[behavior];
}
export function updateEmeraldBerryGrowth(state:EmeraldWorldState,now=Date.now()){
 for(const tree of Object.values(state.berryTrees||{})){const data=berryInfo[tree.item];if(!data||!tree.stage||!data[2])continue;const stageMs=data[2]*3600000;let duration=stageMs*(tree.stage===5?4:1);let remaining=now-tree.seenAt;if(remaining>=stageMs*71){Object.assign(tree,{item:'',stage:0,watered:0,yield:0,regrowths:0,seenAt:now});continue;}
  while(tree.stage&&remaining>=duration){remaining-=duration;tree.seenAt+=duration;if(tree.stage===5){tree.stage=2;tree.watered=0;tree.yield=0;tree.regrowths++;if(tree.regrowths===10){Object.assign(tree,{item:'',stage:0,watered:0,yield:0,regrowths:0});break;}}else{if(tree.stage===4){const water=tree.watered.toString(2).replaceAll('0','').length;const min=data[0],max=data[1];if(!water)tree.yield=min;else{const random=(max-min)*(water-1)+Math.floor(emeraldRandom(state)*((max-min)+1));tree.yield=min+Math.floor(random/4)+(random%4>=2?1:0);}}tree.stage++;}duration=stageMs*(tree.stage===5?4:1);}
 }
}
// Canonical rotating_gate.c configurations: x, y, shape, initial quarter-turns.
const fortreeGates=[[6,7,5,1],[9,15,5,2],[3,19,5,1],[2,6,4,1],[9,12,4,0],[6,23,4,0],[12,22,4,0],[6,3,3,2]];
const trickGates=[[14,5,4,1],[10,6,1,2],[6,6,3,1],[14,8,4,1],[3,10,2,3],[9,14,0,1],[3,15,6,0],[2,17,1,2],[12,18,6,3],[5,18,3,1],[10,19,2,2]];
const armLayouts=[[1,0,1,0,0,0,0,0],[1,1,1,0,0,0,0,0],[1,0,1,1,0,0,0,0],[1,1,1,1,0,0,0,0],[1,0,1,0,1,0,0,0],[1,1,1,0,1,0,0,0],[1,0,1,1,1,0,0,0]];
const gateConfig=(map:string)=>map==='MAP_FORTREE_CITY_GYM'?fortreeGates:map==='MAP_ROUTE110_TRICK_HOUSE_PUZZLE6'?trickGates:[];
const gateOrientation=(s:EmeraldWorldState,i:number,initial:number)=>((s.vars[`VAR_TEMP_${Math.floor(i/2).toString(16).toUpperCase()}`]??(initial<<((i%2)*8)))>>((i%2)*8))&255;
function setGateOrientation(s:EmeraldWorldState,i:number,n:number){const key=`VAR_TEMP_${Math.floor(i/2).toString(16).toUpperCase()}`,shift=(i%2)*8;s.vars[key]=((s.vars[key]||0)&~(255<<shift))|(n<<shift);}
export function emeraldRotatingGates(s:EmeraldWorldState){return gateConfig(s.map).map(([x,y,shape,initial],id)=>({id,x,y,shape,orientation:gateOrientation(s,id,initial),arms:armLayouts[shape]}));}
function rotatingGateCollision(s:EmeraldWorldState,map:EmeraldMap,direction:EmeraldDirection,x:number,y:number){for(const [i,gate]of gateConfig(s.map).entries()){const [gx,gy,shape,initial]=gate,cx=x-gx+2,cy=y-gy+2;if(cx<0||cy<0||cx>3||cy>3)continue;let arm=-1,long=0,rotation=0;if(direction==='up'&&cy===1){arm=cx<2?3:1;long=cx===0||cx===3?1:0;rotation=cx<2?1:-1;}if(direction==='down'&&cy===2){arm=cx<2?3:1;long=cx===0||cx===3?1:0;rotation=cx<2?-1:1;}if(direction==='left'&&cx===1){arm=cy<2?0:2;long=cy===0||cy===3?1:0;rotation=cy<2?-1:1;}if(direction==='right'&&cx===2){arm=cy<2?0:2;long=cy===0||cy===3?1:0;rotation=cy<2?1:-1;}if(arm<0)continue;const orientation=gateOrientation(s,i,initial);if(!armLayouts[shape][((arm-orientation+4)%4)*2+long])continue;const sweep=rotation===1?[[0,-1],[1,-2],[0,0],[1,0],[-1,0],[-1,1],[-1,-1],[-2,-1]]:[[-1,-1],[-1,-2],[0,-1],[1,-1],[0,0],[0,1],[-1,0],[-2,0]];for(let a=0;a<4;a++)for(let l=0;l<2;l++)if(armLayouts[shape][a*2+l]){const [dx,dy]=sweep[((orientation+a)%4)*2+l];if(emeraldCell(s,map,gx+dx,gy+dy).collision===1)return true;}setGateOrientation(s,i,(orientation+rotation+4)%4);}return false;}
const directionNames:Record<string,EmeraldDirection>={DIR_NORTH:'up',DIR_SOUTH:'down',DIR_WEST:'left',DIR_EAST:'right','1':'down','2':'up','3':'left','4':'right'};
export const FIELD_BADGES:Record<string,string>={CUT:'FLAG_BADGE01_GET',FLASH:'FLAG_BADGE02_GET',ROCK_SMASH:'FLAG_BADGE03_GET',STRENGTH:'FLAG_BADGE04_GET',SURF:'FLAG_BADGE05_GET',FLY:'FLAG_BADGE06_GET',DIVE:'FLAG_BADGE07_GET',WATERFALL:'FLAG_BADGE08_GET'};
export function fieldMovePermission(state:EmeraldWorldState,move:string,partyMoves:string[]){const name=normalizeEmeraldFieldMove(move);if(!FIELD_BADGES[name])return{allowed:false,reason:'Unknown field move'};if(!state.flags[FIELD_BADGES[name]])return{allowed:false,reason:'The required Gym Badge has not been earned.'};if(!partyMoves.some(m=>normalizeEmeraldFieldMove(m)===name))return{allowed:false,reason:'No party Pokémon knows this move.'};return{allowed:true,reason:''};}
export function emeraldCell(state:EmeraldWorldState,map:EmeraldMap,x:number,y:number){const i=y*map.width+x;const changed=state.metatiles[emeraldTileKey(state.map,x,y)];return{id:changed?.id??((map.rawCells?.[i]??0)&1023),collision:changed?.collision??map.collision?.[i]??(map.tiles[y]?.[x]==='#'?1:0),elevation:changed?.elevation??map.elevations?.[i]??0,behavior:changed?.behavior??(changed&&map.metatileAttributes?.[changed.id]!==undefined?(map.metatileAttributes[changed.id]&255):map.behaviors?.[i]??0),water:map.tiles[y]?.[x]==='W'};}
/** Map connection offsets use target coordinate = source coordinate - offset. */
export function tryEmeraldStep(state:EmeraldWorldState,map:EmeraldMap,direction:EmeraldDirection,maps:Record<string,EmeraldMap>,behaviorNames:Record<string,string>={}):{moved:boolean;reason?:string;connection?:boolean;jump?:boolean;fall?:boolean;fallTo?:EmeraldPosition;forced?:EmeraldDirection}{
 state.facing=direction;const [dx,dy]=directions[direction];let x=state.x+dx,y=state.y+dy;
 if(x<0||y<0||x>=map.width||y>=map.height){const c=map.connections?.find(c=>c.dir===direction||c.dir===({up:'north',down:'south',left:'west',right:'east'}[direction]));const target=c&&maps[c.to];if(!c||!target)return{moved:false,reason:'Map boundary'};if(dx){x=dx>0?0:target.width-1;y-=Number(c.offset)||0;}else{y=dy>0?0:target.height-1;x-=Number(c.offset)||0;}if(x<0||y<0||x>=target.width||y>=target.height)return{moved:false,reason:'Connection outside target map'};const previousMap=state.map;state.map=c.to;const cell=emeraldCell(state,target,x,y);state.map=previousMap;if(cell.collision&&!cell.water)return{moved:false,reason:'Blocked connection'};if(cell.water&&!state.surfing)return{moved:false,reason:'Surf is required'};state.map=c.to;state.x=x;state.y=y;state.steps++;return{moved:true,connection:true};}
 const cell=emeraldCell(state,map,x,y),previous=emeraldCell(state,map,state.x,state.y);const name=behaviorNames[String(cell.behavior)]||'';
 if(rotatingGateCollision(state,map,direction,x,y))return{moved:false,reason:'Rotating gate blocked by wall'};
 const ledge={up:'NORTH',down:'SOUTH',left:'WEST',right:'EAST'}[direction];let jump=false;
 if(name===`MB_JUMP_${ledge}`){x+=dx;y+=dy;if(x<0||y<0||x>=map.width||y>=map.height||emeraldCell(state,map,x,y).collision)return{moved:false,reason:'Blocked ledge landing'};jump=true;}
 else if(cell.water&&!state.surfing)return{moved:false,reason:'Surf is required'};
 else if(cell.collision&&!cell.water)return{moved:false,reason:'Collision'};
 if(!jump&&previous.elevation&&cell.elevation&&previous.elevation!==cell.elevation)return{moved:false,reason:'Elevation mismatch'};
 const occupied=map.npcs?.find(n=>{const o=state.objects[emeraldObjectKey(state.map,n.localId)];const flag=n.flag||n.flag_id;return !o?.hidden&&!(flag&&flag!=='0'&&state.flags[flag])&&(o?.x??n.x)===x&&(o?.y??n.y)===y;});if(occupied){
  if(!state.strength||occupied.graphics_id!=='OBJ_EVENT_GFX_PUSHABLE_BOULDER')return{moved:false,reason:'Object event'};
  const bx=x+dx,by=y+dy,beyond=emeraldCell(state,map,bx,by);if(bx<0||by<0||bx>=map.width||by>=map.height||beyond.collision||beyond.water||(cell.elevation&&beyond.elevation&&cell.elevation!==beyond.elevation)||map.npcs?.some(n=>{if(n.localId===occupied.localId)return false;const o=state.objects[emeraldObjectKey(state.map,n.localId)];const flag=n.flag||n.flag_id;return !o?.hidden&&!(flag&&flag!=='0'&&state.flags[flag])&&(o?.x??n.x)===bx&&(o?.y??n.y)===by;}))return{moved:false,reason:'Boulder cannot move'};
  const key=emeraldObjectKey(state.map,occupied.localId);state.objects[key]={...state.objects[key],x:bx,y:by};
 }
 state.x=x;state.y=y;state.steps++;if(state.surfing&&!cell.water)state.surfing=false;
 if(state.stepCallback==='STEP_CB_SOOTOPOLIS_ICE'&&(name==='MB_THIN_ICE'||name==='MB_CRACKED_ICE')){const key=emeraldTileKey(state.map,x,y);if(name==='MB_CRACKED_ICE'||state.metatiles[key]?.id===0x20e){state.vars.VAR_ICE_STEP_COUNT=0;state.metatiles[key]={id:0x206,collision:0};return{moved:true,fall:true,fallTo:{map:'MAP_SOOTOPOLIS_CITY_GYM_B1F',x,y,facing:state.facing}};}state.vars.VAR_ICE_STEP_COUNT=(state.vars.VAR_ICE_STEP_COUNT||0)+1;state.metatiles[key]={id:0x20e,collision:0};const rows:Record<number,string>={6:'1',7:'2',8:'3',9:'4',12:'5',13:'6',14:'7',17:'8',18:'9',19:'A'};if(rows[y]&&x>=3&&x<=13)state.vars[`VAR_TEMP_${rows[y]}`]=(state.vars[`VAR_TEMP_${rows[y]}`]||0)|(1<<(x-3));}
 const landedName=behaviorNames[String(emeraldCell(state,map,x,y).behavior)]||'';const forced=emeraldForcedDirection(landedName,direction);return{moved:true,jump,...(forced?{forced}:{})};
}
export function applyEmeraldAction(state:EmeraldWorldState,op:string,args:string[],resolve:(s:string)=>number=(s)=>state.vars[s]??(Number(s)||0)):EmeraldMechanicResult{
 const v=(i:number)=>resolve(args[i]||'0');const map=args.find(a=>a.startsWith('MAP_'))||state.map;
 if(op==='hideplayer'||op==='showplayer'){state.playerHidden=op==='hideplayer';return applied();}
 // Object coordinates in this runtime are saved directly in map-scoped overrides,
 // rather than split into the GBA's live-object and saved-template arrays.
 if(op==='copyobjectxytoperm')return applied();
 if(op==='fadenewbgm')return effect('presentation',{name:op,args});
 if(op==='frontier_set'&&args[0]==='FRONTIER_DATA_SELECTED_MON_ORDER'){const native=state.nativeState??={};native.frontierSelectedOrder=structuredClone(native.selectedPartyOrder||[]);return applied();}
 if(op==='frontier_saveparty')return effect('save-selected-party');
 if(op==='finditem')return effect('find-item',{item:args[0],quantity:args[1]?v(1):1,object:state.vars.VAR_LAST_TALKED});
 if(op==='register_matchcall'){const native=state.nativeState??={};const registrations=(native.registeredTrainers??={}) as Record<string,boolean>;registrations[String(v(0))]=true;return effect('register-trainer',{trainer:args[0]});}
 if(op==='dotimebasedevents')return effect('clock-events');
 if(op==='playmoncry'||op==='waitmoncry'||op==='showmonpic'||op==='hidemonpic'||op==='dofieldeffectsparkle')return effect('presentation',{name:op,args});
 if(op==='setmetatile'){state.metatiles[emeraldTileKey(state.map,v(0),v(1))]={id:v(2),collision:v(3)};return applied();}
 if(op==='setweather'){state.weather=args[0];return applied();}if(op==='setflashlevel'){state.flashLevel=v(0);return applied();}
 if(op==='setstepcallback'){state.stepCallback=args[0];return applied();}
 if(op==='setrespawn'){return effect('set-respawn',{healLocation:args[0]});}
 if(op==='setdynamicwarp'||op==='setescapewarp'){state.dynamicWarps[op==='setescapewarp'?'escape':'dynamic']={map:args[0],x:v(args.length-2),y:v(args.length-1),facing:state.facing};return applied();}
 if(op==='setdivewarp'||op==='setholewarp'){state.dynamicWarps[op==='setdivewarp'?'dive':'hole']={map:args[0],x:args.length>=3?v(args.length-2):state.x,y:args.length>=3?v(args.length-1):state.y,facing:state.facing};return applied();}
 if(op==='removeobject'||op==='addobject'||op==='setobjectxy'||op==='setobjectxyperm'||op==='turnobject'||op==='setobjectmovementtype'){const key=emeraldObjectKey(map,args[0]);const object=state.objects[key]??={};if(op==='removeobject'||op==='addobject')object.hidden=op==='removeobject';if(op==='setobjectxy'||op==='setobjectxyperm'){object.x=v(1);object.y=v(2);}if(op==='turnobject')object.facing=directionNames[args[1]]||directionNames[String(v(1))]||'down';if(op==='setobjectmovementtype')object.movement=args[1];return applied();}
 if(op==='bufferstring'||op==='bufferstdstring'){state.strings[args[0]]=args[1];return applied();}
 if(op==='buffernumberstring'){state.strings[args[0]]=String(v(1));return applied();}
 if(op==='bufferitemname'||op==='buffermovename'||op==='bufferspeciesname'){state.strings[args[0]]=args[1].replace(/^(ITEM|MOVE|SPECIES)_/,'').replaceAll('_',' ');return applied();}
 if(op==='bufferpartymonnick')return effect('buffer-party-name',{destination:args[0],index:v(1)});
 if(op==='getplayerxy'){state.vars[args[0]]=state.x;state.vars[args[1]]=state.y;return applied();}
 if(op==='opendoor'||op==='closedoor'||op==='setdooropen'||op==='setdoorclosed')return effect('door-animation',{x:v(0),y:v(1),open:op==='opendoor'||op==='setdooropen'});
 if(op==='waitdooranim'||op==='waitfieldeffect')return applied();
 if(op==='setberrytree')return effect('set-berry-tree',{tree:args[0],berry:args[1],stage:args[2]});
 if(op==='givemon'||op==='giveegg')return effect('give-pokemon',{species:args[0],level:op==='giveegg'?1:v(1),held:args[2],egg:op==='giveegg'});
 if(op==='pokemart'||op==='pokemartdecoration')return effect('shop',{stock:args[0]});
 if(op==='dofieldeffect')return effect('field-effect',{name:args[0]});
 if(['doweather','fadescreen','fadescreenspeed','setfieldeffectargument','setmaplayoutindex','showmapname','setmapflag'].includes(op))return effect(op,{args});
 return unsupported(op);
}
export function applyEmeraldSpecial(state:EmeraldWorldState,name:string,args:string[]=[],context:EmeraldMechanicContext={}):EmeraldMechanicResult{
 const resolve=context.resolve||((s:string)=>state.vars[s]??context.constants?.[s]??(Number(s)||0));const value=(key:string)=>resolve(key);const map=context.maps?.[state.map];
 const berryTree=()=>{
  updateEmeraldBerryGrowth(state,context.now?.getTime()??Date.now());
  const selected=state.vars.VAR_LAST_TALKED??state.vars.VAR_0x800B;const npc=map?.npcs?.find(n=>n.localId===selected);const key=npc?.trainer_sight_or_berry_tree_id;if(!key)return;
  const sourceKey=Object.keys(state.berries||{}).find(k=>k===key||(context.constants?.[k]!==undefined&&context.constants[k]===resolve(key)))||key;
  const trees=state.berryTrees??={};if(!trees[sourceKey]){const initial=state.berries?.[sourceKey];const item=initial?.item||'';const stage=initial?resolve(initial.stage):0;trees[sourceKey]={item,stage,watered:0,yield:stage===5?(berryInfo[item]?.[0]||0):0,seenAt:context.now?.getTime()??Date.now(),regrowths:0};}
  return trees[sourceKey];
 };
 if(name==='InitSecretBaseDecorationSprites'){
  // secret_base.c: an empty new-game decoration array spawns nothing. Saved
  // entries contain the canonical resolved permission/graphics and packed position.
  const layouts=state.nativeState?.decorationLayouts as Record<string,{permission:string;position:number;graphics:number}[]>|undefined;
  const entries=layouts?.[state.map]||[];let index=state.vars.VAR_0x8004||0;
  for(const entry of entries){if(entry.permission!=='DECORPERM_SPRITE')continue;if(!map)return unsupported(`${name} (map required for saved decorations)`);
   const npc=map.npcs?.find(n=>(n.flag||n.flag_id)===`FLAG_DECORATION_${index+1}`);if(!npc)continue;
   const x=entry.position>>4,y=entry.position&15,cell=emeraldCell(state,map,x,y);
   if(cell.behavior!==context.constants?.MB_HOLDS_SMALL_DECORATION&&cell.behavior!==context.constants?.MB_HOLDS_LARGE_DECORATION)continue;
   const variable=npc.graphics_id?.match(/^OBJ_EVENT_GFX_VAR_(\d+)$/);if(!variable)return unsupported(`${name} (decoration object graphics is not dynamic)`);
   state.vars[`VAR_OBJ_GFX_ID_${Number(variable[1]).toString(16).toUpperCase()}`]=entry.graphics;
   state.flags[`FLAG_DECORATION_${index+1}`]=false;state.objects[emeraldObjectKey(state.map,npc.localId)]={...state.objects[emeraldObjectKey(state.map,npc.localId)],x,y,hidden:false};
   state.vars.VAR_0x8006=x;state.vars.VAR_0x8007=y;state.vars.VAR_RESULT=npc.localId;index++;
  }state.vars.VAR_0x8004=index;return applied();
 }
 if(name==='TurnOffTVScreen'||name==='TurnOnTVScreen'){
  if(!map)return unsupported(`${name} (map not provided)`);const television=context.constants?.MB_TELEVISION;
  const id=context.constants?.[name==='TurnOnTVScreen'?'METATILE_Building_TV_On':'METATILE_Building_TV_Off'];
  if(television===undefined||id===undefined)return unsupported(`${name} (canonical metatile constants missing)`);
  for(let y=0;y<map.height;y++)for(let x=0;x<map.width;x++)if(emeraldCell(state,map,x,y).behavior===television)state.metatiles[emeraldTileKey(state.map,x,y)]={id,collision:3};
  return applied();
 }
 if(name==='PlayerHasBerries')return applied(Object.entries(state.inventory).some(([item,n])=>n>0&&item.endsWith('_BERRY'))?1:0);
 if(name==='Bag_ChooseBerry')return effect('choose-berry');
 if(name==='ObjectEventInteractionGetBerryTreeData'||name==='ObjectEventInteractionGetBerryName'||name==='ObjectEventInteractionGetBerryCountString'){
  const tree=berryTree();if(!tree)return unsupported(`${name} (selected object has no berry tree id)`);state.strings.STR_VAR_1=tree.item.replace(/^ITEM_/,'').replaceAll('_',' ');if(name==='ObjectEventInteractionGetBerryTreeData'){state.vars.VAR_0x8004=tree.stage;state.vars.VAR_0x8005=tree.watered.toString(2).replaceAll('0','').length;state.vars.VAR_0x8006=tree.yield;}return applied();
 }
 if(name==='ObjectEventInteractionPickBerryTree'){const tree=berryTree();if(!tree)return unsupported(`${name} (missing tree)`);state.inventory[tree.item]=(state.inventory[tree.item]||0)+tree.yield;state.vars.VAR_0x8004=1;return applied();}
 if(name==='ObjectEventInteractionPlantBerryTree'){const tree=berryTree();if(!tree)return unsupported(`${name} (missing tree)`);const item=Object.keys(berryInfo).find(item=>context.constants?.[item]===state.vars.VAR_ITEM_ID);if(!item)return unsupported(`${name} (selected berry item is invalid)`);Object.assign(tree,{item,stage:1,watered:0,yield:0,regrowths:0,seenAt:context.now?.getTime()??Date.now()});state.vars.VAR_0x8004=1;return applied();}
 if(name==='ObjectEventInteractionRemoveBerryTree'){const tree=berryTree();if(!tree)return unsupported(`${name} (missing tree)`);Object.assign(tree,{item:'',stage:0,watered:0,yield:0,regrowths:0});return applied();}
 if(name==='ObjectEventInteractionWaterBerryTree'){const tree=berryTree();if(!tree)return unsupported(`${name} (missing tree)`);if(tree.stage>=1&&tree.stage<=4)tree.watered|=1<<(tree.stage-1);return applied(tree.stage>=1&&tree.stage<=4?1:0);}
 if(name==='IncrementDailyPickedBerries'){const native=state.nativeState??={};native.dailyPickedBerries=Number(native.dailyPickedBerries||0)+1;return applied();}
 // Expanded roster keeps its real national species in state.starter. Emerald's
 // rival branches still need the canonical grass/fire/water representative.
 const internalStarter=()=>{const selected=[252,255,258].includes(state.starter||0)?state.starter!:[252,255,258][state.vars.VAR_STARTER_MON||0];const symbol=({252:'SPECIES_TREECKO',255:'SPECIES_TORCHIC',258:'SPECIES_MUDKIP'} as Record<number,string>)[selected];return context.constants?.[symbol]??({252:277,255:280,258:283} as Record<number,number>)[selected];};
 if(name==='ChooseStarter')return effect('choose-starter',{species:[252,255,258],level:5});
 // script_pokemon_util.c: selection returns FALSE on cancellation; party reduction
 // follows the explicitly chosen one-based order, never a fabricated automatic team.
 if(name==='ChooseHalfPartyForBattle'){state.vars.VAR_FRONTIER_FACILITY=context.constants?.FACILITY_MULTI_OR_EREADER??9;return effect('choose-half-party',{max:3,minimum:3});}
 if(name==='ReducePlayerPartyToSelectedMons'){const order=state.nativeState?.selectedPartyOrder;if(!Array.isArray(order)||!order.length)return unsupported(`${name} (party selection has not completed)`);return effect('reduce-party',{indices:order.map(n=>Number(n)-1)});}
 if(name==='BedroomPC')return effect('bedroom-pc');
 if(name==='ScriptMenu_CreatePCMultichoice'){state.vars.VAR_RESULT=255;return effect('pc-menu',{options:[state.flags.FLAG_SYS_PC_LANETTE?"LANETTE'S PC":"SOMEONE'S PC",`${state.playerName||'TRAINER'}'s PC`,...(state.flags.FLAG_SYS_GAME_CLEAR?['HALL OF FAME']:[]),'LOG OFF']});}
 if(name==='BattleSetup_StartLegendaryBattle')return effect('legendary-battle');
 if(name==='IsEnigmaBerryValid')return applied(state.nativeState?.enigmaBerryValid?1:0);
 if(name==='Script_TryGainNewFanFromCounter'){
  // field_specials.c fan counter occupies the low seven bits of VAR_FANCLUB_FAN_COUNTER.
  let packed=state.vars.VAR_FANCLUB_FAN_COUNTER||0;
  if(state.vars.VAR_LILYCOVE_FAN_CLUB_STATE===2){const increment=[2,1,2,1][state.vars.VAR_0x8004]||0;const counter=(packed&127)+increment;const fans=Array.from({length:8},(_,i)=>Boolean(packed&(1<<(i+8)))).filter(Boolean).length;
   if(counter>19&&fans<3){let selected=0;for(let i=0;i<8;i++)if(!(packed&(1<<(i+8)))){selected=i;if(emeraldRandom(state)>=.5)break;}packed|=1<<(selected+8);packed&=~127;}else packed=(packed&~127)|Math.min(counter,20);
   state.vars.VAR_FANCLUB_FAN_COUNTER=packed;
  }return applied(packed&127);
 }
 if(name==='InitBirchState'){state.vars.VAR_BIRCH_STATE=0;return applied();}
 if(name==='IsTrainerReadyForRematch'||name==='ShouldTryRematchBattle'){const rematch=state.rematches?.[state.activeTrainer||''];return applied(rematch?.ready||(name==='ShouldTryRematchBattle'&&rematch?.secondWon)?1:0);}
 if(name==='ShouldTryGetTrainerScript'){const native=state.nativeState??={};const remaining=Number(native.trainerReturnScripts||0);native.checkTrainerB=remaining>1;if(remaining>1)native.trainerReturnScripts=0;return applied(remaining>1?1:0);}
 if(name==='SetLilycoveLadyGfx'){state.trainerId??=Math.floor(emeraldRandom(state)*65536);const native=state.nativeState??={};const id=Number(native.lilycoveLadyId??((state.trainerId%6)>>1));native.lilycoveLadyId=id;state.vars.VAR_OBJ_GFX_ID_0=[26,20,10][id]||26;if(id===2){const category=Number(native.lilycoveLadyCategory||0);state.vars.VAR_OBJ_GFX_ID_1=[98,203,220,204,209][category]||98;}return applied(id===2?1:0);}
 if(name==='ShouldDistributeEonTicket')return applied(state.vars.VAR_DISTRIBUTE_EON_TICKET?1:0);
 if(name==='InitUnionRoom'){(state.nativeState??={}).unionRoom={players:[],status:'offline'};return applied();}
 if(name==='RunUnionRoom')return effect('offline-link-room');
 if(name==='IsWirelessContest')return applied(0);
 if(name==='GabbyAndTyGetBattleNum'){const n=state.gabbyBattleNum||0;return applied(n>5?n%3+6:n);}
 if(name==='UpdateCyclingRoadState'){if(state.previousMap!=='MAP_ROUTE110_SEASIDE_CYCLING_ROAD_NORTH_ENTRANCE'&&[2,3].includes(state.vars.VAR_CYCLING_CHALLENGE_STATE))state.vars.VAR_CYCLING_CHALLENGE_STATE=0;return applied();}
 if(name==='SetTrickHouseNuggetFlag'||name==='ResetTrickHouseNuggetFlag'){state.flags.FLAG_HIDDEN_ITEM_TRICK_HOUSE_NUGGET=name==='SetTrickHouseNuggetFlag';state.vars.VAR_0x8004=context.constants?.FLAG_HIDDEN_ITEM_TRICK_HOUSE_NUGGET??0;return applied();}
 if(name==='SetRoute119Weather'||name==='SetRoute123Weather'){if(!state.previousMap||!/MAP_ROUTE\d+$|MAP_.*_(CITY|TOWN)$/.test(state.previousMap))state.weather=name==='SetRoute119Weather'?'WEATHER_ROUTE119_CYCLE':'WEATHER_ROUTE123_CYCLE';return applied();}
 if(name==='SetMirageTowerVisibility'){state.flags.FLAG_MIRAGE_TOWER_VISIBLE=!state.vars.VAR_MIRAGE_TOWER_STATE&&(state.flags.FLAG_FORCE_MIRAGE_TOWER_VISIBLE||emeraldRandom(state)<.5);return applied();}
 if(name==='UpdateShoalTideFlag'){const hour=(context.now||new Date()).getHours();state.flags.FLAG_SYS_SHOAL_TIDE=hour<3||(hour>=9&&hour<15)||hour>=21;return applied();}
 if(name==='IsMirageIslandPresent'){state.mirageRandom??=Math.floor(emeraldRandom(state)*0x100000000);return applied(context.party?.some(p=>p.personality!==undefined&&(p.personality&65535)===(state.mirageRandom!>>>16))?1:0);}
 if(name==='StorePlayerCoordsInVars'){state.vars.VAR_0x8004=state.x;state.vars.VAR_0x8005=state.y;return applied();}
 if(name==='GetBattleOutcome')return applied(state.lastBattleOutcome??state.lastBattle??0);
 if(name==='IsStarterInParty')return applied(context.party?.some(p=>p.species===(state.starter??[252,255,258][state.vars.VAR_STARTER_MON||0]))?1:0);
 if(name==='ScriptGetPartyMonSpecies'){const n=context.party?.[state.vars.VAR_0x8004||0]?.species??0;return context.toInternalSpecies?applied(context.toInternalSpecies(n)):n<=251?applied(n):unsupported('ScriptGetPartyMonSpecies (national-to-internal converter required)');}
 if(name==='GetPlayerBigGuyGirlString'){state.strings.STR_VAR_1=state.gender?'big girl':'big guy';return applied();}
 if(name==='GetRivalSonDaughterString'){state.strings.STR_VAR_1=state.gender?'son':'daughter';return applied();}
 if(name==='GetWeekCount')return applied(Math.min(9999,Math.floor(((context.now?.getTime()??Date.now())-(state.clockStartedAt??Date.now()))/(86400000*7))));
 if(name==='SetMauvilleOldManObjEventGfx'){state.vars.VAR_OBJ_GFX_ID_0=context.constants?.OBJ_EVENT_GFX_BARD??69;return applied();}
 if(name==='ResetHealLocationFromDewford'){if(state.lastHeal.map==='MAP_DEWFORD_TOWN')state.lastHeal={map:'MAP_PETALBURG_CITY',x:20,y:16,facing:'down'};return applied();}
 if(name==='SwapRegisteredBike'){if(state.registeredItem==='ITEM_MACH_BIKE')state.registeredItem='ITEM_ACRO_BIKE';else if(state.registeredItem==='ITEM_ACRO_BIKE')state.registeredItem='ITEM_MACH_BIKE';return applied();}
 if(name==='GameClear'){state.flags.FLAG_SYS_GAME_CLEAR=true;state.flags.FLAG_SYS_RIBBON_GET=true;state.hallOfFameCount=(state.hallOfFameCount||0)+1;return effect('hall-of-fame',{heal:true,championRibbons:true,continueMap:state.gender?'MAP_LITTLEROOT_TOWN_MAYS_HOUSE_2F':'MAP_LITTLEROOT_TOWN_BRENDANS_HOUSE_2F'});}
 if(name==='SetCB2WhiteOut')return effect('white-out',{to:state.lastHeal});
 if(name==='PetalburgGymUnlockRoomDoors'||name==='PetalburgGymSlideOpenRoomDoors'){
  const rooms:Record<number,[number,number][]>= {1:[[1,104],[7,104]],2:[[1,78],[7,78]],3:[[1,91],[7,91]],4:[[7,39]],5:[[1,52],[7,52]],6:[[1,65]],7:[[7,13]],8:[[1,26]]};
  for(const [x,y]of rooms[state.vars.VAR_0x8004]||[]){state.metatiles[emeraldTileKey(state.map,x,y)]={id:0x21c,collision:1};state.metatiles[emeraldTileKey(state.map,x,y+1)]={id:0x224,collision:1};}return applied();
 }
 if(name==='DoSpecialTrainerBattle')return effect('special-battle',{mode:state.vars.VAR_0x8004});
 if(name==='StartWallyTutorialBattle')return effect('wally-tutorial-battle',{playerSpecies:263,playerLevel:7,wildSpecies:280,wildLevel:5});
 if(name==='LoadWallyZigzagoon')return effect('temporary-party',{species:263,level:7,moves:['MOVE_TACKLE']});
 if(name==='SavePlayerParty')return effect('save-party');
 if(name==='LoadPlayerParty')return effect('restore-party');
 if(name==='Script_DoRayquazaScene')return effect('rayquaza-scene',{scene:state.vars.VAR_0x8004});
 if(name==='OpenPokenavForTutorial'||name==='ScriptMenu_CreateStartMenuForPokenavTutorial')return effect('pokenav-tutorial');
 if(name==='ShowFieldMessageStringVar4')return effect('message',{text:state.strings.STR_VAR_4||''});
 if(name==='BufferTMHMMoveName')return effect('buffer-tm-hm',{item:state.vars.VAR_0x8004});
 if(name==='BufferMonNickname')return effect('buffer-party-name',{destination:'STR_VAR_1',index:state.vars.VAR_0x8004||0});
 if(['DrawWholeMapView','WaitWeather','PlayerFaceTrainerAfterBattle','DoPCTurnOnEffect','DoPCTurnOffEffect','SpawnCameraObject','RemoveCameraObject','ShakeCamera','Script_FadeOutMapMusic','DoOrbEffect','FadeOutOrbEffect'].includes(name))return effect('presentation',{name,args,values:{...state.vars}});
 if(name==='HealPlayerParty')return effect('heal-party');
 if(name==='IsPokerusInParty')return applied(context.party?.some(p=>p.pokerus)?1:0);
 if(name==='GetPlayerAvatarBike')return applied(state.bike==='acro'?1:state.bike==='mach'?2:0);
 if(name==='IsTrainerRegistered')return applied((state.nativeState?.registeredTrainers as Record<string,boolean>|undefined)?.[String(state.vars.VAR_0x8004)]?1:0);
 if(name==='CableCar')return effect('cable-car',{to:state.dynamicWarps.cableCar});
 if(name==='CalculatePlayerPartyCount'||name==='CountPartyNonEggMons')return applied(context.party?.length??0);
 if(name==='CountPartyAliveNonEggMons_IgnoreVar0x8004Slot')return applied(context.party?.filter((p,i)=>i!==state.vars.VAR_0x8004&&(p.hp===undefined||p.hp>0)).length??0);
 if(name==='ChoosePartyMon'||name==='ChangePokemonNickname')return effect('choose-party',{purpose:name});
 if(name==='Special_ViewWallClock')return effect('view-clock');
 if(name==='SetCurrentBox')return effect('set-storage-box',{box:state.vars.VAR_0x8004});
 if(name==='ScriptGetPokedexInfo')return effect('pokedex-counts');
 if(name==='ShowPokedexRatingMessage')return effect('pokedex-rating');
 if(name==='AccessHallOfFamePC')return effect('hall-of-fame-records');
 if(name==='CableCarWarp'){state.dynamicWarps.cableCar={map:state.vars.VAR_0x8004?'MAP_ROUTE112_CABLE_CAR_STATION':'MAP_MT_CHIMNEY_CABLE_CAR_STATION',x:6,y:4,facing:state.facing};return applied();}
 if(name==='SubtractMoneyFromVar0x8005'){state.money=Math.max(0,state.money-(state.vars.VAR_0x8005||0));return applied();}
 if(name==='SetUnlockedPokedexFlags'){state.flags.FLAG_SYS_POKEDEX_GET=true;return applied();}
 if(name==='EnableNationalPokedex'){state.flags.FLAG_SYS_NATIONAL_DEX=true;return applied();}
 if(name==='CountPlayerTrainerStars')return applied(state.flags.FLAG_SYS_GAME_CLEAR?1:0);
 if(name==='PlayerNotAtTrainerHillEntrance')return applied(state.map==='MAP_TRAINER_HILL_ENTRANCE'?0:1);
 if(name==='HasEnoughMonsForDoubleBattle')return applied((context.party?.filter(p=>p.hp===undefined||p.hp>0).length||0)>=2?1:0);
 if(name==='GetPlayerFacingDirection')return applied(({down:1,up:2,left:3,right:4})[state.facing]);
 if(name==='GetPlayerCoords'){state.vars.VAR_0x8004=state.x;state.vars.VAR_0x8005=state.y;return applied();}
 if(name==='GetStarterPokemon')return applied(internalStarter());
 if(name==='ShowPokemonStorageSystemPC')return effect('storage');
 if(name==='ShowEasyChatScreen')return effect('easy-chat');
 if(name==='DoNamingScreen')return effect('name',{target:state.vars.VAR_0x8004});
 if(name==='ShowDiploma')return effect('diploma');
 if(name==='DoHallOfFameScreen'||name==='EnterHallOfFame'){state.flags.FLAG_SYS_GAME_CLEAR=true;return effect('hall-of-fame');}
 if(name==='DoSoftReset')return effect('return-title');
 if(name==='DoTimeBasedEvents')return effect('clock-events');
 if(name==='StartWallClock'){state.clockStartedAt??=context.now?.getTime()??Date.now();return effect('set-clock');}
 if(name==='GetTimeOfDay'){const h=(context.now||new Date()).getHours();return applied(h>=4&&h<12?0:h>=12&&h<20?1:2);}
 if(name==='SetPlayerAvatarTransitionFlags')return effect('avatar-transition',{flags:state.vars.VAR_0x8004});
 if(name==='MauvilleGymPressSwitch'){[[0,15],[4,12],[3,9],[8,9]].forEach(([x,y],i)=>state.metatiles[emeraldTileKey(state.map,x,y)]={id:i===state.vars.VAR_0x8004?0x206:0x205,collision:0});return applied();}
 if(name==='MauvilleGymSetDefaultBarriers'||name==='MauvilleGymDeactivatePuzzle'){
  if(!map)return unsupported(`${name} (map not provided)`);const off:Record<number,number>={0x220:0x230,0x221:0x231,0x228:0x238,0x229:0x239,0x222:0x232,0x223:0x233,0x22a:0x23a,0x22b:0x23b,0x240:0x242,0x241:0x243,0x248:0x21a,0x249:0x21a,0x250:0x251};const reverse=Object.fromEntries(Object.entries(off).slice(0,8).map(([a,b])=>[b,Number(a)]));
  for(let y=5;y<17;y++)for(let x=0;x<9;x++){const old=emeraldCell(state,map,x,y).id;let id=off[old];if(name==='MauvilleGymSetDefaultBarriers'){
   if(reverse[old]!==undefined)id=reverse[old];
   if(old===0x242)id=0x240;if(old===0x243)id=0x241;if(old===0x251)id=0x250;if(old===0x250)id=0x251;
   if(old===0x21a)id=emeraldCell(state,map,x,y-1).id===0x240?0x248:0x249;
  }
  if(id!==undefined)state.metatiles[emeraldTileKey(state.map,x,y)]={id,collision:[0x228,0x229,0x22a,0x22b,0x242,0x243,0x240,0x241,0x248,0x249,0x250].includes(id)?1:0};}
  if(name==='MauvilleGymDeactivatePuzzle')[[0,15],[4,12],[3,9],[8,9]].forEach(([x,y])=>state.metatiles[emeraldTileKey(state.map,x,y)]={id:0x206,collision:0});return applied();
 }
 if(name==='SetSootopolisGymCrackedIceMetatiles'){const rows:Record<number,string>={6:'1',7:'2',8:'3',9:'4',12:'5',13:'6',14:'7',17:'8',18:'9',19:'A'};for(const [row,n]of Object.entries(rows))for(let x=3;x<=13;x++)if((state.vars[`VAR_TEMP_${n}`]||0)&(1<<(x-3)))state.metatiles[emeraldTileKey(state.map,x,Number(row))]={id:0x20e,collision:0};return applied();}
 if(name==='RotatingGate_InitPuzzle'||name==='RotatingGate_InitPuzzleAndGraphics'){if(name==='RotatingGate_InitPuzzle')gateConfig(state.map).forEach((g,i)=>setGateOrientation(state,i,g[3]));return applied();}
 if(name==='BufferUnionRoomPlayerName'){return applied(0);}
 if(name==='GetPartyMonSpecies'){const n=context.party?.[value('VAR_0x8004')]?.species??0;return context.toInternalSpecies?applied(context.toInternalSpecies(n)):n<=251?applied(n):unsupported('GetPartyMonSpecies (national-to-internal converter required)');}
 if(name==='GetPartyMonLevel')return applied(context.party?.[value('VAR_0x8004')]?.level??0);
 return unsupported(name);
}
