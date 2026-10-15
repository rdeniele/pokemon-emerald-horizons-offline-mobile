import {projectileSpeed} from "@/pokemon/moves/timing";
import {typeEffectiveness} from "@/pokemon/types/typeChart";
import {blockedLine,blockedPoint} from "../field";
import {moveBehavior,moveVisual,isTravelMove,isConeMove,isStreamMove,isAreaMove,areaMoveProfile,projectileRadius,STREAM_DURATION,STREAM_CLASH_DURATION,type MoveBehavior} from "@/pokemon/moves/behavior";
import {dist,emit,type BattleState} from "../engine/BattleState";
import type {BattleUnit,Skill} from "../types";
import {arenaMoveProfile,isDashMove} from "@/pokemon/moves/arenaProfile";
import {castSkill,skillReady} from "./SkillSystem";
import {dealDamage} from "./CombatSystem";
import {applyStatus,hasStatus} from "./StatusSystem";

type Point={x:number;y:number};
interface Attack {id:number;source:string;origin:Point;point:Point;direction:Point;remaining:number;at:number;until?:number;nextPulse?:number;clashUntil?:number;clashWith?:number;clashPoint?:Point;pulses?:number;melee:boolean;behavior:MoveBehavior;radius:number;skill?:Skill;power:BattleUnit["spec"]["basic"]}

/** Directional skillshots: the cursor chooses a ray, never an enemy lock-on. */
export class AimedCombat {
  private attacks:Attack[]=[];
  private serial=0;
  constructor(private state:BattleState){}
  snapshot(){return {attacks:this.attacks,serial:this.serial};}
  restore(value:ReturnType<AimedCombat['snapshot']>){this.attacks=value.attacks;this.serial=value.serial;}
  cancel(id:string){for(const a of this.attacks.filter(a=>a.source===id))emit(this.state,{type:"MOVE_ENDED",attackId:a.id});this.attacks=this.attacks.filter(a=>a.source!==id);const unit=this.state.units.get(id);if(unit){delete unit.travelMove;if(unit.channelUntil){delete unit.channelUntil;unit.actionReadyAt=this.state.time;}}}
  cast(u:BattleUnit,slot:number,aim:Point):boolean {
    const s=this.state;
    if(!Number.isInteger(slot)||slot<0||slot>3||!Number.isFinite(aim.x)||!Number.isFinite(aim.y)||aim.x<0||aim.y<0||aim.x>s.grid.cols-1||aim.y>s.grid.rowsPerSide*2+s.grid.gapRows-1)return false;
    const skill=slot>0?u.spec.skills[slot-1]:undefined;
    if(slot>0&&!skill)return false;
    if(skill?.kind!==undefined&&skill.kind!=="damage"&&skill.kind!=="control")return castSkill(s,u,skill,true);
    if(skill?!skillReady(u,skill):u.basicCooldown>0)return false;
    const power=skill??u.spec.basic,range=skill?.range??u.spec.attackRange;
    let behavior=moveBehavior(power.name);
    const distance=dist(u,aim);if(distance<.01&&behavior!=="circle"&&!isAreaMove(behavior))return false;
    const direction={x:distance?(aim.x-u.x)/distance:1,y:distance?(aim.y-u.y)/distance:0};
    const travel=isTravelMove(behavior),area=isAreaMove(behavior),areaProfile=areaMoveProfile(behavior);
    const destination={x:u.x+direction.x*Math.min(range,distance),y:u.y+direction.y*Math.min(range,distance)};
    if((travel||area)&&blockedPoint(s.obstacles,destination.x,destination.y,.32))return false;
    const melee=arenaMoveProfile(power.name,range).delivery==="melee";
    const contactDash=melee&&behavior!=="circle"&&!travel&&!isStreamMove(behavior);
    if(isDashMove(power.name)&&hasStatus(u,"root"))return false;
    if((isDashMove(power.name)||contactDash)&&!hasStatus(u,"root")) {
      const length=Math.min(isDashMove(power.name)?3:1.5,distance),fromX=u.x,fromY=u.y;
      for(let d=.1;d<=length;d+=.1){const next={x:fromX+direction.x*d,y:fromY+direction.y*d};if(blockedLine(s.obstacles,u,next,.32)||[...s.units.values()].some(v=>v!==u&&v.alive&&v.deployed&&dist(v,next)<.8))break;u.x=next.x;u.y=next.y;}
      if(dist(u,{x:fromX,y:fromY})>.05)emit(s,{type:"POKEMON_DASHED",unitId:u.spec.id,fromX,fromY,x:u.x,y:u.y,dodge:false});
    }
    const origin={x:u.x,y:u.y};
    if(behavior==="projectile"&&melee)behavior="melee";
    // The cursor chooses direction; a nearby cursor must not truncate a projectile.
    let length=range;
    if(!melee&&!travel&&!area&&!isConeMove(behavior))for(let d=.05;d<=length;d+=.05){if(blockedLine(s.obstacles,origin,{x:origin.x+direction.x*d,y:origin.y+direction.y*d},.08)){length=Math.max(0,d-.05);break;}}
    const radius=area?areaProfile.radius:travel?1.8:behavior==="circle"?3:0;
    const attackId=++this.serial;
    const stream=isStreamMove(behavior),windup=area?areaProfile.windup:travel?2000:180,until=stream?s.time+180+STREAM_DURATION:area?s.time+windup+areaProfile.duration:undefined;
    this.attacks.push({id:attackId,source:u.spec.id,origin,point:travel||area?destination:{...origin},direction,remaining:length,at:s.time+windup,until,nextPulse:stream?s.time+180:area?s.time+windup:undefined,melee,behavior,radius,skill,power});
    if(stream&&until)u.channelUntil=until;
    if(travel)u.travelMove={kind:behavior as "fly"|"dig"|"dive"|"vanish",started:s.time,until:s.time+2000,...destination};
    if(skill){u.skillCooldowns[skill.id]=skill.cooldown;emit(s,{type:"SKILL_USED",source:u.spec.id,skillId:skill.id,name:skill.name,manual:true,aimed:true});}
    else{u.basicCooldown=travel?Math.max(8,u.spec.attackCooldown):u.spec.attackCooldown;emit(s,{type:"ATTACK_STARTED",source:u.spec.id,target:"",move:power.name,aimed:true});}
    u.actionReadyAt=stream?until:s.time+windup;
    const endpoint=travel||area?destination:behavior==="circle"?origin:{x:origin.x+direction.x*length,y:origin.y+direction.y*length};
    emit(s,{type:"MOVE_AIMED",source:u.spec.id,fromX:origin.x,fromY:origin.y,x:endpoint.x,y:endpoint.y,delivery:melee?"melee":"ranged",moveType:power.type,moveName:power.name,travel:area?windup+areaProfile.duration:travel?2000:stream?180+STREAM_DURATION:behavior==="circle"||behavior==="whip"?450:180+length/projectileSpeed(power.name)*1000,behavior,radius,attackId});
    return true;
  }
  step(dt:number) {
    const s=this.state;
    const canceled=new Set<number>();
    // Resolve each held pair once, before normal travel and hit tests resume.
    const resolved=new Set<number>();
    const valid=(a:Attack)=>{const u=s.units.get(a.source);return !!u?.alive&&u.deployed&&!hasStatus(u,"sleep")&&!hasStatus(u,"stun");};
    for(const a of this.attacks){
      if(!a.clashUntil||s.time<a.clashUntil||resolved.has(a.id))continue;
      const b=this.attacks.find(other=>other.id===a.clashWith);
      if(!b||!valid(a)||!valid(b))continue;
      resolved.add(a.id);resolved.add(b.id);
      const scoreA=typeEffectiveness(a.power.type,[b.power.type]),scoreB=typeEffectiveness(b.power.type,[a.power.type]);
      const winner=scoreA===scoreB?undefined:scoreA>scoreB?a:b;
      const point=a.clashPoint??a.point;
      emit(s,{type:"CLASH_RESOLVED",...point,winner:winner?.source,moveType:winner?.power.type});
      if(!winner){canceled.add(a.id);canceled.add(b.id);continue;}
      canceled.add(winner===a?b.id:a.id);
      emit(s,{type:"MOVE_ENDED",attackId:winner.id});
      delete winner.clashUntil;delete winner.clashWith;delete winner.clashPoint;
      winner.at=s.time;
      const unit=s.units.get(winner.source)!;
      if(isStreamMove(winner.behavior)){
        winner.nextPulse=s.time;winner.until=s.time+(3-(winner.pulses??0))*STREAM_DURATION/3;
        unit.channelUntil=winner.until;unit.actionReadyAt=winner.until;
      }else{
        delete unit.channelUntil;unit.actionReadyAt=s.time;
        winner.origin=winner.melee?{x:unit.x,y:unit.y}:{...winner.point};
      }
      const endpoint={x:winner.origin.x+winner.direction.x*winner.remaining,y:winner.origin.y+winner.direction.y*winner.remaining};
      emit(s,{type:"MOVE_AIMED",source:winner.source,fromX:winner.origin.x,fromY:winner.origin.y,...endpoint,delivery:winner.melee?"melee":"ranged",moveType:winner.power.type,moveName:winner.power.name,travel:isStreamMove(winner.behavior)?winner.until!-s.time:180+winner.remaining/projectileSpeed(winner.power.name)*1000,behavior:winner.behavior,radius:winner.radius,attackId:winner.id});
    }
    const ready=this.attacks.filter(a=>a.at<=s.time&&a.remaining>0&&(!a.until||s.time<a.until)&&a.behavior!=="circle"&&!isAreaMove(a.behavior)&&!isTravelMove(a.behavior)&&a.skill?.kind!=="control"&&(()=>{const u=s.units.get(a.source);return u?.alive&&u.deployed&&!hasStatus(u,"sleep")&&!hasStatus(u,"stun");})());
    const contact=(a:Attack)=>a.melee||isStreamMove(a.behavior);
    const next=(a:Attack)=>({x:a.point.x+a.direction.x*Math.min(a.remaining,projectileSpeed(a.power.name)*dt),y:a.point.y+a.direction.y*Math.min(a.remaining,projectileSpeed(a.power.name)*dt)});
    for(let i=0;i<ready.length;i++)for(let j=i+1;j<ready.length;j++){
      const a=ready[i],b=ready[j],u=s.units.get(a.source)!,v=s.units.get(b.source)!;
      if(a.clashUntil||b.clashUntil||canceled.has(a.id)||canceled.has(b.id)||u.side===v.side||a.direction.x*b.direction.x+a.direction.y*b.direction.y>-.2)continue;
      let point:Point|undefined;
      if(contact(a)&&contact(b)){
        const mid={x:(a.origin.x+b.origin.x)/2,y:(a.origin.y+b.origin.y)/2};
        if([a,b].every(c=>{const d=dist(c.origin,mid),dot=(mid.x-c.origin.x)*c.direction.x+(mid.y-c.origin.y)*c.direction.y,across=Math.abs((mid.x-c.origin.x)*c.direction.y-(mid.y-c.origin.y)*c.direction.x);return c.behavior==="beam"?dot>=0&&dot<=c.remaining&&across<=.45:d<=c.remaining&&dot>=d*(isConeMove(c.behavior)?Math.cos(Math.PI/6):.8);}))point=mid;
      }else if(!contact(a)&&!contact(b)){
        // Swept relative motion: crossing projectiles cannot tunnel between 20 Hz ticks.
        const an=next(a),bn=next(b),rx=a.point.x-b.point.x,ry=a.point.y-b.point.y,dx=an.x-a.point.x-bn.x+b.point.x,dy=an.y-a.point.y-bn.y+b.point.y;
        const t=Math.max(0,Math.min(1,-(rx*dx+ry*dy)/(dx*dx+dy*dy||1)));
        const ap={x:a.point.x+(an.x-a.point.x)*t,y:a.point.y+(an.y-a.point.y)*t},bp={x:b.point.x+(bn.x-b.point.x)*t,y:b.point.y+(bn.y-b.point.y)*t};
        if(dist(ap,bp)<=projectileRadius(a.power.name)+projectileRadius(b.power.name))point={x:(ap.x+bp.x)/2,y:(ap.y+bp.y)/2};
      }else{
        const c=contact(a)?a:b,p=c===a?b:a;
        for(const candidate of [p.point,next(p)]){const dx=candidate.x-c.origin.x,dy=candidate.y-c.origin.y,dot=dx*c.direction.x+dy*c.direction.y,across=Math.abs(dx*c.direction.y-dy*c.direction.x);if(dot>=0&&dot<=c.remaining&&across<=.45){point=candidate;break;}}
      }
      if(!point||blockedLine(s.obstacles,a.origin,point,.08)||blockedLine(s.obstacles,b.origin,point,.08))continue;
      const beams=isStreamMove(a.behavior)&&isStreamMove(b.behavior);
      const spheres=[a,b].some(c=>moveVisual(c.power.name)==="sphere");
      const duration=beams?STREAM_CLASH_DURATION:spheres?1200:a.melee&&b.melee?1000:450;
      {
        for(const [attack,unit,other] of [[a,u,b],[b,v,a]] as const){attack.clashPoint={...point};if(!contact(attack)){attack.remaining=Math.max(0,attack.remaining-dist(attack.point,point));attack.point={...point};}attack.clashUntil=s.time+duration;attack.clashWith=other.id;unit.channelUntil=attack.clashUntil;unit.actionReadyAt=attack.clashUntil;}
      }
      emit(s,{type:"ATTACK_CLASH",...point,sources:[a.source,b.source],attackIds:[a.id,b.id],duration,kind:beams?"beam" as const:spheres?"sphere" as const:a.melee&&b.melee?"melee" as const:"projectile" as const});
      for(const [attack,unit] of [[a,u],[b,v]] as const)if(attack.melee){
        const destination={x:Math.max(0,Math.min(s.grid.cols-1,unit.x-attack.direction.x*.45)),y:Math.max(0,Math.min(s.grid.rowsPerSide*2+s.grid.gapRows-1,unit.y-attack.direction.y*.45))};
        if(!blockedLine(s.obstacles,unit,destination,.32)&&![...s.units.values()].some(other=>other!==unit&&other.alive&&other.deployed&&dist(other,destination)<.75)){
          unit.x=destination.x;unit.y=destination.y;emit(s,{type:"POKEMON_MOVED",unitId:unit.spec.id,...destination});
        }
        unit.actionReadyAt=Math.max(unit.actionReadyAt??0,s.time+250);
      }
    }
    const previous=this.attacks;
    this.attacks=this.attacks.filter(a=>{
      if(canceled.has(a.id))return false;
      const u=s.units.get(a.source);if(!u?.alive||!u.deployed||hasStatus(u,"stun")||hasStatus(u,"sleep")){if(u){delete u.travelMove;if(u.channelUntil){delete u.channelUntil;u.actionReadyAt=s.time;}}return false;}
      if(a.clashUntil)return s.time<a.clashUntil&&this.attacks.some(other=>other.id===a.clashWith&&s.units.get(other.source)?.alive&&s.units.get(other.source)?.deployed&&!hasStatus(s.units.get(other.source)!,"stun")&&!hasStatus(s.units.get(other.source)!,"sleep"));
      if(s.time<a.at)return true;
      const foes=[...s.units.values()].filter(v=>v.side!==u.side&&v.alive&&v.deployed&&(!v.travelMove||s.time>=v.travelMove.until));
      const hit=(v:BattleUnit)=>{if(v.travelMove&&s.time<v.travelMove.until)return;if(a.skill?.kind==="control"){if(a.skill.status&&s.time>=(v.dodgeUntil??0)&&!blockedLine(s.obstacles,a.origin,v))applyStatus(s,v,a.skill.status);return;}const amount=dealDamage(s,u,v,a.power,isAreaMove(a.behavior)?a.point:a.origin,isAreaMove(a.behavior)?1/areaMoveProfile(a.behavior).pulses:isStreamMove(a.behavior)?1/3:1,isAreaMove(a.behavior)?1/areaMoveProfile(a.behavior).pulses:1);if(amount>0&&v.alive){if(a.skill?.status)applyStatus(s,v,a.skill.status);if(a.behavior==="bind")applyStatus(s,v,{kind:"root",chance:1,duration:1.2});}};
      if(isAreaMove(a.behavior)){
        const profile=areaMoveProfile(a.behavior);
        if(s.time>=a.until!)return false;
        if(s.time<a.nextPulse!||(a.pulses??0)>=profile.pulses)return true;
        a.nextPulse!+=profile.duration/profile.pulses;a.pulses=(a.pulses??0)+1;
        for(const v of foes)if(dist(v,a.point)<=a.radius)hit(v);
        return true;
      }
      if(isTravelMove(a.behavior)){
        // Recheck occupied landing tiles: never materialize inside a fighter or cover.
        const landing=[a.point,...Array.from({length:16},(_,i)=>({x:a.point.x+Math.cos(i*Math.PI/8)*.85,y:a.point.y+Math.sin(i*Math.PI/8)*.85}))].find(p=>p.x>=0&&p.x<=s.grid.cols-1&&p.y>=0&&p.y<=s.grid.rowsPerSide*2+s.grid.gapRows-1&&!blockedPoint(s.obstacles,p.x,p.y,.32)&&![...s.units.values()].some(v=>v!==u&&v.alive&&v.deployed&&dist(v,p)<.75));
        if(landing){u.x=landing.x;u.y=landing.y;emit(s,{type:"POKEMON_MOVED",unitId:u.spec.id,...landing});}
        delete u.travelMove;a.origin=a.point;
        for(const v of foes)if(dist(v,a.point)<=a.radius)hit(v);
        return false;
      }
      if(a.behavior==="circle"||isStreamMove(a.behavior)){
        if(a.until&&s.time>=a.until)return false;
        if(a.nextPulse!==undefined){if(s.time<a.nextPulse)return true;a.nextPulse+=STREAM_DURATION/3;a.pulses=(a.pulses??0)+1;}
        for(const v of foes){const distance=dist(a.origin,v),dot=(v.x-a.origin.x)*a.direction.x+(v.y-a.origin.y)*a.direction.y;
          const across=Math.abs((v.x-a.origin.x)*a.direction.y-(v.y-a.origin.y)*a.direction.x);
          if(a.behavior==="circle"?distance<=a.radius:a.behavior==="beam"?dot>=0&&dot<=a.remaining&&across<=.45:distance<=a.remaining&&dot>=distance*Math.cos(Math.PI/6))hit(v);
        }return isStreamMove(a.behavior);
      }
      if(a.melee){for(const v of foes){const d=dist(a.origin,v),dot=(v.x-a.origin.x)*a.direction.x+(v.y-a.origin.y)*a.direction.y,across=Math.abs((v.x-a.origin.x)*a.direction.y-(v.y-a.origin.y)*a.direction.x);if(d<=Math.max(a.remaining,a.skill?.aoeRadius??0)&&(a.behavior==="whip"?dot>=0&&across<=.55:dot>=-.1))hit(v);}return false;}
      // Substeps avoid tunnelling through a moving target or narrow cover at 20 Hz.
      const distance=Math.min(a.remaining,projectileSpeed(a.power.name)*dt),steps=Math.max(1,Math.ceil(distance/.15));
      for(let i=0;i<steps;i++) {
        const next={x:a.point.x+a.direction.x*distance/steps,y:a.point.y+a.direction.y*distance/steps};
        if(blockedLine(s.obstacles,a.point,next,projectileRadius(a.power.name)))return false;
        a.point=next;a.remaining-=distance/steps;
        const target=foes.find(v=>dist(v,next)<=.32+projectileRadius(a.power.name));
        if(target){for(const v of foes)if(v===target||(a.skill?.aoeRadius??0)>0&&dist(v,next)<=a.skill!.aoeRadius)hit(v);return false;}
      }
      if(a.remaining<=.001){if(a.skill&&a.skill.aoeRadius>0)for(const v of foes)if(dist(v,a.point)<=a.skill.aoeRadius)hit(v);return false;}
      return true;
    });
    for(const a of previous)if(!this.attacks.some(active=>active.id===a.id)&&(a.clashUntil||isStreamMove(a.behavior)||!a.melee&&!isTravelMove(a.behavior)))emit(s,{type:"MOVE_ENDED",attackId:a.id});
    for(const u of s.units.values())if(u.channelUntil&&!this.attacks.some(a=>a.source===u.spec.id)){
      delete u.channelUntil;u.actionReadyAt=Math.min(u.actionReadyAt??s.time,s.time);
    }
  }
}
