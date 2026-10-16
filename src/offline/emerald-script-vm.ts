import imported from '../data/emerald-events.generated.json';
export type EmeraldInstruction={op:string;args:string[]};
export type EmeraldDatabase={instructions:EmeraldInstruction[];labels:Record<string,number>;texts:Record<string,string>;constants:Record<string,number>;trainers:Record<string,{name:string;team:{level:number;species:string}[];trainerClass?:string;doubleBattle?:boolean;rewardMoney?:number}>;shops?:Record<string,string[]>;choices?:Record<string,string[]>;movements:Record<string,EmeraldInstruction[]>;stdScripts?:string[]};
export const emeraldEvents=imported as EmeraldDatabase;
export function emeraldRandom(state:EmeraldState):number{state.rng=((state.rng??0x6d2b79f5)+0x6d2b79f5)>>>0;let n=state.rng;n=Math.imul(n^(n>>>15),n|1);n^=n+Math.imul(n^(n>>>7),n|61);return((n^(n>>>14))>>>0)/4294967296;}
export type EmeraldState={flags:Record<string,boolean>;vars:Record<string,number>;trainerFlags?:Record<string,boolean>;inventory?:Record<string,number>;berries?:Record<string,{item:string;stage:string}>;money?:number;playerName?:string;rivalName?:string;gender?:number;rng?:number};
export type EmeraldSession={pc:number;stack:number[];compare:number;switchValue?:number;ended:boolean;pending?:EmeraldInstruction;origin:string};
export type EmeraldHookResult=void|number|{wait?:boolean;result?:number};
export type EmeraldHooks={say?:(text:string,label:string)=>Promise<EmeraldHookResult>|EmeraldHookResult;choice?:(op:string,args:string[])=>Promise<EmeraldHookResult>|EmeraldHookResult;battle?:(op:string,args:string[])=>Promise<EmeraldHookResult>|EmeraldHookResult;warp?:(op:string,args:string[])=>Promise<EmeraldHookResult>|EmeraldHookResult;move?:(op:string,args:string[])=>Promise<EmeraldHookResult>|EmeraldHookResult;service?:(op:string,args:string[])=>Promise<EmeraldHookResult>|EmeraldHookResult;action?:(op:string,args:string[])=>Promise<EmeraldHookResult>|EmeraldHookResult};
export function createEmeraldSession(label:string,db:EmeraldDatabase=emeraldEvents):EmeraldSession{if(db.labels[label]===undefined)throw Error(`Unknown Emerald script: ${label}`);return{pc:db.labels[label],stack:[],compare:0,ended:false,origin:label};}
export function resumeEmeraldSession(session:EmeraldSession,state:EmeraldState,result?:number){if(result!==undefined)state.vars.VAR_RESULT=result;session.pending=undefined;}
export function emeraldText(label:string,state:EmeraldState,db:EmeraldDatabase=emeraldEvents){return(db.texts[label]??label).replace(/\{PLAYER\}/g,state.playerName||'TRAINER').replace(/\{RIVAL\}/g,state.rivalName||'MAY').replace(/\{KUN\}/g,'');}
export async function runEmeraldScript(session:EmeraldSession,state:EmeraldState,hooks:EmeraldHooks={},db:EmeraldDatabase=emeraldEvents,budget=2000):Promise<{status:'ended'|'waiting'|'unsupported'|'budget';command?:EmeraldInstruction}>{
 if(session.pending)return{status:'waiting',command:session.pending};
 const value=(s:string):number=>state.vars[s]??(s.startsWith('VAR_')?0:db.constants[s])??(Number.isFinite(Number(s))?Number(s):0);
 const indirect=(s:string,prefix:string)=>s.startsWith('VAR_')?(Object.keys(db.constants).find(k=>k.startsWith(prefix)&&db.constants[k]===value(s))||String(value(s))):s;
 const jump=(s:string,call=false)=>{if(db.labels[s]===undefined)return false;if(call)session.stack.push(session.pc);session.pc=db.labels[s];return true;};
 const condition=(s:string,a:number,b:number)=>({eq:a===b,ne:a!==b,lt:a<b,gt:a>b,le:a<=b,ge:a>=b,set:a!==0,unset:a===0}[s]??false);
 for(let step=0;step<budget&&!session.ended;step++){
  const instruction=db.instructions[session.pc];if(!instruction){session.ended=true;break;}session.pc++;
  const {op,args:a}=instruction;const v=(i:number)=>value(a[i]||'0');
  if(['end','endtrainerbattle','gotopostbattlescript'].includes(op)){session.ended=true;break;}
  if(op==='return'){if(session.stack.length)session.pc=session.stack.pop()!;else session.ended=true;continue;}
  if(op==='goto'||op==='call'){if(!jump(a[0],op==='call')){session.pc--;return{status:'unsupported',command:instruction};}continue;}
  if(op==='callstd'||op==='gotostd'){const label=db.stdScripts?.[v(0)];if(!label||!jump(label,op==='callstd')){session.pc--;return{status:'unsupported',command:instruction};}continue;}
  if(op.startsWith('goto_if_')||op.startsWith('call_if_')){const suffix=op.replace(/^(goto|call)_if_/,'');let yes=false,target='';if(suffix==='set'||suffix==='unset'){yes=Boolean(state.flags[indirect(a[0],'FLAG_')])===(suffix==='set');target=a[1];}else if(a.length===1){yes=condition(suffix,session.compare,0);target=a[0];}else{yes=condition(suffix,v(0),v(1));target=a[2];}if(yes&&!jump(target,op.startsWith('call'))){session.pc--;return{status:'unsupported',command:instruction};}continue;}
  if(op==='goto_if'||op==='call_if'){if(condition(({0:'lt',1:'eq',2:'gt',3:'le',4:'ge',5:'ne'} as Record<number,string>)[v(0)]||a[0],session.compare,0)&&!jump(a[1],op==='call_if')){session.pc--;return{status:'unsupported',command:instruction};}continue;}
  if(op==='compare'||op==='compare_var_to_value'||op==='compare_var_to_var'){session.compare=v(0)-v(1);continue;}
  if(op==='switch'){session.switchValue=v(0);continue;}
  if(op==='case'){if(session.switchValue===v(0)&&!jump(a[1])){session.pc--;return{status:'unsupported',command:instruction};}continue;}
  if(op==='setvar'||op==='copyvar'||op==='setorcopyvar'){state.vars[a[0]]=v(1);continue;}
  if(op==='addvar'||op==='subvar'){state.vars[a[0]]=((state.vars[a[0]]||0)+(op==='addvar'?v(1):-v(1)))&65535;continue;}
  if(op==='setflag'||op==='clearflag'){state.flags[indirect(a[0],'FLAG_')]=op==='setflag';continue;}
  if(op==='checkflag'){session.compare=state.flags[indirect(a[0],'FLAG_')]?1:0;state.vars.VAR_RESULT=session.compare;continue;}
  if(op==='checktrainerflag'){session.compare=state.trainerFlags?.[a[0]]?1:0;continue;}
  if(op==='settrainerflag'||op==='cleartrainerflag'){(state.trainerFlags??={})[a[0]]=op==='settrainerflag';continue;}
  if(op==='checkplayergender'){state.vars.VAR_RESULT=state.gender||0;continue;}
  if(op==='setberrytree'){(state.berries??={})[a[0]]={item:a[1].replace(/^ITEM_TO_BERRY\((.*)\)$/,'$1'),stage:a[2]};continue;}
  if(op==='random'){state.vars.VAR_RESULT=Math.floor(emeraldRandom(state)*Math.max(1,v(0)));continue;}
  if(['additem','giveitem','removeitem','checkitem','checkitemspace'].includes(op)){const inventory=state.inventory??={};const item=indirect(a[0],'ITEM_');const quantity=a[1]?v(1):1;if(op==='removeitem'){state.vars.VAR_RESULT=(inventory[item]||0)>=quantity?1:0;if(state.vars.VAR_RESULT)inventory[item]-=quantity;}else if(op==='checkitem')state.vars.VAR_RESULT=(inventory[item]||0)>=quantity?1:0;else if(op==='checkitemspace')state.vars.VAR_RESULT=1;else{inventory[item]=(inventory[item]||0)+quantity;state.vars.VAR_RESULT=1;if(op==='giveitem'&&hooks.say)await hooks.say(`Received ${quantity} ${item.replace(/^ITEM_/,'').replaceAll('_',' ')}.`,item);}continue;}
  if(['addmoney','givemoney','removemoney','takemoney','checkmoney'].includes(op)){if(op==='checkmoney')state.vars.VAR_RESULT=(state.money||0)>=v(0)?1:0;else state.money=Math.max(0,(state.money||0)+((op==='removemoney'||op==='takemoney')?-v(0):v(0)));continue;}
  if(['lock','lockall','release','releaseall','faceplayer','waitmessage','waitbuttonpress','closemessage','delay','waitstate','waitmovement','waitse','waitfanfare','playse','playfanfare','playbgm','savebgm','fadedefaultbgm','fadeoutbgm','fadeinbgm','showmoneybox','hidemoneybox','updatemoneybox','incrementgamestat'].includes(op))continue;
  let hook:((...args:never[])=>unknown)|undefined;let params:unknown[]=[op,a];
  if(op==='msgbox'&&(a[1]==='MSGBOX_YESNO'||value(a[1])===5)){
   if(!hooks.say||!hooks.choice){session.pc--;return{status:'unsupported',command:instruction};}
   await hooks.say(emeraldText(a[0],state,db),a[0]);hook=hooks.choice as typeof hook;
  }
  else if(op==='msgbox'||op==='message'){hook=hooks.say as typeof hook;params=[emeraldText(a[0],state,db),a[0]];}
  else if(/yesnobox|multichoice/.test(op))hook=hooks.choice as typeof hook;
  else if(/^(trainerbattle|wildbattle|dowildbattle|setwildbattle)/.test(op))hook=hooks.battle as typeof hook;
  else if(/^warp/.test(op))hook=hooks.warp as typeof hook;
  else if(/movement|object|sprite|turnobject/.test(op))hook=hooks.move as typeof hook;
  else if(/^(special|specialvar|pokemart|givemon|giveegg|setmetatile|setweather|doweather|fadescreen|fadescreenspeed|setflashlevel|dofieldeffect)/.test(op))hook=hooks.service as typeof hook;
  else hook=hooks.action as typeof hook;
  if(!hook){session.pc--;return{status:'unsupported',command:instruction};}
  const result=await hook(...params as never[]) as EmeraldHookResult;
  if(typeof result==='number')state.vars[op==='specialvar'?a[0]:'VAR_RESULT']=result;
  if(result&&typeof result==='object'){if(result.result!==undefined)state.vars[op==='specialvar'?a[0]:'VAR_RESULT']=result.result;if(result.wait){session.pending=instruction;return{status:'waiting',command:instruction};}}
 }
 return{status:session.ended?'ended':'budget'};
}
