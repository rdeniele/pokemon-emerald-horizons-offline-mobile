'use client';

import {useEffect,useRef,useState} from 'react';

import importedWorld from '@/data/emerald-world.generated.json';

import importedEvents from '@/data/emerald-events.generated.json';

import {createEmeraldSession,runEmeraldScript,resumeEmeraldSession,emeraldEvents,emeraldRandom,emeraldText,type EmeraldSession,type EmeraldInstruction} from '@/offline/emerald-script-vm';

import {createEmeraldWorldState,emeraldObjectKey,emeraldTileKey,type EmeraldWorldState,type EmeraldDirection} from '@/offline/emerald-state';

import {applyEmeraldAction,applyEmeraldSpecial,tryEmeraldStep,emeraldCell,fieldMovePermission,updateEmeraldBerryGrowth,emeraldRotatingGates} from '@/offline/emerald-mechanics';

import {E,SPECIES,type Mon} from '@/offline/model';

import {createBattleRequest,nationalSpeciesId,emeraldWildProfile,scriptsForMap,frameTableScripts,internalSpeciesId} from '@/offline/emerald-content';

import {getEmpressSprite} from '@/pokemon/sprites/resolver';

import {useEmeraldFieldItem,emeraldRepelBlocks,normalizeEmeraldFieldMove} from '@/offline/emerald-items';
import './emerald-world.css';



const world=importedWorld as any,maps=world.maps as Record<string,any>,db=emeraldEvents;

for(const map of Object.values(maps) as any[])map.metatileAttributes=world.atlases[map.render.atlasId]?.attributes;

const directions:Record<EmeraldDirection,[number,number]>={up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]};

const facingFrame={down:0,up:1,left:2,right:2};

export type EmeraldBattleRequest={wild:boolean;title:string;team:{species:number;level:number}[];trainerId?:string;gymIndex?:number;resumeLabel?:string;catchable?:boolean;tutorial?:boolean;rewardMoney?:number;defeatLabel?:string;partyIndices?:number[]};

type RuntimeState=EmeraldWorldState&{pendingUi?:{text:string;label:string;yesno?:boolean};externalService?:string;lastBattle?:number;pendingWild?:{species:number;level:number};lastWarp?:string;entered?:boolean;initialised?:boolean};

type Props={progress?:EmeraldWorldState;party:Mon[];gold:number;inventory:Record<string,number>;cleared:number[];onSave:(p:EmeraldWorldState)=>void;onBattle:(request:EmeraldBattleRequest,p:EmeraldWorldState)=>void;onParty:()=>void;onLeave:()=>void;onGive:(id:number,level:number)=>void;onStarter?:(id:number)=>void;suspended?:boolean;onMenu?:(section:'party'|'pokedex'|'trainer'|'options')=>void;onTeach:(index:number,move:string,slot:number)=>void};

type Modal={kind:'dialogue'|'menu'|'bag'|'shop'|'clock'|'starter'|'teach'|'blocked'|'berry'|'half-party'|'fly';title:string;text?:string;choices?:{label:string;value:number}[];stock?:string[];move?:string};

function displayName(name:string){return name.replace(/^MAP_/,'').replaceAll('_',' ').toLowerCase().replace(/\b\w/g,c=>c.toUpperCase());}

function constantsName(prefix:string,value:number){return Object.keys(db.constants).find(k=>k.startsWith(prefix)&&db.constants[k]===value);}

function initialState(props:Props):RuntimeState{const s=(props.progress?structuredClone(props.progress):createEmeraldWorldState()) as RuntimeState;s.money=props.gold;s.starter??=props.party[0]?.species;for(const [canonical,local]of Object.entries({ITEM_POKE_BALL:'poke',ITEM_GREAT_BALL:'great',ITEM_ULTRA_BALL:'ultra',ITEM_POTION:'potion',ITEM_REVIVE:'revive'}))s.inventory[canonical]=props.inventory[local]||0;return s;}



export default function EmeraldWorld(props:Props){

 const state=useRef<RuntimeState>(initialState(props)),callbacks=useRef(props),canvas=useRef<HTMLCanvasElement>(null),input=useRef({x:0,y:0}),keys=useRef(new Set<string>()),busy=useRef(false),alive=useRef(true),entering=useRef(false),pendingService=useRef<EmeraldInstruction|undefined>(undefined),running=useRef(false),modalRef=useRef<Modal|null>(null),answer=useRef<((value:number)=>void)|null>(null),interact=useRef(()=>{}),stepEvent=useRef<()=>Promise<void>>(async()=>{}),run=useRef<(label?:string)=>Promise<void>>(async()=>{});

 callbacks.current=props;

 const [view,setView]=useState({map:state.current.map,money:state.current.money}),[modal,setModalState]=useState<Modal|null>(null),[near,setNear]=useState('Talk'),[error,setError]=useState(''),[time,setTime]=useState('12:00'),[selectedParty,setSelectedParty]=useState<number[]>([]);

 const setModal=(value:Modal|null)=>{modalRef.current=value;setModalState(value);};

 const persist=()=>{if(!alive.current)return;const saved=structuredClone(state.current);if(pendingService.current&&saved.session&&!saved.session.pending&&db.instructions[saved.session.pc-1]?.op===pendingService.current.op)saved.session.pc--;callbacks.current.onSave(saved);};

 const redraw=()=>setView({map:state.current.map,money:state.current.money});

 const getMap=()=>maps[state.current.map];

 const resolve=(symbol:string):number=>{const m=getMap();const object=m?.npcs?.find((n:any)=>n.local_id===symbol);return object?.localId??(symbol.startsWith('VAR_')?(state.current.vars[symbol]??0):db.constants[symbol]??(Number.isFinite(Number(symbol))?Number(symbol):0));};

 const visible=()=>{const m=getMap();return(m?.npcs||[]).filter((n:any)=>{const o=state.current.objects[emeraldObjectKey(state.current.map,n.localId)]??state.current.objects[emeraldObjectKey(state.current.map,n.local_id)];return !o?.hidden&&!(n.flag&&n.flag!=='0'&&state.current.flags[n.flag]);}).map((n:any)=>({...n,...(state.current.objects[emeraldObjectKey(state.current.map,n.localId)]||{}),facing:state.current.objects[emeraldObjectKey(state.current.map,n.localId)]?.facing||n.facing}));};

 const close=(value=0)=>{setModal(null);const fn=answer.current;answer.current=null;fn?.(value);};

 const prompt=(title:string,text:string,choices=[{label:'Continue',value:0}])=>new Promise<number>(done=>{answer.current=done;setModal({kind:'dialogue',title,text,choices});});

 const say=async(text:string,label:string,yesno=false)=>{const s=state.current;const cleaned=text.replace(/\{(STR_VAR_[123])\}/g,(_,key)=>s.strings[key]||'POKéMON').replace(/\{PLAYER\}/g,s.playerName||'TRAINER').replace(/\{RIVAL\}/g,s.rivalName||'MAY').replace(/\{[^}]+\}/g,'').replace(/\\[nl]/g,' ').replace(/\\p/g,'\n\n').replace(/\$$/,'');s.pendingUi={text:cleaned,label,yesno};persist();const selected=await prompt('Hoenn',cleaned,yesno?[{label:'Yes',value:1},{label:'No',value:0}]:[{label:'Continue',value:0}]);delete s.pendingUi;if(yesno)s.vars.VAR_RESULT=selected;persist();return selected;};

 const fail=(op:string,args:string[])=>{const session=state.current.session;if(session&&db.instructions[session.pc-1]?.op===op)session.pc--;const text=`This event needs an Emerald handler: ${op} ${args.join(', ')}. Your location and script are saved.`;setError(text);throw Error(text);};

 const mapScripts=(type:string)=>[...String(getMap()?.scripts||'').matchAll(/^\s*map_script\s+(\w+),\s*(\w+)/gm)].filter(m=>m[1]===type).map(m=>m[2]);

 const tableLabel=(label:string)=>{const body=String(getMap()?.scripts||'').split(new RegExp('^'+label+':{1,2}\\s*$','m'))[1]?.split(/^\w+:{1,2}\s*$/m)[0]||'';return[...body.matchAll(/map_script_2\s+(\w+),\s*(\w+),\s*(\w+)/g)].find(m=>resolve(m[1])===resolve(m[2]))?.[3];};

 const enter=async(load=true)=>{if(entering.current)return;entering.current=true;const s=state.current;redraw();try{if(load)for(const type of ['MAP_SCRIPT_ON_LOAD','MAP_SCRIPT_ON_TRANSITION','MAP_SCRIPT_ON_RESUME'])for(const label of mapScripts(type)){await run.current(label);if(s.session||!alive.current)return;}for(const label of frameTableScripts(s.map,s,'MAP_SCRIPT_ON_WARP_INTO_MAP_TABLE')){await run.current(label);if(s.session)return;}s.entered=true;persist();}finally{entering.current=false;}};

 const warp=async(op:string,args:string[])=>{const s=state.current;let target=args[0],x=0,y=0;const old={map:s.map,x:s.x,y:s.y,facing:s.facing};if(op==='warpdynamic'||target==='MAP_DYNAMIC'){const d=s.dynamicWarps.dynamic;if(!d)return fail(op,args);target=d.map;x=d.x;y=d.y;}else if(op==='warpteleport'||op==='warp'||op==='warpdoor'||op==='warpsilent'||op==='warphole'||op==='warpwhitefade'||op==='warpblackfade'){const m=maps[target];if(!m)return fail(op,args);if(op==='warphole'){x=s.x;y=s.y;}else if(args.length>=4){x=resolve(args[2]);y=resolve(args[3]);}else if(args.length===3){x=resolve(args[1]);y=resolve(args[2]);}else{const w=m.warps?.[resolve(args[1]||'0')];x=w?.x??Math.floor(m.width/2);y=w?.y??Math.floor(m.height/2);}}else return fail(op,args);if(!maps[target])return fail(op,args);s.dynamicWarps.previous=old;s.previousMap=old.map;if(maps[target].allow_escaping&&!getMap().allow_escaping)s.dynamicWarps.escape=old;if(old.map!==target){for(const key of Object.keys(s.vars))if(key.startsWith('VAR_TEMP_'))delete s.vars[key];s.strength=false;}s.map=target;s.x=x;s.y=y;s.lastWarp=`${target}:${x},${y}`;s.entered=false;redraw();persist();return 1;};

 const doMove=async(op:string,args:string[])=>{const s=state.current,m=getMap();const id=args[0]==='LOCALID_PLAYER'||args[0]==='PLAYER'?255:resolve(args[0]);if(/apply.*movement/.test(op)){const sequence=db.movements[args[1]];if(!sequence)return fail(op,args);const target=id===255?s:(s.objects[emeraldObjectKey(s.map,id)]??={x:m.npcs?.find((n:any)=>n.localId===id)?.x||0,y:m.npcs?.find((n:any)=>n.localId===id)?.y||0});for(const item of sequence){const match=item.op.match(/(?:walk|run|jump|slide|face|step|ride_water_current|slow_walk|fast_walk|walk_in_place).*_(up|down|left|right|north|south|west|east)$/);if(match){const dir=({north:'up',south:'down',west:'left',east:'right'} as Record<string,string>)[match[1]]||match[1];target.facing=dir as EmeraldDirection;if(!item.op.startsWith('face_')&&!item.op.includes('in_place')){const [dx,dy]=directions[dir as EmeraldDirection];target.x=(target.x||0)+dx;target.y=(target.y||0)+dy;}}}persist();return;}if(id===255&&['setobjectxy','setobjectxyperm'].includes(op)){s.x=resolve(args[1]);s.y=resolve(args[2]);return;}const normalized=[String(id),...args.slice(1)];const result=applyEmeraldAction(s,op,normalized,resolve);if(!result.handled)return fail(op,args);};

 const battleImpl=async(op:string,args:string[])=>{const s=state.current;if(op==='setwildbattle'){s.pendingWild={species:nationalSpeciesId(args[0])||resolve(args[0]),level:resolve(args[1])};return;}let request:EmeraldBattleRequest;if(op.startsWith('trainerbattle')){const parsed=createBattleRequest(op,args,s);if(parsed.trainer&&s.trainerFlags[parsed.trainer])return 1;if(parsed.intro&&db.texts[parsed.intro])await say(emeraldText(parsed.intro,s),parsed.intro);request={wild:false,title:parsed.name,trainerId:parsed.trainer,team:parsed.team,gymIndex:parsed.gymIndex,resumeLabel:parsed.after,rewardMoney:parsed.rewardMoney,defeatLabel:parsed.defeat};}else{const mon=s.pendingWild||{species:263,level:2};request={wild:true,title:'Wild '+(SPECIES[mon.species]?.name||'Pokémon'),team:[mon],catchable:!!s.flags.FLAG_SYS_POKEDEX_GET};delete s.pendingWild;}s.session!.pending={op,args};(s as any).battleRequest=request;persist();callbacks.current.onBattle(request,structuredClone(s));return{wait:true};};

 const battle=async(op:string,args:string[]):Promise<any>=>{pendingService.current={op,args};persist();try{return await battleImpl(op,args);}finally{pendingService.current=undefined;persist();}};
 const nativeImpl=async(op:string,args:string[]):Promise<any>=>{const s=state.current;const name=op==='specialvar'?args[1]:args[0];const result=op==='special'||op==='specialvar'?applyEmeraldSpecial(s,name,args,{resolve,maps,constants:db.constants,party:callbacks.current.party,toInternalSpecies:internalSpeciesId}):applyEmeraldAction(s,op,args,resolve);if(!result.handled)return fail(op,args);const fx=result.effect;if(!fx)return result.result;

  if(fx.kind==='heal-party'){s.lastHeal={map:s.map,x:s.x,y:s.y,facing:s.facing};return 1;}

  if(fx.kind==='set-respawn'){const heal=(importedEvents.healLocations as any[]).find(h=>h.id===fx.healLocation||db.constants[h.id]===Number(fx.healLocation));if(!heal)return fail(op,args);s.lastHeal={map:heal.map,x:heal.x,y:heal.y,facing:'down'};return 1;}

  if(fx.kind==='choose-starter'){const chosen=await new Promise<number>(done=>{answer.current=done;setModal({kind:'starter',title:"Birch's bag",text:'Choose a Pokémon to help Professor Birch.'});});if(callbacks.current.onStarter)callbacks.current.onStarter(chosen);else callbacks.current.onGive(chosen,5);s.starter=chosen;const type=SPECIES[chosen]?.types[0]||'grass';s.vars.VAR_RESULT=type==='fire'?1:type==='water'?2:0;s.vars.VAR_STARTER_MON=s.vars.VAR_RESULT;s.flags.FLAG_SYS_POKEMON_GET=true;s.pendingWild={species:263,level:2};return battle('dowildbattle',[]);}

  if(fx.kind==='storage'||fx.kind==='bedroom-pc'){s.externalService='party';s.session!.pending={op,args};persist();callbacks.current.onParty();return{wait:true};}

  if(fx.kind==='give-pokemon'){const species=nationalSpeciesId(String(fx.species))||resolve(String(fx.species)),level=Number(fx.level)||5;callbacks.current.onGive(species,level);await say(`Received ${SPECIES[species]?.name||'a Pokémon'}!`,'Gift');return 1;}

  if(fx.kind==='shop'){const at=db.labels[String(fx.stock)],stock:string[]=[];if(at!==undefined)for(let i=at;i<Math.min(at+100,db.instructions.length);i++){const instruction=db.instructions[i];if(instruction.args.includes('ITEM_NONE'))break;for(const item of instruction.args)if(item.startsWith('ITEM_'))stock.push(item);}await new Promise<number>(done=>{answer.current=done;setModal({kind:'shop',title:'Poké Mart',stock:(importedEvents as any).shops?.[String(fx.stock)]||stock});});return 1;}

  if(fx.kind==='set-clock'){await new Promise<number>(done=>{answer.current=done;setModal({kind:'clock',title:'Set the clock'});});return 1;}

  if(fx.kind==='field-effect'){const field=String(fx.name);if(field.includes('SURF'))s.surfing=true;if(field.includes('DIVE'))s.diving=!s.diving;if(field.includes('STRENGTH'))s.strength=true;if(field.includes('FLASH'))s.flashLevel=0;return 1;}

  if(fx.kind==='buffer-party-name'){s.strings[String(fx.destination)]=SPECIES[callbacks.current.party[Number(fx.index)]?.species]?.name||'POKéMON';return 1;}

  if(fx.kind==='hall-of-fame'){s.flags.FLAG_SYS_GAME_CLEAR=true;const records=(s.nativeState??={});const entries=(records.hallOfFameRecords as unknown[]||[]);records.hallOfFameRecords=[...entries,{player:s.playerName,party:callbacks.current.party.map(p=>({species:p.species,level:p.level})),date:Date.now()}];await say('Your Pokémon are entered in the Hall of Fame. Congratulations, Champion!','HallOfFame');if(fx.continueMap){await warp('warp',[String(fx.continueMap),'-1',String(s.lastHeal.x),String(s.lastHeal.y)]);s.facing='down';}return 1;}

  if(fx.kind==='clock-events'){updateEmeraldBerryGrowth(s);return 1;}

  if(fx.kind==='choose-berry'){const item=await new Promise<number>(done=>{answer.current=done;setModal({kind:'berry',title:'Choose a berry'});});s.vars.VAR_ITEM_ID=item;return item;}

  if(fx.kind==='find-item'){const item=String(fx.item),quantity=Number(fx.quantity)||1;s.inventory[item]=(s.inventory[item]||0)+quantity;const npc=getMap().npcs.find((n:any)=>n.localId===fx.object);if(npc){s.objects[emeraldObjectKey(s.map,npc.localId)]={hidden:true};if(npc.flag&&npc.flag!=='0')s.flags[npc.flag]=true;}persist();await say(`Found ${item.replace(/^ITEM_/,'').replaceAll('_',' ')}!`,'FoundItem');return 1;}

  if(fx.kind==='message'){await say(String(fx.text),'FieldMessage');return 1;}

  if(fx.kind==='view-clock'){await say(new Date().toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'}),'WallClock');return 1;}

  if(fx.kind==='pc-menu')return prompt('PC','Which PC should be accessed?',(fx.options as string[]).map((label,value)=>({label,value})));
  if(fx.kind==='buffer-tm-hm'){const item=constantsName('ITEM_',Number(fx.item))||'';s.strings.STR_VAR_1=item.replace(/^ITEM_/,'').replaceAll('_',' ');return 1;}

  if(fx.kind==='legendary-battle')return battle('dowildbattle',[]);

  if(fx.kind==='pokedex-counts'){s.vars.VAR_0x8005=new Set(callbacks.current.party.map(p=>p.species)).size;return 1;}

  if(fx.kind==='hall-of-fame-records'){const records=s.nativeState?.hallOfFameRecords as {party:{species:number;level:number}[]}[]||[];await say(records.length?records.map((entry,i)=>'Champion team '+(i+1)+': '+entry.party.map(p=>SPECIES[p.species].name+' Lv '+p.level).join(', ')).join('\n'):'No Hall of Fame records yet.','HallOfFamePC');return 1;}
  if(fx.kind==='pokedex-rating'){await say('Keep exploring Hoenn and adding Pokémon to your Pokédex!','PokedexRating');return 1;}

  if(fx.kind==='pokenav-tutorial'){await say('The PokéNav records your Trainer contacts, ribbons and Hoenn journey.','Pokenav');return 1;}

  if(fx.kind==='save-party'||fx.kind==='temporary-party'||fx.kind==='restore-party')return 1; // Wally uses a separate combat party, supplied by the battle shell.

  if(fx.kind==='wally-tutorial-battle'){const request:EmeraldBattleRequest={wild:true,tutorial:true,title:"Wally's first catch",team:[{species:280,level:5}],catchable:false};s.session!.pending={op,args};(s as any).battleRequest=request;persist();callbacks.current.onBattle(request,structuredClone(s));return{wait:true};}

  if(fx.kind==='rayquaza-scene'){await say('Rayquaza descends from the sky. Groudon and Kyogre cease their clash and retreat. The weather over Hoenn begins to clear.','RayquazaScene');s.weather='WEATHER_NONE';return 1;}

  if(fx.kind==='white-out'){Object.assign(s,s.lastHeal);s.entered=false;return 1;}

  if(fx.kind==='cable-car'){if(fx.to){Object.assign(s,fx.to);s.entered=false;return 1;}return fail(op,args);}

  if(fx.kind==='choose-half-party'){setSelectedParty([]);const result=await new Promise<number>(done=>{answer.current=done;setModal({kind:'half-party',title:'Choose three Pokémon'});});return result;}
  if(fx.kind==='reduce-party'||fx.kind==='save-selected-party')return 1; // External combat uses the selection without mutating the durable party.
  if(fx.kind==='special-battle'){if(Number(fx.mode)!==db.constants.SPECIAL_BATTLE_STEVEN)return fail(op,args);const trainers=['TRAINER_MAXIE_MOSSDEEP','TRAINER_TABITHA_MOSSDEEP'];const team=trainers.flatMap(id=>db.trainers[id].team.map(p=>({species:nationalSpeciesId(p.species),level:p.level})));const request:EmeraldBattleRequest={wild:false,title:'Steven & you · Maxie and Tabitha',team,partyIndices:(s.nativeState?.selectedPartyOrder as number[]||[]).map(n=>n-1)};s.session!.pending={op,args};(s as any).battleRequest=request;persist();callbacks.current.onBattle(request,structuredClone(s));return{wait:true};}
  if(fx.kind==='choose-party'){const choice=await prompt('Pokémon','Choose a party Pokémon.',callbacks.current.party.map((p,i)=>({label:SPECIES[p.species].name,value:i})));s.vars.VAR_0x8004=choice;return choice;}

  if(fx.kind==='offline-link-room'){await say('Link play requires another connected player. Your adventure continues offline.','LinkRoom');return 0;}

  if(['avatar-transition','doweather','fadescreen','fadescreenspeed','showmapname','setfieldeffectargument','setmapflag','rotating-gate-init','presentation','door-animation'].includes(fx.kind))return 1;

  return fail(op,args);

 };

 const native=async(op:string,args:string[]):Promise<any>=>{pendingService.current={op,args};persist();try{return await nativeImpl(op,args);}finally{pendingService.current=undefined;persist();}};
 const action=async(op:string,args:string[]):Promise<any>=>{const s=state.current;

  if(op==='checkpartymove'){const move=args[0].replace(/^MOVE_/,'').toLowerCase().replaceAll('_','');const i=callbacks.current.party.findIndex(p=>p.moves.some(m=>m.replaceAll('-','')===move));return i<0?6:i;}

  if(op==='getpartysize')return callbacks.current.party.length;

  if(op==='getpartymonlevel')return callbacks.current.party[resolve(args[0])]?.level||0;

  if(op==='setwildbattle'||op==='dowildbattle')return battle(op,args);

  if(op==='callstd'||op==='gotostd'){const id=resolve(args[0]);const labels=['EventScript_GiveItem','EventScript_FindItem','EventScript_TrainerBattle','EventScript_MsgboxNpc','EventScript_MsgboxSign','EventScript_MsgboxDefault','EventScript_MsgboxYesNo'];if(labels[id]&&db.labels[labels[id]]!==undefined){s.session!.stack.push(s.session!.pc);s.session!.pc=db.labels[labels[id]];return;}return fail(op,args);}

  if(op==='bufferleadmonspecies'){s.strings.STR_VAR_1=SPECIES[callbacks.current.party[0]?.species]?.name||'POKéMON';return 1;}

  if(['waitfieldeffect','waitdooranim','setdooropened','setdoorclosed','opendoor','closedoor','drawbox','erasebox','drawboxtext','textcolor','showcontestwinner','fieldeffectargument'].includes(op))return 1;

  return native(op,args);

 };

 run.current=async(label?:string)=>{const s=state.current;if(!alive.current)return;if(label)s.session=createEmeraldSession(label);if(!s.session||s.session.ended)return;busy.current=true;setError('');try{const result=await runEmeraldScript(s.session,s,{say:async(text,label)=>{const instruction=db.instructions[s.session!.pc-1],yesno=instruction?.args.includes('MSGBOX_YESNO');return say(text,label,yesno);},choice:async(op,args)=>{const instruction=db.instructions[s.session!.pc-1];if(instruction?.op==='msgbox')return s.vars.VAR_RESULT||0;if(op==='yesnobox')return prompt('Choose','What would you like to do?',[{label:'Yes',value:1},{label:'No',value:0}]);const key=args.find(a=>a.startsWith('MULTI_')),options=key?(importedEvents as any).choices?.[key]:undefined;if(!options)return fail(op,args);return prompt('Choose','Choose an option.',options.map((label:string,value:number)=>({label,value})).concat([{label:'Cancel',value:db.constants.MULTI_B_PRESSED||127}]));},battle,warp,move:doMove,service:native,action});if(result.status==='unsupported')fail(result.command!.op,result.command!.args);if(result.status==='budget')throw Error('This event reached its execution limit; the continuation is saved.');if(result.status==='ended')delete s.session;persist();redraw();}catch(e){if(alive.current){setError(e instanceof Error?e.message:String(e));persist();}}finally{busy.current=false;}};

 stepEvent.current=async()=>{const s=state.current,m=getMap();for(const c of m.coord_events||[])if(c.x===s.x&&c.y===s.y&&(c.type!=='trigger'||resolve(c.var)===resolve(String(c.var_value)))){await run.current(c.script);return;}for(const npc of visible()){if(!npc.trainer_type||npc.trainer_type==='TRAINER_TYPE_NONE')continue;const start=db.labels[npc.script];const instruction=start===undefined?undefined:db.instructions.slice(start,start+12).find(i=>i.op.startsWith('trainerbattle'));const trainer=instruction?.args.find(a=>a.startsWith('TRAINER_'));if(!trainer||s.trainerFlags[trainer])continue;const [dx,dy]=directions[npc.facing as EmeraldDirection]||[0,0];const distance=Math.abs(s.x-npc.x)+Math.abs(s.y-npc.y);if(!distance||distance>resolve(npc.trainer_sight_or_berry_tree_id)||(dx&&s.y!==npc.y)||(dy&&s.x!==npc.x)||(dx&&Math.sign(s.x-npc.x)!==dx)||(dy&&Math.sign(s.y-npc.y)!==dy))continue;let clear=true;for(let n=1;n<distance;n++)if(emeraldCell(s,m,npc.x+dx*n,npc.y+dy*n).collision){clear=false;break;}if(clear){s.vars.VAR_LAST_TALKED=npc.localId;s.activeTrainer=trainer;await run.current(npc.script);return;}}for(const table of mapScripts('MAP_SCRIPT_ON_FRAME_TABLE')){const label=tableLabel(table);if(label){await run.current(label);return;}}};

 interact.current=()=>{if(modalRef.current){if(modalRef.current.kind==='dialogue')close(0);return;}if(busy.current||entering.current||error)return;const s=state.current,[dx,dy]=directions[s.facing],x=s.x+dx,y=s.y+dy,npc=visible().find((n:any)=>n.x===x&&n.y===y);if(npc?.script&&db.labels[npc.script]!==undefined){s.vars.VAR_LAST_TALKED=npc.localId;s.vars.VAR_FACING=({down:1,up:2,left:3,right:4})[s.facing];void run.current(npc.script);return;}const sign=getMap().bg_events?.find((b:any)=>b.x===x&&b.y===y&&b.script);if(sign&&db.labels[sign.script]!==undefined){void run.current(sign.script);return;}const ch=emeraldCell(s,getMap(),x,y);if(ch.water&&!s.surfing){const permit=fieldMovePermission(s,'SURF',callbacks.current.party.flatMap(p=>p.moves));if(permit.allowed){void prompt('Surf','The water is calm. Surf here?',[{label:'Surf',value:1},{label:'Cancel',value:0}]).then(value=>{if(value){s.surfing=true;tryEmeraldStep(s,getMap(),s.facing,maps,world.behaviorNames);persist();}});return;}}void prompt(displayName(s.map),'There is nothing to interact with here.');};



 useEffect(()=>{alive.current=true;const init=async()=>{const s=state.current;if(!s.initialised){busy.current=true;s.session=createEmeraldSession('EventScript_ResetAllMapFlags');await run.current();await run.current('InsideOfTruck_EventScript_SetIntroFlags');s.initialised=true;s.entered=false;}if(s.externalService){delete s.externalService;if(s.session)resumeEmeraldSession(s.session,s,1);}if(s.pendingUi){const saved=s.pendingUi;await say(saved.text,saved.label,saved.yesno);if(s.session)resumeEmeraldSession(s.session,s);}if(s.session&&!s.session.ended&&!s.session.pending)await run.current();if(!s.session)await enter(!s.entered);};void init();return()=>{persist();alive.current=false;};},[]);

 useEffect(()=>{const s=state.current;if(!props.suspended&&s.externalService){delete s.externalService;if(s.session){resumeEmeraldSession(s.session,s,1);void run.current();}}},[props.suspended]);

 useEffect(()=>{const c=canvas.current,ctx=c?.getContext('2d');if(!c||!ctx)return;const images=new Map<string,HTMLImageElement>();const image=(src:string)=>{if(!images.has(src)){const im=new Image();im.src=src;images.set(src,im);if(images.size>80)images.delete(images.keys().next().value!);}return images.get(src)!;};const overlay=document.createElement('canvas');let overlayKey='';let raf=0,last=performance.now(),nextStep=0,lastSave=last,warpCooldown=0,encounterSteps=0,lastHint='',forcedDirection:EmeraldDirection|undefined;

  const stop=()=>{keys.current.clear();input.current={x:0,y:0};running.current=false;persist();};const down=(e:KeyboardEvent)=>{const k=e.key.toLowerCase();if(['arrowup','arrowdown','arrowleft','arrowright',' ','e','w','a','s','d','escape'].includes(k))e.preventDefault();keys.current.add(k);if(!e.repeat&&(k==='e'||k===' '))interact.current();if(!e.repeat&&k==='escape'&&!state.current.session&&!answer.current)setModal({kind:'menu',title:'START'});};const up=(e:KeyboardEvent)=>keys.current.delete(e.key.toLowerCase());window.addEventListener('keydown',down);window.addEventListener('keyup',up);window.addEventListener('blur',stop);window.addEventListener('emerald-pause',stop);window.addEventListener('pagehide',stop);const visibility=()=>{if(document.hidden)stop();};document.addEventListener('visibilitychange',visibility);

  const frame=(now:number)=>{if(!state.current.entered&&!callbacks.current.suspended&&!busy.current&&!entering.current&&!state.current.session){busy.current=true;void enter().finally(()=>busy.current=false);}if(state.current.entered&&!callbacks.current.suspended&&!busy.current&&!entering.current&&!state.current.session&&!modalRef.current){const label=frameTableScripts(state.current.map,state.current)[0];if(label)void run.current(label);}const dt=Math.min(.05,(now-last)/1000);last=now;const s=state.current,m=getMap();if(!m){raf=requestAnimationFrame(frame);return;}const vx=input.current.x+Number(keys.current.has('d')||keys.current.has('arrowright'))-Number(keys.current.has('a')||keys.current.has('arrowleft')),vy=input.current.y+Number(keys.current.has('s')||keys.current.has('arrowdown'))-Number(keys.current.has('w')||keys.current.has('arrowup'));if(!callbacks.current.suspended&&!busy.current&&!entering.current&&!state.current.session&&!modalRef.current&&!error&&!document.hidden&&now>=nextStep&&(forcedDirection||Math.abs(vx)>.25||Math.abs(vy)>.25)){const dir:EmeraldDirection=forcedDirection||(Math.abs(vx)>Math.abs(vy)?vx>0?'right':'left':vy>0?'down':'up');const result=tryEmeraldStep(s,m,dir,maps,world.behaviorNames);forcedDirection=result.moved?result.forced:undefined;nextStep=now+(s.bike!=='none'?80:s.flags.FLAG_SYS_B_DASH&&getMap().allow_running&&(running.current||keys.current.has('shift'))?95:160);if(result.moved){if(s.vars.VAR_REPEL_STEP_COUNT>0)s.vars.VAR_REPEL_STEP_COUNT--;encounterSteps++;if(result.connection){s.previousMap=m.id;for(const key of Object.keys(s.vars))if(key.startsWith('VAR_TEMP_'))delete s.vars[key];s.entered=false;void enter();}else{const warpTile=m.warps?.find((w:any)=>w.x===s.x&&w.y===s.y);const key=`${s.map}:${s.x},${s.y}`;if(warpTile&&now>warpCooldown&&key!==s.lastWarp){busy.current=true;warpCooldown=now+500;void warp('warp',[warpTile.to,String(warpTile.dest_warp_id)]).then(()=>enter()).finally(()=>busy.current=false);}else{if(key!==s.lastWarp)delete s.lastWarp;void stepEvent.current();const cell=emeraldCell(s,m,s.x,s.y),behavior=world.behaviorNames[String(cell.behavior)]||'';if(!busy.current&&!s.session&&callbacks.current.party.length&&encounterSteps>=5){encounterSteps=0;const profile=emeraldWildProfile(s.map,s.surfing);const valid=profile.rate>0&&(s.surfing||/TALL_GRASS|LONG_GRASS|CAVE/.test(behavior)||profile.biome==='cave'||/METEOR|MT_PYRE.*[1-6]F|SHOAL_CAVE/.test(s.map));if(valid&&emeraldRandom(s)<profile.rate/100){const biome=({water:3,cave:5,mountain:2,desert:6,forest:1,grass:0})[profile.biome],tier=Math.max(0,E.TIERS.findIndex((range:number[])=>profile.minLevel<=range[1])),pool=E.encounterPool(biome,tier,13).filter((p:any)=>p.id<=1025) as any[];const p=pool[Math.floor(emeraldRandom(s)*pool.length)];if(p){const level=profile.minLevel+Math.floor(emeraldRandom(s)*(profile.maxLevel-profile.minLevel+1));if(emeraldRepelBlocks(s,level,callbacks.current.party[0]?.level||0)){raf=requestAnimationFrame(frame);return;}const request:EmeraldBattleRequest={wild:true,title:`Wild ${p.name}`,team:[{species:p.id,level}],catchable:!!s.flags.FLAG_SYS_POKEDEX_GET};busy.current=true;persist();callbacks.current.onBattle(request,structuredClone(s));}}}}}}}if(now-lastSave>3000){lastSave=now;persist();}

   const [dx,dy]=directions[s.facing];const n=visible().find((n:any)=>n.x===s.x+dx&&n.y===s.y+dy);const hint=n?'Talk':'Interact';if(hint!==lastHint){lastHint=hint;setNear(hint);}const r=c.getBoundingClientRect();if(c.width!==Math.round(r.width)||c.height!==Math.round(r.height)){c.width=Math.round(r.width);c.height=Math.round(r.height);}const scale=Math.max(1,Math.min(4,Math.floor(r.height/144))),tile=16*scale,worldW=m.width*tile,worldH=m.height*tile,camX=worldW<c.width?-(c.width-worldW)/2:Math.max(0,Math.min(worldW-c.width,(s.x+.5)*tile-c.width/2)),camY=worldH<c.height?-(c.height-worldH)/2:Math.max(0,Math.min(worldH-c.height,(s.y+.5)*tile-c.height/2));ctx.imageSmoothingEnabled=false;ctx.fillStyle='#102c25';ctx.fillRect(0,0,c.width,c.height);const layer=(src:string)=>{const im=image(src);if(im.complete&&im.naturalWidth)ctx.drawImage(im,-camX,-camY,worldW,worldH);};layer(m.render.under);

   const edits=Object.entries(s.metatiles).filter(([key])=>key.startsWith(s.map+':'));const drawEdits=(kind:'atlasUnder'|'atlasOver')=>{if(!m.render[kind])return;const atlas=image(m.render[kind]);if(!atlas.complete||!atlas.naturalWidth)return;for(const [key,value]of edits){const [x,y]=key.slice(s.map.length+1).split(',').map(Number);if(kind==='atlasUnder')ctx.clearRect(x*tile-camX,y*tile-camY,tile,tile);ctx.drawImage(atlas,(value.id%32)*16,Math.floor(value.id/32)*16,16,16,x*tile-camX,y*tile-camY,tile,tile);}};drawEdits('atlasUnder');

   const sprite=(src:string,x:number,y:number,fw:number,fh:number,face:string,walking=false)=>{const im=image(src);if(!im.complete||!im.naturalWidth)return;const base=facingFrame[face as EmeraldDirection]??0,frames=Math.floor(im.naturalWidth/fw),cell=frames>=9?(walking?3+base*2+(Math.floor(now/130)%2):base):0;ctx.save();const px=(x+.5)*tile-camX,py=(y+1)*tile-camY;ctx.translate(px,py);if(face==='right')ctx.scale(-1,1);ctx.drawImage(im,Math.min(cell,frames-1)*fw,0,fw,fh,-fw*scale/2,-fh*scale,fw*scale,fh*scale);ctx.restore();};

   for(const gate of emeraldRotatingGates(s)){const file=['l1','l2','l3','l4','t1','t2','t3'][gate.shape],im=image('/assets/emerald-world/rotating-gates/'+file+'.png');if(im.complete&&im.naturalWidth){ctx.save();ctx.translate(gate.x*tile-camX,gate.y*tile-camY);ctx.rotate(gate.orientation*Math.PI/2);ctx.drawImage(im,-im.naturalWidth*scale/2,-im.naturalHeight*scale/2,im.naturalWidth*scale,im.naturalHeight*scale);ctx.restore();}}const player=world.sprites['OBJ_EVENT_GFX_'+(s.gender?'MAY':'BRENDAN')+'_'+(s.diving?'UNDERWATER':s.surfing?'SURFING':s.bike==='mach'?'MACH_BIKE':s.bike==='acro'?'ACRO_BIKE':'NORMAL')];const objects=visible().sort((a:any,b:any)=>a.y-b.y),drawPlayer=()=>!s.playerHidden&&sprite(player.src,s.x,s.y,player.frameWidth,player.frameHeight,s.facing,now<nextStep&&!!(vx||vy||forcedDirection));let drew=false;for(const n of objects){if(!drew&&n.y>s.y){drawPlayer();drew=true;}if(!n.sprite&&n.graphics_id?.startsWith('OBJ_EVENT_GFX_VAR_')){const value=s.vars['VAR_OBJ_GFX_ID_'+n.graphics_id.replace('OBJ_EVENT_GFX_VAR_','')];const symbol=Object.keys(db.constants).find(k=>k.startsWith('OBJ_EVENT_GFX_')&&db.constants[k]===value);if(symbol)n.sprite=world.sprites[symbol];}if(n.sprite)sprite(n.sprite.src,n.x,n.y,n.sprite.frameWidth,n.sprite.frameHeight,n.facing);}if(!drew)drawPlayer();const over=image(m.render.over),atlasOver=image(m.render.atlasOver);const nextOverlayKey=s.map+JSON.stringify(edits);if(over.complete&&over.naturalWidth&&atlasOver.complete&&atlasOver.naturalWidth){if(nextOverlayKey!==overlayKey){overlay.width=m.width*16;overlay.height=m.height*16;const oc=overlay.getContext('2d')!;oc.drawImage(over,0,0);for(const [key,value]of edits){const [x,y]=key.slice(s.map.length+1).split(',').map(Number);oc.clearRect(x*16,y*16,16,16);oc.drawImage(atlasOver,(value.id%32)*16,Math.floor(value.id/32)*16,16,16,x*16,y*16,16,16);}overlayKey=nextOverlayKey;}ctx.drawImage(overlay,-camX,-camY,worldW,worldH);}else layer(m.render.over);if(m.requires_flash&&s.flashLevel>0){ctx.fillStyle='#061211bb';ctx.fillRect(0,0,c.width,c.height);}if(/RAIN/.test(s.weather||m.weather)){ctx.strokeStyle='#bbdce877';ctx.lineWidth=1;for(let i=0;i<30;i++){const x=(i*89+now*.1)%c.width,y=(i*57+now*.25)%c.height;ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x-5,y+12);ctx.stroke();}}raf=requestAnimationFrame(frame);};raf=requestAnimationFrame(frame);return()=>{cancelAnimationFrame(raf);window.removeEventListener('keydown',down);window.removeEventListener('keyup',up);window.removeEventListener('blur',stop);window.removeEventListener('emerald-pause',stop);window.removeEventListener('pagehide',stop);document.removeEventListener('visibilitychange',visibility);};},[]);

 const joystick=(e:React.PointerEvent<HTMLDivElement>)=>{const r=e.currentTarget.getBoundingClientRect(),x=(e.clientX-r.left-r.width/2)/(r.width*.35),y=(e.clientY-r.top-r.height/2)/(r.height*.35),length=Math.max(1,Math.hypot(x,y));input.current={x:x/length,y:y/length};const knob=e.currentTarget.firstElementChild as HTMLElement;knob.style.transform=`translate(${x/length*20}px,${y/length*20}px)`;};

 const stopStick=(e:React.PointerEvent<HTMLDivElement>)=>{input.current={x:0,y:0};(e.currentTarget.firstElementChild as HTMLElement).style.transform='';};

 const useBagItem=async(item:string)=>{const s=state.current;if(item.startsWith('ITEM_HM')){const hmMoves=['cut','fly','surf','strength','flash','rocksmash','waterfall','dive'],move=hmMoves[Number(item.slice(-2))-1];setModal({kind:'teach',title:'Teach '+(E.moves[move]?.name||move),move});return;}const [dx,dy]=directions[s.facing],cell=emeraldCell(s,getMap(),s.x+dx,s.y+dy);const table=(importedEvents.wildEncounters as any[]).find(e=>e.map===s.map)?.fishing_mons;const result=useEmeraldFieldItem(s,item,{map:getMap(),facingWater:cell.water,facingWaterCollision:cell.collision,facingWaterfall:/WATERFALL/.test(world.behaviorNames[String(cell.behavior)]||''),fishingProfile:table});if(!result.used){await prompt('BAG',result.reason);return;}Object.assign(s,result.next);setModal(null);if(result.effect.kind==='escape'){Object.assign(s,result.effect.destination);s.entered=false;}if(result.effect.kind==='fishing'){await prompt('Fishing',result.message);if(emeraldRandom(s)<result.effect.rate/100){const slot=result.effect.slots[Math.floor(emeraldRandom(s)*result.effect.slots.length)],profile=emeraldWildProfile(s.map,true),pool=E.encounterPool(3,Math.max(0,E.TIERS.findIndex((range:number[])=>slot.min_level<=range[1])),13).filter((p:any)=>p.id<=1025),mon=pool[Math.floor(emeraldRandom(s)*pool.length)],level=slot.min_level+Math.floor(emeraldRandom(s)*(slot.max_level-slot.min_level+1));persist();callbacks.current.onBattle({wild:true,title:'Wild '+mon.name,team:[{species:mon.id,level}],catchable:!!s.flags.FLAG_SYS_POKEDEX_GET},structuredClone(s));return;}await prompt('Fishing','Not even a nibble…');}else await prompt('BAG',result.message);persist();redraw();};
 const fieldMove=async(raw:string)=>{const s=state.current,move=normalizeEmeraldFieldMove(raw),permit=fieldMovePermission(s,move,callbacks.current.party.flatMap(p=>p.moves));if(!permit.allowed){await prompt('Field move',permit.reason);return;}if(move==='FLY'){setModal({kind:'fly',title:'Fly to…'});return;}if(move==='STRENGTH'){s.strength=true;await prompt('STRENGTH','Your Pokémon can now move boulders.');}else if(move==='FLASH'){s.flashLevel=0;await prompt('FLASH','The cave is illuminated.');}else if(move==='SURF'||move==='CUT'||move==='ROCK_SMASH'){interact.current();}else if(move==='DIVE'){const connection=getMap().connections?.find((c:any)=>c.direction===(s.diving?'emerge':'dive'));if(!connection){await prompt('DIVE','You cannot dive or surface here.');return;}s.diving=!s.diving;s.map=connection.to;s.entered=false;}else if(move==='WATERFALL'){const [dx,dy]=directions.up;let y=s.y;while(y>0&&/WATERFALL/.test(world.behaviorNames[String(emeraldCell(s,getMap(),s.x,y-1).behavior)]||''))y--;if(y!==s.y)s.y=y;else await prompt('WATERFALL','There is no waterfall here.');}persist();redraw();};
 useEffect(()=>{const handler=(event:Event)=>{const move=(event as CustomEvent<string>).detail;if(!busy.current&&!state.current.session)void fieldMove(move);};window.addEventListener('emerald-field-move',handler);return()=>window.removeEventListener('emerald-field-move',handler);},[]);
 const buy=(item:string)=>{const s=state.current;const prices:Record<string,number>={ITEM_POKE_BALL:200,ITEM_GREAT_BALL:600,ITEM_ULTRA_BALL:1200,ITEM_POTION:300,ITEM_SUPER_POTION:700,ITEM_HYPER_POTION:1200,ITEM_REVIVE:1500,ITEM_ANTIDOTE:100,ITEM_PARALYZE_HEAL:200,ITEM_REPEL:350};const price=prices[item]||500;if(s.money<price){setError('Not enough money.');return;}s.money-=price;s.inventory[item]=(s.inventory[item]||0)+1;persist();redraw();};

 return <section className="emerald-world" aria-label="Emerald exploration"><canvas ref={canvas} aria-label={`${displayName(view.map)} map`}/><header className="emerald-world-top"><strong>{displayName(view.map)}</strong><button disabled={!!state.current.session||!!answer.current} onClick={()=>setModal({kind:'menu',title:'START'})}>Menu</button></header><div className="emerald-world-controls"><div className="emerald-world-stick" role="application" aria-label="Move and face direction" onPointerDown={e=>{e.currentTarget.setPointerCapture(e.pointerId);joystick(e);}} onPointerMove={e=>{if(e.currentTarget.hasPointerCapture(e.pointerId))joystick(e);}} onPointerUp={stopStick} onPointerCancel={stopStick} onLostPointerCapture={stopStick}><span/></div><div className="emerald-world-actions"><button onPointerDown={()=>running.current=true} onPointerUp={()=>running.current=false} onPointerCancel={()=>running.current=false}>Run</button><button className="emerald-interact" onClick={()=>interact.current()}>{near}</button></div></div>{error&&<div className="emerald-event-error" role="alert"><span>{error}</span><button onClick={()=>{busy.current=false;setError('');void run.current();}}>Retry event</button><button onClick={()=>{persist();callbacks.current.onLeave();}}>Menu</button></div>}

 {modal&&<aside className={`emerald-dialogue ${modal.kind}`} role="dialog" aria-label={modal.title}><h2>{modal.title}</h2>{modal.text&&<p>{modal.text}</p>}{modal.kind==='dialogue'&&<div className="emerald-dialogue-actions">{modal.choices?.map(c=><button key={c.label} onClick={()=>close(c.value)}>{c.label}</button>)}</div>}

 {modal.kind==='menu'&&<div className="emerald-menu-actions">{state.current.flags.FLAG_SYS_POKEDEX_GET&&<button onClick={()=>{persist();callbacks.current.onMenu?.('pokedex');}}>POKéDEX</button>}{callbacks.current.party.length>0&&<button onClick={()=>{persist();callbacks.current.onMenu?.('party');}}>POKéMON</button>}<button onClick={()=>setModal({kind:'bag',title:'BAG'})}>BAG</button>{state.current.flags.FLAG_SYS_POKENAV_GET&&<button onClick={()=>{void say('Hoenn contacts and journey records.','Pokenav');}}>POKéNAV</button>}<button onClick={()=>{persist();callbacks.current.onMenu?.('trainer');}}>{state.current.playerName||'TRAINER'}</button><button onClick={()=>{persist();setModal({kind:'dialogue',title:'SAVE',text:'Your adventure has been saved.',choices:[{label:'Continue',value:0}]});}}>SAVE</button><button onClick={()=>{persist();callbacks.current.onMenu?.('options');}}>OPTION</button><button onClick={()=>setModal(null)}>EXIT</button></div>}

 {modal.kind==='starter'&&<div className="emerald-starter-grid">{[1,4,7,152,155,158,252,255,258,387,390,393,495,498,501,650,653,656,722,725,728,810,813,816,906,909,912].map(id=><button key={id} onClick={()=>close(id)}><img src={getEmpressSprite(id)} alt="" width={48} height={48}/>{SPECIES[id].name}</button>)}</div>}

 {modal.kind==='half-party'&&<><div className="emerald-menu-actions">{callbacks.current.party.map((p,i)=><button key={p.uid} aria-pressed={selectedParty.includes(i)} onClick={()=>setSelectedParty(old=>old.includes(i)?old.filter(n=>n!==i):old.length<3?[...old,i]:old)}>{selectedParty.includes(i)?'✓ ':''}{SPECIES[p.species].name} Lv {p.level}</button>)}</div><button disabled={selectedParty.length!==3} onClick={()=>{(state.current.nativeState??={}).selectedPartyOrder=selectedParty.map(i=>i+1);persist();close(1);}}>Confirm party</button><button onClick={()=>close(0)}>Cancel</button></>}
 {modal.kind==='berry'&&<div className="emerald-bag-items">{Object.entries(state.current.inventory).filter(([id,n])=>id.endsWith('_BERRY')&&n>0).map(([id,n])=><button key={id} onClick={()=>close(db.constants[id])}>{id.replace('ITEM_','').replaceAll('_',' ')} × {n}</button>)}<button onClick={()=>close(0)}>Cancel</button></div>}

 {modal.kind==='bag'&&<><div className="emerald-bag-items">{Object.entries(state.current.inventory).filter(([,n])=>n>0).map(([item,n])=><button key={item} onClick={()=>void useBagItem(item)}>{item.replace(/^ITEM_/,'').replaceAll('_',' ')} × {n}</button>)}</div><button onClick={()=>setModal(null)}>Close bag</button></>}

 {modal.kind==='fly'&&<div className="emerald-menu-actions">{(importedEvents.healLocations as any[]).filter(h=>maps[h.map]&&(state.current.flags['FLAG_VISITED_'+h.id.replace(/^HEAL_LOCATION_/,'')]||h.map==='MAP_LITTLEROOT_TOWN')).map(h=><button key={h.id} onClick={()=>{Object.assign(state.current,{map:h.map,x:h.x,y:h.y,facing:'down',entered:false});setModal(null);persist();redraw();}}>{displayName(h.map)}</button>)}<button onClick={()=>setModal(null)}>Cancel</button></div>}
 {modal.kind==='teach'&&<><p>Choose a partner and move slot. HM teaching is free.</p>{callbacks.current.party.map((p,i)=><div className="emerald-teach-row" key={p.uid}><strong>{SPECIES[p.species].name}</strong>{p.moves.map((move,slot)=><button key={slot} onClick={()=>{callbacks.current.onTeach(i,modal.move!,slot);setModal(null);}}>{slot+1}: {E.moves[move]?.name||move}</button>)}</div>)}<button onClick={()=>setModal(null)}>Cancel</button></>}

 {modal.kind==='shop'&&<><p>{state.current.money} money</p><div className="emerald-shop-stock">{modal.stock?.map(item=><button key={item} onClick={()=>buy(item)}>{item.replace(/^ITEM_/,'').replaceAll('_',' ')}</button>)}</div><button onClick={()=>close(1)}>Leave shop</button></>}

 {modal.kind==='clock'&&<><p>Set the clock in your new room.</p><input type="time" value={time} onChange={e=>setTime(e.target.value)}/><button onClick={()=>{state.current.vars.VAR_CLOCK_HOUR=Number(time.split(':')[0]);state.current.vars.VAR_CLOCK_MINUTE=Number(time.split(':')[1]);state.current.flags.FLAG_SYS_CLOCK_SET=true;persist();close(1);}}>Set clock</button></>}

 </aside>}</section>;

}
