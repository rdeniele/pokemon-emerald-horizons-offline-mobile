"use client";
import KeyIcon from "./KeyIcon";
import {getEmpressSprite} from "@/pokemon/sprites/resolver";
import ControlGuide from "./ControlGuide";
import {getAudio,type AudioLike} from "@/game/audio";
import {moveBehaviorLabel} from "@/pokemon/moves/behavior";
import {FULL_ARENA_CAMERA,followBattleCamera,cameraToWorld} from "./battleCamera";
import {combatAnimations,animationDirection,drawCombatAnimation,type AnimationState} from "./combatAnimation";
import {drawMoveEffect} from "./moveEffects";
import BattleParty from "./BattleParty";
import {useEffect,useRef,useState,type PointerEvent as ReactPointerEvent} from "react";
import type {BattleEngine} from "@/battle/engine/BattleEngine";
import type {Side, BattleUnit} from "@/battle/types";
import type {ArenaSnapshot, ClientInput} from "@/battle/viewProtocol";
import type {BattleEvent} from "@/battle/events/types";
import {speedMultiplier} from "@/battle/systems/StatusSystem";
import {blockedLine} from "@/battle/field";
import {getArena} from "@/battle/arenas";
import {SPECIES} from "@/pokemon/species/species";
import {typeEffectiveness} from "@/pokemon/types/typeChart";
import {arenaMoveProfile,isDashMove} from "@/pokemon/moves/arenaProfile";

interface Props {spectator?:boolean;engine?:BattleEngine; remote?:ArenaSnapshot; side?:Side; send?:(input:Omit<ClientInput,"type"|"seq">)=>void; onFinish?:(winner:Side)=>void; onLeave:()=>void; title:string;wild?:boolean;initialPaused?:boolean;initialAuto?:boolean;onCheckpoint?:(engine:BattleEngine,paused:boolean,auto:boolean)=>void;onItems?:(engine:BattleEngine)=>void}
const COLORS:Record<string,string>={fire:"#f06828",water:"#38a8f0",grass:"#70c838",electric:"#f8d830",psychic:"#ef68a8",ice:"#9ee8f0",ghost:"#9860c8",dark:"#806870",ground:"#b89050",rock:"#c8b870",normal:"#eee0c0",poison:"#bc63ca",bug:"#a9c34a",flying:"#bbd9ee",fighting:"#da7655",steel:"#b9d2df",dragon:"#897bf0",fairy:"#f5a9d5"};
const spriteUrl=getEmpressSprite;
export default function ArenaCanvas({engine,remote,side="player",send,onFinish,onLeave,title,spectator=false,wild=false,initialPaused=false,initialAuto=false,onCheckpoint,onItems}:Props) {
  const canvas=useRef<HTMLCanvasElement>(null);
  const crosshair=useRef<SVGSVGElement>(null);
  const consoleRef=useRef<HTMLElement>(null);
  const [fullscreen,setFullscreen]=useState(false);
  useEffect(()=>{const changed=()=>setFullscreen(document.fullscreenElement===consoleRef.current);document.addEventListener("fullscreenchange",changed);return()=>document.removeEventListener("fullscreenchange",changed);},[]);
  useEffect(()=>{
    const host=consoleRef.current?.closest<HTMLElement>(".stage-workspace")??consoleRef.current;
    if(!host)return;
    const previous=host.style.getPropertyValue("--battle-viewport-height");
    const viewport=window.visualViewport;
    const fit=()=>{
      const height=Math.min(window.innerHeight,document.documentElement.clientHeight,viewport?.height??Infinity);
      host.style.setProperty("--battle-viewport-height",`${Math.floor(height)}px`);
    };
    fit();window.addEventListener("resize",fit);viewport?.addEventListener("resize",fit);
    return()=>{window.removeEventListener("resize",fit);viewport?.removeEventListener("resize",fit);if(previous)host.style.setProperty("--battle-viewport-height",previous);else host.style.removeProperty("--battle-viewport-height");};
  },[]);
  const current=useRef(remote);
  const commands=useRef(send);
  const finish=useRef(onFinish);
  useEffect(()=>{current.current=remote;commands.current=send;finish.current=onFinish;},[remote,send,onFinish]);
  const input=useRef({x:0,y:0});
  const aim=useRef<{x:number;y:number}|undefined>(undefined);
  const [units,setUnits]=useState<BattleUnit[]>([]);
  const [time,setTime]=useState(0);
  const [auto,setAuto]=useState(initialAuto);
  const autoRef=useRef(initialAuto),paused=useRef(initialPaused),[pauseState,setPauseState]=useState(initialPaused);
  const checkpoint=useRef(onCheckpoint),itemCallback=useRef(onItems);checkpoint.current=onCheckpoint;itemCallback.current=onItems;
  const recallUntil=useRef(0);
  const aimDirection=useRef<{x:number;y:number}|undefined>(undefined);
  const stickOwners=useRef<{move?:number;aim?:number}>({});
  const switchTimer=useRef<ReturnType<typeof setTimeout>|null>(null),[recalling,setRecalling]=useState(false);
  const saveBattle=()=>{if(engine)checkpoint.current?.(engine,paused.current,autoRef.current);};
  const togglePause=(value:boolean)=>{paused.current=value;setPauseState(value);input.current={x:0,y:0};stickOwners.current={};consoleRef.current?.querySelectorAll<HTMLElement>('.mobile-joystick span').forEach(knob=>knob.style.transform='');engine?.setMovement(side,0,0);saveBattle();};
  useEffect(()=>{const previous=window.pauseGame;window.pauseGame=()=>togglePause(true);const visibility=()=>{if(document.hidden)togglePause(true);};document.addEventListener('visibilitychange',visibility);window.addEventListener('pagehide',saveBattle);return()=>{if(switchTimer.current)clearTimeout(switchTimer.current);saveBattle();window.pauseGame=previous;document.removeEventListener('visibilitychange',visibility);window.removeEventListener('pagehide',saveBattle);};},[engine]);
  const [feedback,setFeedback]=useState("Close in for contact moves. Create space for ranged moves.");
  const seq=useRef(0);
  const act=useRef<(move?:number,dodge?:boolean,switchId?:string)=>void>(()=>{});
  useEffect(()=>{
    const node=canvas.current,ctx=node?.getContext("2d");if(!node||!ctx)return;
    node.focus();
    const audio=getAudio(),sounds=new Map<number,AudioLike>();let musicArena="";
    const keys=new Set<string>(),images=new Map<number,HTMLImageElement>(),positions=new Map<string,{x:number;y:number}>();
    const deployedTimes=new Map<string,number>(),previouslyDeployed=new Set<string>();
    const facing=new Map<string,number>();
    const directions=new Map<string,number>(),sheets=new Map<string,HTMLImageElement>();
    const actions=new Map<string,{state:AnimationState;at:number;until:number}>();
    const effects:{from:{x:number;y:number};to:{x:number;y:number};at:number;travel?:number;speciesId?:number;kind:"melee"|"ranged"|"hit"|"dodge"|"buff";color:string;label?:string;behavior?:import("@/pokemon/moves/behavior").MoveBehavior;radius?:number;attackId?:number;attackIds?:number[];moveName?:string}[]=[];
    const reduced=window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    let raf=0,last=performance.now(),hud=0,lastSend=0,lastCheckpoint=0,ended=false,lastTick=-1,received=performance.now();
    const move=()=>{input.current={x:Number(keys.has("d"))-Number(keys.has("a")),y:Number(keys.has("s"))-Number(keys.has("w"))};};
    let camera={...FULL_ARENA_CAMERA},pointerScreen:{x:number;y:number}|undefined;
    const updatePointerAim=()=>{if(aimDirection.current){const unit=engine?.deployedUnits(side)[0]??current.current?.units.find(u=>u.side===side&&u.alive&&u.deployed);if(unit)aim.current={x:unit.x+aimDirection.current.x*24,y:unit.y+aimDirection.current.y*24};return;}if(!pointerScreen)return;const p=cameraToWorld(camera,pointerScreen);aim.current={x:Math.max(0,Math.min(17,(p.x-35)/650*17)),y:Math.max(0,Math.min(11,(p.y-35)/350*11))};};
    const command=(slot?:number,dodge?:boolean,switchId?:string)=>{
      if(ended||spectator||paused.current)return;
      updatePointerAim();
      if(engine){const unit=engine.deployedUnits(side)[0];if(!unit)return;
        if(switchId){recallUntil.current=performance.now()+250;setRecalling(true);switchTimer.current=setTimeout(()=>{engine.switchUnit(side,unit.spec.id,switchId);saveBattle();setRecalling(false);},250);return;}
        else if(dodge)engine.commandDodge(unit.spec.id,input.current.x,input.current.y);
        else if(slot!==undefined && !engine.commandMove(unit.spec.id,slot,aim.current))setFeedback("Move cooling down, out of range, or temporarily stunned.");
        saveBattle();
      } else commands.current?.({...input.current,aim:aim.current,move:slot,dodge,switchId});
    };
    act.current=command;
    const down=(event:KeyboardEvent)=>{
      if(spectator)return;
      if(event.target instanceof HTMLInputElement||event.target instanceof HTMLTextAreaElement||event.target instanceof HTMLSelectElement)return;
      if(["w","a","s","d","q","e","r","x"," "].includes(event.key.toLowerCase()))event.preventDefault();
      if(/^[1-6]$/.test(event.key)){event.preventDefault();const roster=engine?[...engine.state.units.values()]:current.current?.units??[];const chosen=roster.filter(u=>u.side===side)[Number(event.key)-1];if(chosen?.alive&&!chosen.deployed)command(undefined,false,chosen.spec.id);return;}
      keys.add(event.key.toLowerCase());move();if(event.repeat)return;
      const slot="qerx".indexOf(event.key.toLowerCase());if(slot>=0)command(slot);if(event.code==="Space")command(undefined,true);
    };
    const up=(event:KeyboardEvent)=>{keys.delete(event.key.toLowerCase());move();};
    const hideCrosshair=()=>{if(crosshair.current)crosshair.current.style.visibility="hidden";pointerScreen=undefined;node.style.cursor="crosshair";};
    const blur=()=>{if(engine&&!ended)togglePause(true);hideCrosshair();keys.clear();input.current={x:0,y:0};engine?.setMovement(side,0,0);commands.current?.({x:0,y:0});};
    const pointer=(event:PointerEvent)=>{if(spectator)return;aimDirection.current=undefined;const rect=node.getBoundingClientRect(),scale=Math.min(rect.width/720,rect.height/420),x=(event.clientX-rect.left-(rect.width-720*scale)/2)/scale,y=(event.clientY-rect.top-(rect.height-420*scale)/2)/scale;if(x<0||x>720||y<0||y>420){hideCrosshair();node.style.cursor="default";return;}pointerScreen={x,y};if(crosshair.current){crosshair.current.style.left=`${event.clientX-rect.left}px`;crosshair.current.style.top=`${event.clientY-rect.top}px`;crosshair.current.style.visibility="visible";node.style.cursor="none";}updatePointerAim();};
    node.addEventListener("pointerleave",hideCrosshair);node.addEventListener("pointermove",pointer);node.addEventListener("pointerdown",pointer);
    window.addEventListener("resize",hideCrosshair);window.addEventListener("keydown",down);window.addEventListener("keyup",up);window.addEventListener("blur",blur);
    const pos=(u:BattleUnit)=>({x:35+u.x/17*650,y:35+u.y/11*350});
    const events=(list:BattleEvent[],all:BattleUnit[],now:number)=>{
      for(const event of list){
        if(event.type==="MOVE_AIMED"){directions.set(event.source,animationDirection(event.x-event.fromX,event.y-event.fromY));actions.set(event.source,{state:event.behavior==="meteors"||event.behavior==="vortex"?"special":event.delivery==="melee"?"attack":"shoot",at:now,until:now+Math.max(450,event.behavior&&["beam","flame","water","wind"].includes(event.behavior)?event.travel:450)});}
        if(event.type==="SKILL_USED"&&!event.aimed)actions.set(event.source,{state:"special",at:now,until:now+550});
        if(event.type==="DAMAGE_DEALT"&&event.amount>0)actions.set(event.target,{state:"hurt",at:now,until:now+240});
        if(event.type==="CLASH_RESOLVED"){
          const point={x:35+event.x/17*650,y:35+event.y/11*350};
          effects.push({from:point,to:point,at:now,kind:"buff",color:event.moveType?COLORS[event.moveType]:"#fff5b0",label:event.winner?"BREAKTHROUGH!":"DRAW!"});
          audio?.playSfx("clash");
          setFeedback(event.winner?`${all.find(u=>u.spec.id===event.winner)?.spec.name??"Pokémon"} wins the clash with its ${event.moveType}-type move!`:"Even matchup! Both attacks canceled.");continue;
        }
        if(event.type==="MOVE_ENDED"){sounds.get(event.attackId)?.pause();sounds.delete(event.attackId);for(let i=effects.length-1;i>=0;i--)if(effects[i].attackId===event.attackId||effects[i].attackIds?.includes(event.attackId))effects.splice(i,1);continue;}
        if(event.type==="ATTACK_CLASH"){for(const id of event.attackIds){sounds.get(id)?.pause();sounds.delete(id);}audio?.playSfx("clash");
          const point={x:35+event.x/17*650,y:35+event.y/11*350};
          for(let i=effects.length-1;i>=0;i--)if(effects[i].attackId!==undefined&&event.attackIds.includes(effects[i].attackId!)){
            if(event.duration){effects[i].to=point;if(event.kind==="sphere"&&effects[i].kind==="ranged"){const dx=effects[i].from.x-point.x,dy=effects[i].from.y-point.y,d=Math.hypot(dx,dy)||1;const held={x:point.x+dx/d*12,y:point.y+dy/d*12};effects[i].from=held;effects[i].to=held;}effects[i].at=now;effects[i].travel=event.duration;}
            else effects.splice(i,1);
          }
          effects.push({from:point,to:point,at:now,travel:event.duration,attackIds:event.attackIds,kind:"buff",color:"#fff5b0",label:event.duration?`${(event.kind??"beam").toUpperCase()} CLASH!`:"CLASH!"});setFeedback(event.duration?"Clash locked! Dodge or switch to disengage.":"Clash! Both attacks canceled.");continue;
        }
        if(event.type==="POTION_PICKED_UP"){effects.push({from:{x:35+event.x/17*650,y:35+event.y/11*350},to:{x:35+event.x/17*650,y:35+event.y/11*350},at:now,kind:"buff",color:"#65e3b3",label:`+${event.amount} HP`});setFeedback("Potion collected! Health restored.");continue;}
        if(event.type==="MOVE_AIMED"){const sound=audio?.playMoveSfx(event.moveName??"Attack",event.moveType);if(sound&&event.attackId!==undefined){sounds.set(event.attackId,sound);if(sounds.size>32)sounds.delete(sounds.keys().next().value!);}effects.push({from:{x:35+event.fromX/17*650,y:35+event.fromY/11*350},to:{x:35+event.x/17*650,y:35+event.y/11*350},at:now,travel:event.travel,kind:event.delivery,color:COLORS[event.moveType]??"#f8e878",behavior:event.behavior,radius:event.radius,attackId:event.attackId,moveName:event.moveName});continue;}
        if(event.type==="ATTACK_STARTED"||event.type==="SKILL_USED"){
          if(event.aimed)continue;
          const source=all.find(u=>u.spec.id===event.source);
          const target=all.find(u=>u.spec.id===(event.type==="ATTACK_STARTED"?event.target:source?.targetId));
          if(!source)continue;
          const soundMove=event.type==="SKILL_USED"?source.spec.skills.find(s=>s.id===event.skillId):source.spec.basic;
          if(soundMove)audio?.playMoveSfx(soundMove.name,soundMove.type,"kind" in soundMove&&soundMove.kind==="buff");
          if(event.type==="SKILL_USED"&&source.spec.skills.find(s=>s.id===event.skillId)?.kind==="buff"){effects.push({from:pos(source),to:pos(source),at:now,kind:"buff",color:"#fff090",label:"BUFF"});setFeedback(`${source.spec.name} used ${event.name}: empowered for 5 seconds.`);continue;}
          if(!target)continue;
          const skill=event.type==="SKILL_USED"?source.spec.skills.find(s=>s.id===event.skillId):source.spec.basic;
          if(!skill)continue;
          effects.push({from:pos(source),to:pos(target),at:now,travel:180+Math.hypot(source.x-target.x,source.y-target.y)*70,kind:arenaMoveProfile(skill.name,"range"in skill&&typeof skill.range==="number"?skill.range:source.spec.attackRange).delivery,color:COLORS[skill.type]??"#f8e878"});
        }
        if(event.type==="POKEMON_FAINTED")audio?.playSfx("faint");
        if(event.type==="POKEMON_DASHED")audio?.playSfx("dodge");
        if(event.type==="DAMAGE_DEALT"){if(event.amount>0)audio?.playSfx("hit");
          const target=all.find(u=>u.spec.id===event.target);if(!target)continue;
          const label=event.effectiveness===0?"NO EFFECT":event.effectiveness>1?`-${event.amount} SUPER!`:event.effectiveness<1?`-${event.amount} resisted`:`-${event.amount}`;
          effects.push({from:pos(target),to:pos(target),at:now,kind:"hit",color:event.effectiveness>1?"#ffe078":"#fff",label});
          setFeedback(`${SPECIES[target.spec.speciesId]?.name}: ${label}`);
        }
        if(event.type==="POKEMON_DASHED")effects.push({from:{x:35+event.fromX/17*650,y:35+event.fromY/11*350},to:{x:35+event.x/17*650,y:35+event.y/11*350},at:now,speciesId:all.find(u=>u.spec.id===event.unitId)?.spec.speciesId,kind:"dodge",color:"#d8ffff"});
      }
      if(effects.length>100)effects.splice(0,effects.length-100);
    };
    const frame=(now:number)=>{
      const dt=Math.min((now-last)/1000,0.1);last=now;
      let state=current.current;
      if(engine){engine.setMovement(side,input.current.x,input.current.y);if(!paused.current)engine.advance(dt);if(now-lastCheckpoint>750){saveBattle();lastCheckpoint=now;}state={potions:engine.state.potions,tick:++seq.current,time:engine.state.time,units:[...engine.state.units.values()],events:engine.drainEvents(),result:engine.state.result};}
      else if(!spectator && now-lastSend>=50){commands.current?.({...input.current,aim:aim.current});lastSend=now;}
      if(state){
        const arena=getArena(engine?.state.arenaId??state.arenaId);
        if(musicArena!==arena.id&&!ended){musicArena=arena.id;audio?.playArenaMusic(arena.type);}
        if(state.tick!==lastTick){events(state.events,state.units,now);lastTick=state.tick;received=now;}
        if(now-hud>80){setUnits(state.units.map(u=>({...u,skillCooldowns:{...u.skillCooldowns}})));setTime(state.time);hud=now;}
        const cameraPoints=state.units.filter(u=>u.alive&&u.deployed).flatMap(u=>[pos(u),...(u.travelMove?[{x:35+u.travelMove.x/17*650,y:35+u.travelMove.y/11*350}]:[])]);
        camera=followBattleCamera(camera,cameraPoints,dt,reduced);updatePointerAim();
        ctx.save();ctx.translate(360,210);ctx.scale(camera.zoom,camera.zoom);ctx.translate(-camera.x,-camera.y);
        ctx.imageSmoothingEnabled=false;ctx.fillStyle=arena.floor;ctx.fillRect(0,0,720,420);
        // Emerald field palette, tiled grass and chalk boundary keep attack silhouettes legible.
        for(let y=0;y<420;y+=16)for(let x=0;x<720;x+=16){ctx.fillStyle=((x/16+y/16)%3===0)?arena.tile:arena.floor;ctx.fillRect(x,y,16,16);if(arena.id==="meadow"||arena.type==="flying"){ctx.fillStyle=arena.edge;ctx.globalAlpha=.25;ctx.fillRect(x+4,y+11,3,2);ctx.globalAlpha=1;}}
        ctx.strokeStyle=arena.line;ctx.lineWidth=1;ctx.globalAlpha=.22;
        if(arena.type==="water"){for(let y=45;y<400;y+=40){ctx.beginPath();for(let x=25;x<700;x+=8){const wy=y+Math.sin(x/24)*4;if(x===25)ctx.moveTo(x,wy);else ctx.lineTo(x,wy);}ctx.stroke();}}
        else if(arena.type==="electric"){for(let x=40;x<700;x+=80){ctx.beginPath();ctx.moveTo(x,25);ctx.lineTo(x,180);ctx.lineTo(x+28,180);ctx.lineTo(x+28,395);ctx.stroke();}}
        else if(arena.id!=="meadow"){for(let x=24;x<700;x+=48)for(let y=24;y<400;y+=48)ctx.strokeRect(x,y,48,48);}
        ctx.globalAlpha=1;ctx.fillStyle=arena.edge;ctx.fillRect(0,0,720,16);ctx.fillRect(0,404,720,16);
        ctx.strokeStyle=arena.line;ctx.lineWidth=3;ctx.strokeRect(23,23,674,374);
        ctx.beginPath();ctx.ellipse(360,210,54,38,0,0,Math.PI*2);ctx.stroke();
        for(const o of engine?.state.obstacles??arena.obstacles){const x=35+o.x/17*650,y=35+o.y/11*350,w=o.w/17*650,h=o.h/11*350;ctx.fillStyle=arena.edge;ctx.fillRect(x+3,y+5,w,h);ctx.fillStyle=arena.cover;ctx.fillRect(x,y,w,h);ctx.fillStyle=arena.highlight;ctx.fillRect(x+3,y+3,w-6,5);
          ctx.strokeStyle=arena.edge;ctx.lineWidth=3;
          if(arena.obstacleStyle==="crate"){ctx.strokeRect(x+4,y+4,w-8,h-8);ctx.beginPath();ctx.moveTo(x+4,y+4);ctx.lineTo(x+w-4,y+h-4);ctx.moveTo(x+w-4,y+4);ctx.lineTo(x+4,y+h-4);ctx.stroke();}
          if(arena.obstacleStyle==="pillar"){ctx.fillStyle=arena.edge;ctx.fillRect(x+w*.3,y+10,3,h-15);ctx.fillRect(x+w*.65,y+10,3,h-15);}
          if(arena.obstacleStyle==="crystal"){ctx.fillStyle=arena.highlight;ctx.beginPath();ctx.moveTo(x+w/2,y-9);ctx.lineTo(x+w-4,y+h/2);ctx.lineTo(x+w/2,y+h-4);ctx.lineTo(x+4,y+h/2);ctx.closePath();ctx.fill();}
          if(arena.obstacleStyle==="tree"){ctx.fillStyle=arena.edge;ctx.fillRect(x+w*.4,y+h*.45,w*.2,h*.55);ctx.fillStyle=arena.highlight;ctx.fillRect(x-3,y-5,w+6,h*.6);ctx.fillStyle=arena.cover;ctx.fillRect(x+3,y+3,w-6,h*.4);}
        }
        for(const potion of state.potions??[]){const x=35+potion.x/17*650,y=35+potion.y/11*350;ctx.fillStyle="#fff7ca";ctx.strokeStyle="#38674c";ctx.lineWidth=2;ctx.beginPath();ctx.ellipse(x,y+12,15,7,0,0,Math.PI*2);ctx.stroke();ctx.fillStyle="#e95c8b";ctx.fillRect(x-8,y-8,16,20);ctx.strokeRect(x-8,y-8,16,20);ctx.fillStyle="#f9efb9";ctx.fillRect(x-5,y-13,10,5);ctx.fillStyle="#fff";ctx.fillRect(x-5,y,10,3);ctx.fillRect(x-1.5,y-3.5,3,10);ctx.font="bold 10px monospace";ctx.textAlign="center";ctx.fillStyle="#243d38";ctx.fillText("+20% HP",x,y-20);}
        for(const unit of state.units.filter(u=>u.alive&&u.deployed).sort((a,b)=>a.y-b.y)){
          if(!previouslyDeployed.has(unit.spec.id))deployedTimes.set(unit.spec.id,now);
          const target=pos(unit);
          if(!engine && !spectator && unit.side===side && !ended && !unit.travelMove && state.time>=(unit.channelUntil??0)){
            const age=Math.min(.1,(now-received)/1000),length=Math.max(1,Math.hypot(input.current.x,input.current.y));
            const speed=unit.spec.movementSpeed*speedMultiplier(unit,state.time);
            const nx=Math.max(0,Math.min(17,unit.x+input.current.x/length*speed*age)),ny=Math.max(0,Math.min(11,unit.y+input.current.y/length*speed*age));
            if(!blockedLine(arena.obstacles,unit,{x:nx,y:ny},.32)){target.x=35+nx/17*650;target.y=35+ny/11*350;}
          }
          const old=positions.get(unit.spec.id)??target;
          const dx=target.x-old.x,dy=target.y-old.y,moving=Math.hypot(dx,dy)>.3;
          if(moving)directions.set(unit.spec.id,animationDirection(dx,dy));
          if(Math.abs(dx)>.3)facing.set(unit.spec.id,dx>0?-1:1);
          if(unit.side===side&&aim.current){directions.set(unit.spec.id,animationDirection(aim.current.x-unit.x,aim.current.y-unit.y));const ax=35+aim.current.x/17*650;if(Math.abs(ax-old.x)>4)facing.set(unit.spec.id,ax>old.x?-1:1);}
          const factor=reduced?1:Math.min(1,dt*24);old.x+=dx*factor;old.y+=dy*factor;positions.set(unit.spec.id,old);
          const action=actions.get(unit.spec.id);
          const animationState:AnimationState=unit.statuses.some(s=>s.kind==="sleep")?"sleep":action&&now<action.until?action.state:moving?"walk":"idle";
          const authored=combatAnimations[unit.spec.speciesId];
          if(authored)for(const entry of Object.values(authored)){if(!sheets.has(entry.src)){const preload=new Image();preload.src=entry.src;sheets.set(entry.src,preload);}}
          const sheet=authored?.[animationState]??authored?.idle;
          let sheetImage:HTMLImageElement|undefined;
          if(sheet){sheetImage=sheets.get(sheet.src);if(!sheetImage){sheetImage=new Image();sheetImage.src=sheet.src;sheets.set(sheet.src,sheetImage);}}
          let image=images.get(unit.spec.speciesId);if(!image){image=new Image();image.src=spriteUrl(unit.spec.speciesId);images.set(unit.spec.speciesId,image);}
          if(unit.buff&&state.time<unit.buff.until){ctx.strokeStyle="#ffe878";ctx.lineWidth=3;ctx.beginPath();ctx.ellipse(old.x,old.y+12,34,18,0,0,Math.PI*2);ctx.stroke();}
          ctx.fillStyle=unit.side===side?"#2868a8":"#c84840";ctx.globalAlpha=.45;ctx.beginPath();ctx.ellipse(old.x,old.y+24,30,8,0,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;
          const phase=unit.travelMove&&state.time<unit.travelMove.until?unit.travelMove:undefined;
          if(phase){const tx=35+phase.x/17*650,ty=35+phase.y/11*350;ctx.strokeStyle=phase.kind==="fly"?"#f5f4cf":"#987151";ctx.setLineDash([6,5]);ctx.beginPath();ctx.ellipse(tx,ty,1.8*650/17,1.8*350/11,0,0,Math.PI*2);ctx.stroke();ctx.setLineDash([]);ctx.font="bold 11px monospace";ctx.fillStyle="#243d38";ctx.fillText(phase.kind.toUpperCase(),tx,ty);if(phase.kind!=="fly"){ctx.fillStyle="#665444";ctx.beginPath();ctx.ellipse(old.x,old.y+12,18,8,0,0,Math.PI*2);ctx.fill();}}
          ctx.save();const materialize=Math.min(1,(now-(deployedTimes.get(unit.spec.id)??now))/500);if(!reduced){ctx.globalAlpha=materialize;ctx.filter=materialize<.5?"brightness(5)":"none";if(unit.side===side&&now<recallUntil.current){ctx.globalAlpha=Math.max(0,(recallUntil.current-now)/250);ctx.filter="brightness(5)";}}
          if(phase&&phase.kind!=="fly"){/* Underground, submerged or vanished until impact. */}
          else if(sheet&&sheetImage&&drawCombatAnimation(ctx,sheetImage,sheet,action&&now<action.until?now-action.at:now,directions.get(unit.spec.id)??(unit.side===side?2:6),old.x,old.y-(phase?45:0),animationState==="idle"||animationState==="walk"||animationState==="sleep",reduced)){/* Authored directional pixel animation. */}
          else if(image.complete&&image.naturalWidth){const scale=76/Math.max(image.naturalWidth,image.naturalHeight),stride=moving&&!reduced?Math.sin(now*.024):0;ctx.save();ctx.translate(old.x,old.y-Math.abs(stride)*3-(phase?(reduced?35:55+Math.sin(now*.004)*5):0));ctx.scale(facing.get(unit.spec.id)??(unit.side===side?-1:1),1);ctx.rotate(stride*.045);ctx.drawImage(image,-image.naturalWidth*scale/2,-image.naturalHeight*scale/2,image.naturalWidth*scale,image.naturalHeight*scale);ctx.restore();}
          else{ctx.fillStyle=COLORS[unit.spec.types[0]]??"#f8e878";ctx.fillRect(old.x-20,old.y-20,40,40);}
          ctx.restore();
          ctx.fillStyle="#183c38";ctx.fillRect(old.x-35,old.y-52,70,7);ctx.fillStyle=unit.hp/unit.maxHp<.25?"#e87858":"#58d890";ctx.fillRect(old.x-33,old.y-50,66*unit.hp/unit.maxHp,3);
          ctx.font="bold 11px monospace";ctx.textAlign="center";ctx.fillStyle="#163c30";ctx.fillText(unit.spec.name,old.x,old.y-60);
          if(unit.statuses.some(s=>s.kind==="sleep"||s.kind==="root")){ctx.fillStyle="#5c447e";ctx.fillText(unit.statuses.some(s=>s.kind==="sleep")?"SLEEP · Zzz":"BOUND",old.x,old.y+40);}
        }
        previouslyDeployed.clear();for(const u of state.units)if(u.alive&&u.deployed)previouslyDeployed.add(u.spec.id);
        for(let i=effects.length-1;i>=0;i--){const fx=effects[i],age=now-fx.at,lifetime=Math.max(650,(fx.travel??0)+400);if(age<0)continue;if(age>lifetime){effects.splice(i,1);continue;}const t=Math.min(1,Math.max(0,(age-180)/Math.max(1,(fx.travel??400)-180)));ctx.globalAlpha=Math.max(0,1-age/lifetime);ctx.strokeStyle=fx.color;ctx.fillStyle=fx.color;
          if(drawMoveEffect(ctx,fx,age,reduced,engine?.state.obstacles??arena.obstacles))continue;
          if(fx.kind==="ranged"&&t<1){const dx=fx.to.x-fx.from.x,dy=fx.to.y-fx.from.y,x=fx.from.x+dx*t,y=fx.from.y+dy*t;ctx.save();ctx.translate(x,y);ctx.rotate(Math.atan2(dy,dx));ctx.beginPath();ctx.ellipse(0,0,12,6,0,0,Math.PI*2);ctx.fill();ctx.fillStyle="#fff9d8";ctx.fillRect(-3,-2,7,4);ctx.restore();if(!reduced){for(let n=1;n<=4;n++){ctx.globalAlpha=(1-n/5)*.65;ctx.fillStyle=fx.color;ctx.fillRect(x-dx*.025*n-3,y-dy*.025*n-3,6,6);}}}
          if(fx.label?.includes("CLASH!")){ctx.lineWidth=3;for(let n=0;n<10;n++){const a=n*Math.PI/5,r=reduced?28:25+Math.sin(age*.03)*12;ctx.beginPath();ctx.moveTo(fx.to.x+Math.cos(a)*10,fx.to.y+Math.sin(a)*10);ctx.lineTo(fx.to.x+Math.cos(a)*r,fx.to.y+Math.sin(a)*r);ctx.stroke();}}
          if(fx.kind==="buff"){ctx.lineWidth=3;ctx.beginPath();ctx.ellipse(fx.to.x,fx.to.y,30+t*15,22+t*10,0,0,Math.PI*2);ctx.stroke();}
          if(fx.kind==="melee"){ctx.lineWidth=2;ctx.beginPath();ctx.ellipse(fx.from.x,fx.from.y,42,32,0,0,Math.PI*2);ctx.stroke();ctx.lineWidth=5;ctx.beginPath();ctx.moveTo(fx.to.x-22,fx.to.y+18);ctx.lineTo(fx.to.x+22,fx.to.y-18);ctx.stroke();}
          if(fx.kind==="dodge"&&!reduced&&age<250){
            const fade=1-age/250,dx=fx.to.x-fx.from.x,dy=fx.to.y-fx.from.y,image=fx.speciesId?images.get(fx.speciesId):undefined;
            ctx.globalAlpha=fade*.7;ctx.lineWidth=3;
            for(const offset of [-8,0,8]){ctx.beginPath();ctx.moveTo(fx.from.x,fx.from.y+offset);ctx.lineTo(fx.to.x,fx.to.y+offset);ctx.stroke();}
            if(image?.complete&&image.naturalWidth){const scale=76/Math.max(image.naturalWidth,image.naturalHeight);for(let n=0;n<3;n++){ctx.globalAlpha=fade*(.12+n*.08);const x=fx.from.x+dx*n/3,y=fx.from.y+dy*n/3;ctx.drawImage(image,x-image.naturalWidth*scale/2,y-image.naturalHeight*scale/2,image.naturalWidth*scale,image.naturalHeight*scale);}}
          }
          if(fx.label){ctx.font="bold 14px monospace";ctx.textAlign="center";ctx.strokeStyle="#183c38";ctx.lineWidth=3;const y=fx.to.y-20-(reduced?0:age*.04);ctx.strokeText(fx.label,fx.to.x,y);ctx.fillText(fx.label,fx.to.x,y);}
        }ctx.globalAlpha=1;
        if(aimDirection.current&&!spectator){const unit=state.units.find(u=>u.side===side&&u.alive&&u.deployed);if(unit){const start=pos(unit),dx=aimDirection.current.x/17*650,dy=aimDirection.current.y/11*350,angle=Math.atan2(dy,dx);ctx.save();ctx.translate(start.x,start.y);ctx.rotate(angle);ctx.strokeStyle="#fff9d8";ctx.lineWidth=3;ctx.setLineDash([5,5]);ctx.beginPath();ctx.moveTo(28,0);ctx.lineTo(88,0);ctx.stroke();ctx.setLineDash([]);ctx.beginPath();ctx.moveTo(78,-7);ctx.lineTo(88,0);ctx.lineTo(78,7);ctx.stroke();ctx.restore();}}
        ctx.restore();
        if(state.result&&!ended){saveBattle();ended=true;audio?.stopSfx();audio?.playMusic(state.result.winner===side?"victory":"defeat");input.current={x:0,y:0};if(document.fullscreenElement===consoleRef.current)void document.exitFullscreen().catch(()=>{});finish.current?.(state.result.winner);}
      }
      raf=requestAnimationFrame(frame);
    };raf=requestAnimationFrame(frame);
    return()=>{audio?.stopSfx();audio?.stopMusic();node.removeEventListener("pointerleave",hideCrosshair);node.removeEventListener("pointermove",pointer);node.removeEventListener("pointerdown",pointer);cancelAnimationFrame(raf);window.removeEventListener("resize",hideCrosshair);window.removeEventListener("keydown",down);window.removeEventListener("keyup",up);window.removeEventListener("blur",blur);input.current={x:0,y:0};};
  },[engine,side,spectator]);
  const active=units.find(u=>u.side===side&&u.deployed&&u.alive),enemy=units.find(u=>u.side!==side&&u.deployed&&u.alive);
  const moves=active?[{...active.spec.basic,cooldown:active.basicCooldown,maxCooldown:active.spec.attackCooldown},...active.spec.skills.map(s=>({...s,cooldown:active.skillCooldowns[s.id]??0,maxCooldown:s.cooldown}))]:[];
  const finished=!!(engine?.state.result||remote?.result);
  const locked=!active||!!active.travelMove||time<(active.channelUntil??0)||active.statuses.some(s=>s.kind==="sleep"||s.kind==="stun");
  const stickMove=(event:ReactPointerEvent<HTMLDivElement>,kind:'move'|'aim')=>{
    if(stickOwners.current[kind]!==event.pointerId||paused.current)return;
    const rect=event.currentTarget.getBoundingClientRect(),radius=rect.width*.32;
    const dx=(event.clientX-rect.left-rect.width/2)/radius,dy=(event.clientY-rect.top-rect.height/2)/radius,length=Math.hypot(dx,dy);
    const vector=length<.16?{x:0,y:0}:{x:dx/Math.max(1,length),y:dy/Math.max(1,length)};
    const knob=event.currentTarget.querySelector<HTMLElement>('span');if(knob)knob.style.transform=`translate(${vector.x*radius}px,${vector.y*radius}px)`;
    if(kind==='move')input.current=vector;
    else if(length>=.16){const worldX=vector.x*17/650,worldY=vector.y*11/350,worldLength=Math.hypot(worldX,worldY);aimDirection.current={x:worldX/worldLength,y:worldY/worldLength};}
  };
  const stickStart=(event:ReactPointerEvent<HTMLDivElement>,kind:'move'|'aim')=>{
    if(paused.current||stickOwners.current[kind]!==undefined)return;
    event.preventDefault();stickOwners.current[kind]=event.pointerId;event.currentTarget.setPointerCapture(event.pointerId);stickMove(event,kind);
  };
  const stickEnd=(event:ReactPointerEvent<HTMLDivElement>,kind:'move'|'aim')=>{
    if(stickOwners.current[kind]!==event.pointerId)return;
    delete stickOwners.current[kind];if(kind==='move')input.current={x:0,y:0};
    const knob=event.currentTarget.querySelector<HTMLElement>('span');if(knob)knob.style.transform='';
    if(event.currentTarget.hasPointerCapture(event.pointerId))event.currentTarget.releasePointerCapture(event.pointerId);
  };
  const toggleFullscreen=async()=>{
    try{if(document.fullscreenElement===consoleRef.current)await document.exitFullscreen();else await consoleRef.current?.requestFullscreen();}
    catch{setFeedback("Fullscreen is unavailable. Use your browser's fullscreen shortcut instead.");}
  };
  return <section ref={consoleRef} className={`battle-console ${finished?"battle-finished":""}`}>
    <div className="battle-top">
      <h2 title={title}>{title}</h2>
      <span className="battle-arena-name">{getArena(engine?.state.arenaId??remote?.arenaId).name}</span>
      <span>{Math.floor(time/1000)}s</span>
      {engine&&<label><input type="checkbox" checked={auto} onChange={e=>{setAuto(e.target.checked);autoRef.current=e.target.checked;engine.setControlled(side,!e.target.checked);engine.setAuto(side,{basic:true,skills:true,ultimate:true});saveBattle();}}/> Auto</label>}
      <button onClick={()=>void toggleFullscreen()} aria-pressed={fullscreen}>{fullscreen?"Exit fullscreen":"Fullscreen"}</button>
      <button onClick={onLeave}>{spectator?"Stop watching":"Forfeit"}</button>
    </div>
    <div className={`arena-viewport original-mobile-arena ${recalling?'is-recalling':''}`}>
      <img className="battle-trainer player" src="/assets/offline/trainers/brendan.png" alt="Your trainer watching the battle"/>
      {!wild&&<img className="battle-trainer opponent" src={/May/.test(title)?'/assets/offline/trainers/may.png':/Steven/.test(title)?'/assets/offline/trainers/steven.png':'/assets/offline/trainers/blue.png'} alt="Opposing trainer watching the battle"/>}
      <div className="deployment-effect" key={units.find(u=>u.side===side&&u.alive&&u.deployed)?.spec.id??'initial'} aria-hidden="true"><i className="pokeball"/><i className="release-beam"/></div>
      <div className="mobile-health-readout"><span>{active?.spec.name} · Lv {active?.spec.level}<meter min={0} max={active?.maxHp||1} value={active?.hp||0}/><small>{active?.hp||0}/{active?.maxHp||0} HP</small></span><span>{enemy?.spec.name} · Lv {enemy?.spec.level}<meter min={0} max={enemy?.maxHp||1} value={enemy?.hp||0}/><small>{enemy?.hp||0}/{enemy?.maxHp||0} HP</small></span></div>
      <canvas ref={canvas} width={720} height={420} tabIndex={0} style={{cursor:spectator?"default":"crosshair"}} aria-label="Battle arena. WASD moves, Q E R X use moves, mouse cursor aims, Space dodges. Numbers 1 to 6 switch party members."/>{!spectator&&<svg ref={crosshair} className="aim-crosshair" viewBox="0 0 32 32" aria-hidden="true"><path className="crosshair-outline" d="M16 3v7m0 12v7M3 16h7m12 0h7"/><path className="crosshair-lines" d="M16 3v7m0 12v7M3 16h7m12 0h7"/><circle cx="16" cy="16" r="2"/></svg>}
    <div className="battle-overlay">
    <div className="battle-readout"><span>{active?.spec.name??"Your Pokémon"} · HP {active?.hp??0}/{active?.maxHp??0}</span><span>{enemy?.spec.name??"Opponent"} · HP {enemy?.hp??0}/{enemy?.maxHp??0}</span></div>
    {!spectator&&<div className="mobile-combat-controls" aria-label="Left movement and aiming controls">
      <div className="combat-stick-pair">{(['move','aim'] as const).map(kind=><div className={`combat-stick-control ${kind}`} key={kind}><div className="mobile-joystick" role="application" aria-label={kind==='move'?'Movement joystick':'Manual aiming angle joystick'} onPointerDown={e=>stickStart(e,kind)} onPointerMove={e=>stickMove(e,kind)} onPointerUp={e=>stickEnd(e,kind)} onPointerCancel={e=>stickEnd(e,kind)} onLostPointerCapture={e=>stickEnd(e,kind)}><span/></div><small>{kind==='move'?'MOVE':'AIM ANGLE'}</small></div>)}</div>
      <div className="combat-utility"><button onClick={()=>togglePause(!pauseState)}>{pauseState?'Resume':'Pause'}</button><button onClick={()=>{togglePause(true);if(engine)itemCallback.current?.(engine);}}>Items</button></div>
    </div>}
    {pauseState&&<div className="battle-pause-overlay"><div className="dialogue-panel"><h2>Battle paused</h2><p>Your original arena battle is saved.</p><button onClick={()=>togglePause(false)}>Resume battle</button><button onClick={onLeave}>Retreat to map</button></div></div>}
    <div className="battle-hud" role="group" aria-label="Battle controls and teams" tabIndex={0}>
      <BattleParty units={units.filter(u=>u.side===side)} label={spectator?"First team":"Your team"} onSwitch={spectator?undefined:id=>act.current(undefined,false,id)}/>
    {!spectator&&<div className="move-bar" aria-label="Skills and cooldowns">{moves.map((m,i)=>{
      const utility="kind" in m&&(m.kind==="buff"||m.kind==="control");
      const matchup=utility?(m.kind==="buff"?"Self":"Status"):enemy?`${typeEffectiveness(m.type,enemy.spec.types)}×`:m.type;
      const details=[m.name,"kind" in m&&m.kind==="buff"?"buff · 5s":moveBehaviorLabel(m.name)??(isDashMove(m.name)?"dash":arenaMoveProfile(m.name,"range" in m?m.range:active!.spec.attackRange).delivery),"status" in m&&m.status?m.status.kind:"",matchup,m.cooldown>0?`${m.cooldown.toFixed(1)}s cooldown`:locked?"Temporarily unavailable":"Ready"].filter(Boolean).join(" · ");
      return <button key={i} title={details} aria-label={`${"QERX"[i]}: ${details}`} disabled={m.cooldown>0||locked||pauseState} onClick={()=>act.current(i)}>
        <i aria-hidden="true" className="cooldown-meter" style={{transform:`scaleX(${Math.min(1,m.cooldown/m.maxCooldown)})`}}/>
        <KeyIcon letter={"QERX"[i]}/><span className="move-name">{m.name}</span><small>{m.cooldown>0?`${m.cooldown.toFixed(1)}s`:matchup}</small>
      </button>;
    })}<button title="Space: dodge in your movement direction" className="combat-dodge" disabled={!active||pauseState||time<(active.dashReadyAt??0)} onClick={()=>act.current(undefined,true)}><kbd>SPACE</kbd><span className="move-name">Dodge</span><small>{time<(active?.dashReadyAt??0)?`${(((active?.dashReadyAt??0)-time)/1000).toFixed(1)}s`:"Ready"}</small></button></div>}
      {!spectator&&<span className="battle-hints" title="WASD: move · Mouse: aim · Q/E/R/X: moves · Space: dodge · 1–6: switch Pokémon"><ControlGuide compact/></span>}
      <BattleParty units={units.filter(u=>u.side!==side)} label={spectator?"Second team":"Opponent team"}/>
    </div>
    </div>
    </div>
    {!spectator&&<p className="battle-feedback" role="status">{feedback}</p>}
  </section>;
}
