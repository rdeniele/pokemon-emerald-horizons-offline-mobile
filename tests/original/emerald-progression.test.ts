import test from 'node:test';
import assert from 'node:assert/strict';
import {createEmeraldWorldState} from '../../src/offline/emerald-state';
import {applyEmeraldAction,applyEmeraldSpecial} from '../../src/offline/emerald-mechanics';
import {createEmeraldSession,emeraldEvents,resumeEmeraldSession,runEmeraldScript} from '../../src/offline/emerald-script-vm';

test('original clock script suspends for native clock UI and survives process restoration',async()=>{
 const s=createEmeraldWorldState();const session=createEmeraldSession('PlayersHouse_2F_EventScript_SetWallClock');
 const effects:string[]=[];
 const result=await runEmeraldScript(session,s,{service:(op,args)=>{const r=op==='special'?applyEmeraldSpecial(s,args[0]):applyEmeraldAction(s,op,args);assert.equal(r.handled,true);if(r.effect)effects.push(r.effect.kind);return r.effect?.kind==='set-clock'?{wait:true}:undefined;}});
 assert.equal(result.status,'waiting');assert.deepEqual(effects,['fadescreen','set-clock']);
 const restored=JSON.parse(JSON.stringify({s,session}));resumeEmeraldSession(restored.session,restored.s);assert.equal((await runEmeraldScript(restored.session,restored.s)).status,'ended');
});

test('Drake source victory chain unlocks the next room after the native fan-counter update',async()=>{
 const s=createEmeraldWorldState();s.map='MAP_EVER_GRANDE_CITY_DRAKES_ROOM';s.vars.VAR_LILYCOVE_FAN_CLUB_STATE=0;
 const session=createEmeraldSession('EverGrandeCity_DrakesRoom_EventScript_Defeated');
 const result=await runEmeraldScript(session,s,{say:()=>{},move:(_op,args)=>{assert.ok(emeraldEvents.movements[args[1]],args[1]);},service:(op,args)=>{const r=op==='special'?applyEmeraldSpecial(s,args[0],args.slice(1),{constants:emeraldEvents.constants}):applyEmeraldAction(s,op,args,value=>s.vars[value]??emeraldEvents.constants[value]??Number(value));assert.equal(r.handled,true,r.reason);},action:(op,args)=>{const r=applyEmeraldAction(s,op,args,value=>s.vars[value]??emeraldEvents.constants[value]??Number(value));assert.equal(r.handled,true,r.reason);}});
 assert.equal(result.status,'ended');assert.equal(s.flags.FLAG_DEFEATED_ELITE_4_DRAKE,true);assert.ok(Object.keys(s.metatiles).length>0);
});

test('Steven multi-battle requires an explicit selected party and preserves its original order',()=>{
 const s=createEmeraldWorldState();const selection=applyEmeraldSpecial(s,'ChooseHalfPartyForBattle');
 assert.deepEqual(selection.effect,{kind:'choose-half-party',max:3,minimum:3});assert.equal(s.vars.VAR_FRONTIER_FACILITY,9);
 assert.equal(applyEmeraldSpecial(s,'ReducePlayerPartyToSelectedMons').handled,false);
 s.nativeState={selectedPartyOrder:[3,1,2]};assert.deepEqual(applyEmeraldSpecial(s,'ReducePlayerPartyToSelectedMons').effect,{kind:'reduce-party',indices:[2,0,1]});
 assert.equal(applyEmeraldAction(s,'frontier_set',['FRONTIER_DATA_SELECTED_MON_ORDER']).handled,true);
 assert.deepEqual(s.nativeState.frontierSelectedOrder,[3,1,2]);assert.deepEqual(applyEmeraldAction(s,'frontier_saveparty',[]).effect,{kind:'save-selected-party'});
});

test('fan counter changes only after meeting fans and reaching the canonical threshold',()=>{
 const s=createEmeraldWorldState();s.vars.VAR_0x8004=0;s.vars.VAR_FANCLUB_FAN_COUNTER=18;
 applyEmeraldSpecial(s,'Script_TryGainNewFanFromCounter');assert.equal(s.vars.VAR_FANCLUB_FAN_COUNTER,18);
 s.vars.VAR_LILYCOVE_FAN_CLUB_STATE=2;applyEmeraldSpecial(s,'Script_TryGainNewFanFromCounter');
 assert.equal(s.vars.VAR_FANCLUB_FAN_COUNTER&127,0);assert.ok(s.vars.VAR_FANCLUB_FAN_COUNTER&0xff00);
});

test('Gen 1–9 starter species stay distinct while rival scripts receive the source elemental branch',()=>{
 const s=createEmeraldWorldState();s.starter=909;s.vars.VAR_STARTER_MON=1;
 assert.equal(applyEmeraldSpecial(s,'GetStarterPokemon').result,280);assert.equal(s.starter,909);
 assert.equal(applyEmeraldSpecial(s,'IsStarterInParty',[],{party:[{species:909,level:5}]}).result,1);
 s.starter=912;s.vars.VAR_STARTER_MON=2;assert.equal(applyEmeraldSpecial(s,'GetStarterPokemon').result,283);
});

test('new bedroom initializes no decorations; saved sprite decorations restore only onto valid surfaces',()=>{
 const s=createEmeraldWorldState();assert.equal(applyEmeraldSpecial(s,'InitSecretBaseDecorationSprites').handled,true);assert.deepEqual(s.objects,{});
 s.map='ROOM';s.nativeState={decorationLayouts:{ROOM:[{permission:'DECORPERM_SPRITE',position:0x21,graphics:98}]}};
 const map={width:4,height:3,tiles:['____','____','____'],behaviors:Array(12).fill(0),npcs:[{localId:3,x:0,y:0,flag:'FLAG_DECORATION_1',graphics_id:'OBJ_EVENT_GFX_VAR_2'}]};map.behaviors[6]=7;
 const context={maps:{ROOM:map},constants:{MB_HOLDS_SMALL_DECORATION:7,MB_HOLDS_LARGE_DECORATION:8}};
 applyEmeraldSpecial(s,'InitSecretBaseDecorationSprites',[],context);assert.equal(s.vars.VAR_OBJ_GFX_ID_2,98);assert.equal(s.flags.FLAG_DECORATION_1,false);assert.deepEqual(s.objects['ROOM:3'],{x:2,y:1,hidden:false});
});

test('Dad television broadcast turns off the actual television tiles with source collision flags',()=>{
 const s=createEmeraldWorldState();s.map='ROOM';const map={width:2,height:1,tiles:['__'],behaviors:[6,0]};
 assert.equal(applyEmeraldSpecial(s,'TurnOffTVScreen',[],{maps:{ROOM:map},constants:{MB_TELEVISION:6,METATILE_Building_TV_Off:123}}).handled,true);
 assert.deepEqual(s.metatiles['ROOM:0,0'],{id:123,collision:3});assert.equal(s.metatiles['ROOM:1,0'],undefined);
});

test('PC multichoice keeps source index order and unlocks Hall of Fame only after championship',()=>{
 const s=createEmeraldWorldState();s.playerName='MAY';assert.deepEqual(applyEmeraldSpecial(s,'ScriptMenu_CreatePCMultichoice').effect,{kind:'pc-menu',options:["SOMEONE'S PC","MAY's PC",'LOG OFF']});
 s.flags.FLAG_SYS_PC_LANETTE=true;s.flags.FLAG_SYS_GAME_CLEAR=true;assert.deepEqual(applyEmeraldSpecial(s,'ScriptMenu_CreatePCMultichoice').effect,{kind:'pc-menu',options:["LANETTE'S PC","MAY's PC",'HALL OF FAME','LOG OFF']});
});
