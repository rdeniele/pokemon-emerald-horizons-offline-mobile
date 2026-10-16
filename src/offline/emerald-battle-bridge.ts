import {emeraldEvents,emeraldText,resumeEmeraldSession} from './emerald-script-vm';
import type {EmeraldWorldState} from './emerald-state';
type BridgeState=EmeraldWorldState&{lastBattle?:number;battleRequest?:{trainerId?:string;resumeLabel?:string;defeatLabel?:string;wild:boolean};pendingUi?:unknown};
/** Resume the exact saved event continuation only after the external fight/capture commits. */
export function completeEmeraldBattle(world:EmeraldWorldState,won:boolean,outcome=won?1:2){
 const s=world as BridgeState,request=s.battleRequest;s.lastBattle=outcome;s.lastBattleOutcome=outcome;s.vars.VAR_RESULT=outcome;
 if(won&&request?.trainerId)s.trainerFlags[request.trainerId]=true;
 if(!won){Object.assign(s,s.lastHeal);s.session=undefined;delete s.pendingUi;(s as any).entered=false;}
 else if(s.session){resumeEmeraldSession(s.session,s,outcome);if(request?.resumeLabel&&emeraldEvents.labels[request.resumeLabel]!==undefined)s.session.pc=emeraldEvents.labels[request.resumeLabel];}
 if(won&&request?.defeatLabel&&emeraldEvents.texts[request.defeatLabel])s.pendingUi={text:emeraldText(request.defeatLabel,s),label:request.defeatLabel};delete s.battleRequest;return s;
}
