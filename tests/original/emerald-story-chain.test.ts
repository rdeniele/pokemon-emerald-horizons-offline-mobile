import test from 'node:test';
import assert from 'node:assert/strict';
import {emeraldWorld,resolveEmeraldValue} from '../../src/offline/emerald-content';
import {createEmeraldWorldState} from '../../src/offline/emerald-state';
import {applyEmeraldAction,applyEmeraldSpecial,type EmeraldMap} from '../../src/offline/emerald-mechanics';
import {createEmeraldSession,emeraldEvents,runEmeraldScript} from '../../src/offline/emerald-script-vm';
const cases=[
['RustboroCity_Gym_EventScript_RoxanneDefeated','FLAG_BADGE01_GET'],
['RustboroCity_DevonCorp_3F_EventScript_MeetPresident',''],
['Route104_MrBrineysHouse_EventScript_SailToDewford',''],
['SlateportCity_OceanicMuseum_2F_EventScript_CaptStern',''],
['Route110_EventScript_MayDefeated',''],
['MauvilleCity_Gym_EventScript_WattsonDefeated','FLAG_BADGE03_GET'],
['MtChimney_EventScript_Maxie','FLAG_DEFEATED_EVIL_TEAM_MT_CHIMNEY'],
['PetalburgCity_Gym_EventScript_NormanBattle','FLAG_BADGE05_GET'],
['Route119_WeatherInstitute_2F_EventScript_ShellyDefeated','FLAG_RECEIVED_CASTFORM'],
['Route120_EventScript_StevenGiveDeconScope','FLAG_RECEIVED_DEVON_SCOPE'],
['FortreeCity_Gym_EventScript_WinonaDefeated','FLAG_BADGE06_GET'],
['MossdeepCity_SpaceCenter_2F_EventScript_DefeatedMaxieTabitha',''],
['SeafloorCavern_Room9_EventScript_ArchieAwakenKyogre','FLAG_KYOGRE_ESCAPED_SEAFLOOR_CAVERN'],
['SootopolisCity_EventScript_StartRayquazaScene',''],
['SootopolisCity_Gym_1F_EventScript_JuanDefeated','FLAG_BADGE08_GET'],
['EverGrandeCity_SidneysRoom_EventScript_Defeated','FLAG_DEFEATED_ELITE_4_SIDNEY'],
['EverGrandeCity_PhoebesRoom_EventScript_Defeated','FLAG_DEFEATED_ELITE_4_PHOEBE'],
['EverGrandeCity_GlaciasRoom_EventScript_Defeated','FLAG_DEFEATED_ELITE_4_GLACIA'],
['EverGrandeCity_DrakesRoom_EventScript_Defeated','FLAG_DEFEATED_ELITE_4_DRAKE'],
['EverGrandeCity_ChampionsRoom_EventScript_Defeated',''],
['EverGrandeCity_HallOfFame_EventScript_GameClearMale','FLAG_SYS_GAME_CLEAR'],
];
for(const [label,expectedFlag]of cases)test(`source progression: ${label}`,async()=>{
 const s=createEmeraldWorldState();const maps=emeraldWorld.maps as unknown as Record<string,EmeraldMap&{id:string;scripts:string}>;
 const owner=Object.values(maps).find(m=>m.scripts.includes(label+'::'));assert.ok(owner,label);s.map=owner.id;s.vars.VAR_FACING=2;s.vars.VAR_RESULT=1;s.lastBattleOutcome=1;s.inventory.ITEM_DEVON_GOODS=1;s.inventory.ITEM_LETTER=1;
 const effects:string[]=[];const resolve=(symbol:string)=>resolveEmeraldValue(s,s.map,symbol);
 const native=(op:string,args:string[])=>{if(op==='getpartysize')return 1;const special=op==='special'||op==='specialvar';const r=special?applyEmeraldSpecial(s,args[op==='specialvar'?1:0],[],{resolve,maps,constants:emeraldEvents.constants,party:[{species:252,level:50}]}):applyEmeraldAction(s,op,args,resolve);assert.ok(r.handled,`${op} ${args.join(' ')}: ${r.reason}`);if(r.effect){effects.push(r.effect.kind);if(r.effect.kind==='give-pokemon')return 0;if(r.effect.kind==='buffer-tm-hm')s.strings.STR_VAR_1='source move';}return r.result;};
 const result=await runEmeraldScript(createEmeraldSession(label),s,{say:()=>{},choice:()=>1,battle:()=>1,service:native,action:native,move:(op,args)=>{if(/apply/.test(op))assert.ok(emeraldEvents.movements[args[1]],args[1]);else native(op,args);},warp:(_op,args)=>{if(args[0]?.startsWith('MAP_'))s.map=args[0];}},undefined,10000);
 if(process.env.EMERALD_AUDIT_EFFECTS)console.log(label,[...new Set(effects)].join(','));assert.equal(result.status,'ended',JSON.stringify(result.command));if(expectedFlag)assert.equal(s.flags[expectedFlag],true);
});
