import test from 'node:test';
import assert from 'node:assert/strict';
import {E,buildOriginalBattle,type Save} from '../../src/offline/model';
import {initialEmeraldState,resolveEmeraldValue} from '../../src/offline/emerald-content';
import {createEmeraldSession,runEmeraldScript} from '../../src/offline/emerald-script-vm';
import {applyEmeraldAction} from '../../src/offline/emerald-mechanics';
import {completeEmeraldBattle} from '../../src/offline/emerald-battle-bridge';

test('Birch rescue source hands Gen 9 starter to real combat and returns to lab after a saved win',async()=>{
 const save=E.newGame(252) as Save;save.party=[];save.emerald=await initialEmeraldState();const world=save.emerald;delete world.starter;world.map='MAP_ROUTE101';world.vars.VAR_ROUTE101_STATE=2;world.session=createEmeraldSession('Route101_EventScript_BirchsBag');
 const resolve=(symbol:string)=>resolveEmeraldValue(world,world.map,symbol);
 const hooks={say:()=>0,move:()=>undefined,warp:(_op:string,args:string[])=>{world.map=args[0];world.x=Number(args.at(-2));world.y=Number(args.at(-1));},service:(op:string,args:string[])=>{if(op==='special'&&args[0]==='ChooseStarter')return{wait:true};if(op==='special'&&args[0]==='HealPlayerParty')return 1;if(op==='fadescreen')return;throw Error(op+' '+args);},action:(op:string,args:string[])=>{const result=applyEmeraldAction(world,op,args,resolve);if(!result.handled)throw Error(op+' '+args);return result.result;}};
 assert.equal((await runEmeraldScript(world.session,world,hooks)).status,'waiting');assert.equal(world.flags.FLAG_SYS_POKEMON_GET,true);assert.equal(E.unpack(E.pack(save)).party.length,0);
 world.starter=909;world.vars.VAR_STARTER_MON=1;save.party=[E.makeMon(909,5)];save.settings.auto=true;E.startBattle(save,'wild',{mon:E.makeMon(263,2)});const engine=buildOriginalBattle(save);for(let i=0;i<12000&&!engine.state.result;i++)engine.advance(.05);assert.equal(engine.state.result?.winner,'player');save.battle!.engineSnapshot=engine.snapshot();const restored=E.unpack(E.pack(save)) as Save;assert.equal(buildOriginalBattle(restored).snapshot(),engine.snapshot());
 E.finish(save,true);save.pending=null;completeEmeraldBattle(world,true);assert.equal((await runEmeraldScript(world.session!,world,hooks)).status,'ended');assert.equal(world.vars.VAR_ROUTE101_STATE,3);assert.equal(world.vars.VAR_BIRCH_LAB_STATE,2);assert.equal(world.map,'MAP_LITTLEROOT_TOWN_PROFESSOR_BIRCHS_LAB');assert.equal(save.party[0].species,909);
});
