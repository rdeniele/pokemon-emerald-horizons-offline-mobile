import test from 'node:test';
import assert from 'node:assert/strict';
import {createEmeraldSession,emeraldEvents,emeraldRandom,runEmeraldScript,resumeEmeraldSession,type EmeraldDatabase,type EmeraldState} from '../../src/offline/emerald-script-vm';
const state=():EmeraldState=>({flags:{},vars:{},inventory:{},money:3000});
test('canonical import retains story, original dialogue and trainer parties',()=>{
 assert.ok(Object.keys(emeraldEvents.labels).length>14000);
 assert.match(emeraldEvents.texts.RustboroCity_Gym_Text_RoxanneIntro,/ROXANNE/);
 assert.deepEqual(emeraldEvents.trainers.TRAINER_ROXANNE_1.team.map(m=>m.level),[12,12,15]);
 assert.ok(emeraldEvents.labels.EventScript_ResetAllMapFlags!==undefined);
});
test('canonical initial hide flags execute with shared calls and fallthrough intact',async()=>{
 const s=state();const session=createEmeraldSession('EventScript_ResetAllMapFlags');
 const result=await runEmeraldScript(session,s);
 assert.equal(result.status,'ended');assert.ok(Object.keys(s.flags).length>150);assert.equal(s.flags.FLAG_HIDE_LITTLEROOT_TOWN_BIRCHS_LAB_BIRCH,true);assert.ok(Object.keys(s.berries||{}).length>50);
});
test('serialized continuation waits for combat and resumes flag reward only afterwards',async()=>{
 const db={instructions:[{op:'setvar',args:['VAR_TEST','3']},{op:'call',args:['sub']},{op:'trainerbattle_single',args:['TRAINER_TEST']},{op:'setflag',args:['FLAG_WON']},{op:'end',args:[]},{op:'addvar',args:['VAR_TEST','2']},{op:'return',args:[]}],labels:{start:0,sub:5},texts:{},constants:{},trainers:{},movements:{}} satisfies EmeraldDatabase;
 const s=state();let session=createEmeraldSession('start',db);let result=await runEmeraldScript(session,s,{battle:()=>({wait:true})},db);
 assert.equal(result.status,'waiting');assert.equal(s.vars.VAR_TEST,5);assert.equal(s.flags.FLAG_WON,undefined);
 session=JSON.parse(JSON.stringify(session));assert.equal((await runEmeraldScript(session,s,{},db)).status,'waiting');
 resumeEmeraldSession(session,s,1);result=await runEmeraldScript(session,s,{},db);assert.equal(result.status,'ended');assert.equal(s.flags.FLAG_WON,true);
});
test('unknown native special stops explicitly and can be implemented then retried',async()=>{
 const db={instructions:[{op:'special',args:['ChooseStarter']},{op:'end',args:[]}],labels:{start:0},texts:{},constants:{},trainers:{},movements:{}} satisfies EmeraldDatabase;
 const s=state();const session=createEmeraldSession('start',db);assert.equal((await runEmeraldScript(session,s,{},db)).status,'unsupported');assert.equal(session.pc,0);
 assert.equal((await runEmeraldScript(session,s,{service:()=>1},db)).status,'ended');assert.equal(s.vars.VAR_RESULT,1);
});
test('comparison branches, indirect flags, yes-no dialogue and world warps retain semantics',async()=>{
 const db={instructions:[{op:'setvar',args:['VAR_FLAG','FLAG_TEST']},{op:'setflag',args:['VAR_FLAG']},{op:'compare',args:['4','4']},{op:'goto_if_eq',args:['choice']},{op:'end',args:[]},{op:'msgbox',args:['intro','MSGBOX_YESNO']},{op:'setrespawn',args:['HEAL_LOCATION_LITTLEROOT_TOWN']},{op:'end',args:[]}],labels:{start:0,choice:5},texts:{intro:'Proceed, {PLAYER}?'},constants:{FLAG_TEST:9},trainers:{},movements:{}} satisfies EmeraldDatabase;
 const s=state();const calls:string[]=[];const result=await runEmeraldScript(createEmeraldSession('start',db),s,{say:text=>{calls.push(text);},choice:()=>1,action:op=>{calls.push(op);}},db);
 assert.equal(result.status,'ended');assert.equal(s.flags.FLAG_TEST,true);assert.equal(s.vars.VAR_RESULT,1);assert.deepEqual(calls,['Proceed, TRAINER?','setrespawn']);
});
test('fresh variables read zero rather than their numeric variable addresses',async()=>{const db={instructions:[{op:'goto_if_eq',args:['VAR_RIVAL_STATE','0','fresh']},{op:'end',args:[]},{op:'setflag',args:['FLAG_CORRECT']},{op:'end',args:[]}],labels:{start:0,fresh:2},texts:{},constants:{VAR_RIVAL_STATE:16400},trainers:{},movements:{}} satisfies EmeraldDatabase;const s=state();await runEmeraldScript(createEmeraldSession('start',db),s,{},db);assert.equal(s.flags.FLAG_CORRECT,true);});
test('world RNG resumes its exact sequence after a serialized checkpoint',()=>{const s=state();emeraldRandom(s);const restored=JSON.parse(JSON.stringify(s));assert.deepEqual(Array.from({length:20},()=>emeraldRandom(s)),Array.from({length:20},()=>emeraldRandom(restored)));});
