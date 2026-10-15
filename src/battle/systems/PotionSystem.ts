import {blockedPoint} from "../field";
import {dist,emit,type BattleState} from "../engine/BattleState";
import {heal} from "./CombatSystem";

/** Shared, contested pickups. Full-health, sleeping and phased fighters cannot consume them. */
export function stepPotions(s:BattleState):void {
  if(!s.arena||s.result)return;
  s.potions=(s.potions??[]).filter(p=>p.expires>s.time);
  s.nextPotionAt??=15000;
  if(s.time>=s.nextPotionAt){
    s.nextPotionAt=s.time+20000;
    if(!s.potions.length){
      // The candidate pool is symmetric under 180-degree rotation.
      const candidates=[{x:8.5,y:5.5},{x:8.5,y:3},{x:8.5,y:8},{x:6,y:5.5},{x:11,y:5.5}].filter(p=>!blockedPoint(s.obstacles,p.x,p.y,.5));
      const contested=candidates.filter(p=>[...s.units.values()].every(u=>!u.alive||!u.deployed||dist(u,p)>1.5));
      const pool=contested.length?contested:candidates;
      if(pool.length){const p=pool[Math.floor(s.rng.next()*pool.length)];s.potions.push({id:s.time,...p,expires:s.time+12000});}
    }
  }
  s.potions=s.potions.filter(p=>{
    const eligible=[...s.units.values()].filter(u=>u.alive&&u.deployed&&!u.travelMove&&u.hp<u.maxHp&&!u.statuses.some(st=>st.kind==="sleep"||st.kind==="stun")&&dist(u,p)<=.65);
    // Equally close simultaneous contenders leave the pickup available rather than favoring roster order.
    eligible.sort((a,b)=>dist(a,p)-dist(b,p));
    if(!eligible.length||eligible.length>1&&Math.abs(dist(eligible[0],p)-dist(eligible[1],p))<.01)return true;
    const u=eligible[0],amount=Math.min(u.maxHp-u.hp,Math.ceil(u.maxHp*.2));
    heal(s,u,u,amount);emit(s,{type:"POTION_PICKED_UP",unitId:u.spec.id,x:p.x,y:p.y,amount});return false;
  });
}
