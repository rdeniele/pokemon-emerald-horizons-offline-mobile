import { dist, emit, opposite, unitsOf, type BattleState } from "../engine/BattleState";
import type { BattleUnit, Skill } from "../types";
import { dealDamage, heal } from "./CombatSystem";
import { applyStatus } from "./StatusSystem";
import { selectTarget } from "./TargetSystem";
import { hasStatus } from "./StatusSystem";
import {blockedLine} from "../field";

export function skillReady(u: BattleUnit, s: Skill): boolean {
  return (u.skillCooldowns[s.id] ?? 0) <= 0;
}

/** Fire a skill if ready, alive, and a valid target is within range. Returns true if used. */
export function castSkill(state: BattleState, u: BattleUnit, skill: Skill, manual: boolean, deferDamage?: (target: BattleUnit) => void): boolean {
  if (!u.alive || !u.deployed || !skillReady(u, skill)) return false;
  if ((hasStatus(u, "stun")||hasStatus(u,"sleep")||!!u.travelMove) || (state.arena && state.time < (u.actionReadyAt ?? 0))) return false;
  if(skill.kind==="buff") {
    u.skillCooldowns[skill.id]=skill.cooldown;u.buff={kind:skill.buff??"attack",until:state.time+5000};
    u.actionReadyAt=state.time+200;
    emit(state,{type:"SKILL_USED",source:u.spec.id,skillId:skill.id,name:skill.name,manual});return true;
  }
  const target = selectTarget(state, u, skill.targetStrategy);
  if (!target) return false;
  if ((skill.kind === "damage"||skill.kind==="control") && (dist(u, target) > skill.range||blockedLine(state.obstacles,u,target))) return false;
  if (state.arena && skill.kind === "heal" && target.hp >= target.maxHp * 0.85) return false;

  u.skillCooldowns[skill.id] = skill.cooldown;
    if (skill.kind === "damage") u.targetId = target.spec.id;
  if (state.arena) u.actionReadyAt = state.time + 450;
  emit(state, { type: "SKILL_USED", source: u.spec.id, skillId: skill.id, name: skill.name, manual });
  emit(state, { type: "POKEMON_TARGETED", source: u.spec.id, target: target.spec.id });

  if (skill.kind === "heal") {
    heal(state, u, target, Math.ceil((target.maxHp * skill.power) / 100));
    return true;
  }
  if (deferDamage) deferDamage(target);
  else resolveSkillDamage(state,u,target,skill);
  return true;
}

export function resolveSkillDamage(state:BattleState,u:BattleUnit,target:BattleUnit,skill:Skill,center:{x:number;y:number}=target,origin:{x:number;y:number}=u):void {
  const victims =
    skill.aoeRadius > 0 ? unitsOf(state, opposite(u.side)).filter((v) => dist(v, center) <= skill.aoeRadius) : [target];
  for (const v of victims) {
    if(skill.kind==="control"){
      if(skill.status&&!v.travelMove&&!blockedLine(state.obstacles,origin,v)&&state.time>=(v.dodgeUntil??0))applyStatus(state,v,skill.status);
      continue;
    }
    const damage = dealDamage(state, u, v, skill,origin);
    if (damage > 0 && skill.status && v.alive) applyStatus(state, v, skill.status);
  }
}
