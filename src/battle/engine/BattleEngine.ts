import {stepPotions} from "../systems/PotionSystem";
import {moveBehavior} from "@/pokemon/moves/behavior";
import {blockedLine} from "../field";
import {AimedCombat} from "../systems/AimedCombat";
import type { BattleEvent } from "../events/types";
import { dealDamage, applyDamage, heal } from "../systems/CombatSystem";
import { deploy } from "../systems/SpawnSystem";
import { validateFormation } from "../systems/FormationSystem";
import { moveToward } from "../systems/MovementSystem";
import { replaceFainted } from "../systems/ReplacementSystem";
import { skillReady, castSkill, resolveSkillDamage } from "../systems/SkillSystem";
import { spawnSide } from "../systems/SpawnSystem";
import { hasStatus, speedMultiplier, tickStatuses } from "../systems/StatusSystem";
import { selectTarget } from "../systems/TargetSystem";
import { checkVictory } from "../systems/VictorySystem";
import { DEFAULT_GRID, type AutoConfig, type BattleSetup, type BattleUnit, type Side, type SkillSlot } from "../types";
import { dist, emit, type BattleState } from "./BattleState";
import { Rng } from "./rng";
import { arenaDash, circleTarget, retreatFrom, DODGE_COOLDOWN_MS } from "../systems/ArenaSystem";
import { arenaMoveProfile, isDashMove, type MoveDelivery } from "@/pokemon/moves/arenaProfile";
import { typeEffectiveness } from "@/pokemon/types/typeChart";

export const TICK = 0.05; // 20 Hz fixed simulation step (seconds)
const DEFAULT_TIME_LIMIT = 120;

const ALL_AUTO: AutoConfig = { basic: true, skills: true, ultimate: true };
const SLOT_ORDER: SkillSlot[] = ["ultimate", "skill2", "skill1"];

/**
 * Deterministic real-time auto-battle simulation. No rendering, no wall clock, no DOM.
 * Same setup + same seed + same inputs => same event stream.
 */
export class BattleEngine {
  readonly state: BattleState;
  private aimed:AimedCombat;
  private accumulator = 0;
  private strikes: { source: string; target: string; x: number; y: number; at: number; from?:{x:number;y:number} }[] = [];
  private arenaPlans = new Map<string, {skillId: string | null; targetId: string; range: number; delivery: MoveDelivery; startedAt: number}>();
  private lastDelivery = new Map<string, MoveDelivery>();
  private controlled = new Set<Side>();
  private movement = new Map<Side, {x: number; y: number}>();
  private switchReadyAt: Partial<Record<Side,number>> = {};
  private skillStrikes: {source:string;target:string;skillId:string;x:number;y:number;at:number;from:{x:number;y:number}}[] = [];

  /** Direct-control sides never run AI movement or autonomous attacks. */
  setControlled(side: Side, value: boolean): void {
    if (value) this.controlled.add(side); else this.controlled.delete(side);
    this.movement.delete(side);
  }

  setMovement(side: Side, x: number, y: number): void {
    if (!Number.isFinite(x) || !Number.isFinite(y)) return;
    const length = Math.max(1, Math.hypot(x, y));
    this.movement.set(side, {x: x / length, y: y / length});
  }

  commandMove(unitId: string, slot: number, aim?:{x:number;y:number}): boolean {
    const u = this.unit(unitId);
    if (!u?.alive || !u.deployed || this.finished || (hasStatus(u, "stun") || hasStatus(u,"sleep")) || this.state.time < (u.actionReadyAt ?? 0)) return false;
    if(aim)return this.aimed.cast(u,slot,aim);
    const namedSkill=slot>0?u.spec.skills[slot-1]:undefined;
    const namedMove=slot===0?u.spec.basic:namedSkill;
    if(namedSkill&&namedSkill.kind!=="damage"&&namedSkill.kind!=="control")return this.activateSkill(unitId,namedSkill.id);
    if(this.state.arena&&namedMove){
      const behavior=moveBehavior(namedMove.name),profile=arenaMoveProfile(namedMove.name,namedSkill?.range??u.spec.attackRange);
      if(behavior!=="projectile"||profile.delivery==="melee"){
        const target=selectTarget(this.state,u,"nearest");
        const extraReach=isDashMove(namedMove.name)?3:profile.delivery==="melee"&&behavior!=="circle"?1.5:0;
        if(target&&dist(u,target)<=profile.range+extraReach)return this.aimed.cast(u,slot,{x:target.x,y:target.y});
        return false;
      }
    }
    if (slot > 0 && slot <= 3) {
      const skill=u.spec.skills[slot-1];if(!skill)return false;
      if(skill.kind!=="damage"&&skill.kind!=="control")return this.activateSkill(unitId,skill.id);
      const target=selectTarget(this.state,u,"nearest");
      if(target && isDashMove(skill.name) && skillReady(u,skill) && dist(u,target)<=4 && !blockedLine(this.state.obstacles,u,target,.32)) {
        const d=dist(u,target)||1,fromX=u.x,fromY=u.y;
        u.x+=(target.x-u.x)/d*Math.max(0,d-1);u.y+=(target.y-u.y)/d*Math.max(0,d-1);
        emit(this.state,{type:"POKEMON_DASHED",unitId,fromX,fromY,x:u.x,y:u.y,dodge:false});
      }
      if(target && blockedLine(this.state.obstacles,u,target))return false;
      return castSkill(this.state,u,skill,true,target=>{
        const melee=arenaMoveProfile(skill.name,skill.range).delivery==="melee";
        this.skillStrikes.push({source:unitId,target:target.spec.id,skillId:skill.id,x:melee?u.x:target.x,y:melee?u.y:target.y,from:{x:u.x,y:u.y},at:this.state.time+(melee?180:180+dist(u,target)*70)});
      });
    }
    if (slot !== 0 || u.basicCooldown > 0) return false;
    const target = selectTarget(this.state, u, "nearest");
    if(target && isDashMove(u.spec.basic.name) && dist(u,target)<=4 && !blockedLine(this.state.obstacles,u,target,.32)) {
      const d=dist(u,target)||1,fromX=u.x,fromY=u.y;
      const x=u.x+(target.x-u.x)/d*Math.max(0,d-1),y=u.y+(target.y-u.y)/d*Math.max(0,d-1);
      if(![...this.state.units.values()].some(v=>v!==u&&v!==target&&v.alive&&v.deployed&&dist(v,{x,y})<.75)){
        u.x=x;u.y=y;emit(this.state,{type:"POKEMON_DASHED",unitId,fromX,fromY,x,y,dodge:false});
      }
    }
    if (!target || blockedLine(this.state.obstacles,u,target) || dist(u, target) > u.spec.attackRange) return false;
    u.targetId = target.spec.id;
    emit(this.state, {type: "ATTACK_STARTED", source: unitId, target: target.spec.id, move: u.spec.basic.name});
    this.strikes.push({source: unitId, target: target.spec.id, x: target.x, y: target.y, from:{x:u.x,y:u.y}, at: this.state.time + (u.spec.attackRange<=2?180:180+dist(u,target)*70)});
    u.basicCooldown = u.spec.attackCooldown;
    u.actionReadyAt = this.state.time + 180;
    return true;
  }

  commandDodge(unitId: string, x: number, y: number): boolean {
    const u = this.unit(unitId), s = this.state;
    if (!u?.alive || !u.deployed || this.finished || !s.arena || (hasStatus(u, "stun") || hasStatus(u,"sleep")) || s.time < (u.dashReadyAt ?? 0) || !Number.isFinite(x) || !Number.isFinite(y)) return false;
    if(u.travelMove||hasStatus(u,"root"))return false;
    if (!x && !y) {
      const target = selectTarget(s, u, "nearest");
      x = target ? u.x - target.x : 0; y = target ? u.y - target.y : 1;
    }
    const length = Math.hypot(x, y) || 1;
    const nx = Math.max(0, Math.min(s.grid.cols - 1, u.x + x / length * 1.5));
    const ny = Math.max(0, Math.min(s.grid.rowsPerSide * 2 + s.grid.gapRows - 1, u.y + y / length * 1.5));
    if (blockedLine(s.obstacles,u,{x:nx,y:ny},.32) || [...s.units.values()].some(v => v !== u && v.alive && v.deployed && dist(v, {x: nx, y: ny}) < 0.75) || dist(u, {x: nx, y: ny}) < 0.05) return false;
    const fromX = u.x, fromY = u.y;
    if(u.channelUntil)this.aimed.cancel(unitId);
    u.x = nx; u.y = ny; u.dodgeUntil = s.time + 300; u.dashReadyAt = s.time + DODGE_COOLDOWN_MS;
    this.arenaPlans.delete(unitId);
    emit(s, {type: "POKEMON_DASHED", unitId, fromX, fromY, x: nx, y: ny, dodge: true});
    return true;
  }

  constructor(setup: BattleSetup) {
    const grid = setup.grid ?? DEFAULT_GRID;
    for (const side of ["player", "enemy"] as const) {
      const errs = validateFormation(grid, side, setup[side].formation, setup[side].maxUnits);
      if (errs.length) throw new Error(`Invalid ${side} formation: ${errs.join("; ")}`);
      if (setup[side].formation.length === 0) throw new Error(`${side} has no deployed units`);
    }
    this.state = {
      arena: setup.arena,
      arenaId: setup.arenaId,
      obstacles: setup.obstacles,
      grid,
      time: 0,
      units: new Map(),
      order: [],
      reserves: { player: [], enemy: [] },
      maxUnits: { player: setup.player.maxUnits, enemy: setup.enemy.maxUnits },
      events: [],
      rng: new Rng(setup.seed),
      auto: { player: { basic: true, skills: false, ultimate: false }, enemy: { ...ALL_AUTO } },
      timeLimit: setup.timeLimit ?? DEFAULT_TIME_LIMIT,
      result: null,
    };
    this.aimed=new AimedCombat(this.state);
    spawnSide(this.state, "enemy", setup.enemy.roster, setup.enemy.formation, setup.enemy.maxUnits);
    spawnSide(this.state, "player", setup.player.roster, setup.player.formation, setup.player.maxUnits);
    if (setup.arena) this.setAuto("player", ALL_AUTO);
  }

  /** Durable offline checkpoint, including in-flight attacks and deterministic RNG. */
  snapshot():string {
    return JSON.stringify({version:1,state:{...this.state,units:[...this.state.units],rng:this.state.rng.snapshot()},accumulator:this.accumulator,strikes:this.strikes,arenaPlans:[...this.arenaPlans],lastDelivery:[...this.lastDelivery],controlled:[...this.controlled],movement:[...this.movement],switchReadyAt:this.switchReadyAt,skillStrikes:this.skillStrikes,aimed:this.aimed.snapshot()});
  }
  restore(snapshot:string):void {
    const saved=JSON.parse(snapshot);
    if(saved.version!==1||!Array.isArray(saved.state?.units)||saved.state.units.length>12||!Number.isFinite(saved.state.time)||!Array.isArray(saved.aimed?.attacks)||saved.aimed.attacks.length>1000)throw Error('Invalid original-engine checkpoint');
    for(const [,u] of saved.state.units)if(!u.spec||!Number.isFinite(u.hp)||!Number.isFinite(u.x)||!Number.isFinite(u.y)||!Array.isArray(u.spec.skills))throw Error('Invalid saved combatant');
    Object.assign(this.state,saved.state,{units:new Map(saved.state.units),rng:new Rng(saved.state.rng)});
    this.accumulator=saved.accumulator;this.strikes=saved.strikes;this.arenaPlans=new Map(saved.arenaPlans);this.lastDelivery=new Map(saved.lastDelivery);this.controlled=new Set(saved.controlled);this.movement=new Map(saved.movement);this.switchReadyAt=saved.switchReadyAt;this.skillStrikes=saved.skillStrikes;this.aimed=new AimedCombat(this.state);this.aimed.restore(saved.aimed);
  }
  get finished(): boolean {
    return this.state.result !== null;
  }

  get timeSeconds(): number {
    return this.state.time / 1000;
  }

  unit(id: string): BattleUnit | undefined {
    return this.state.units.get(id);
  }

  deployedUnits(side?: Side): BattleUnit[] {
    return this.state.order
      .map((id) => this.state.units.get(id)!)
      .filter((u) => u.deployed && u.alive && (!side || u.side === side));
  }

  setAuto(side: Side, cfg: Partial<AutoConfig>): void {
    Object.assign(this.state.auto[side], cfg);
  }

  setManualTarget(unitId: string, targetId: string | null): void {
    const u = this.state.units.get(unitId);
    if (u) u.manualTargetId = targetId;
  }

  /** Player-initiated skill. Returns false if not ready / no valid target in range. */
  activateSkill(unitId: string, skillId: string): boolean {
    if (this.finished) return false;
    const u = this.state.units.get(unitId);
    const skill = u?.spec.skills.find((s) => s.id === skillId);
    if (!u || !skill) return false;
    const used = castSkill(this.state, u, skill, true);
    if (used) {
      this.arenaPlans.delete(unitId);
      this.lastDelivery.set(unitId, arenaMoveProfile(skill.name, skill.range).delivery);
    }
    return used;
  }

  commandDash(unitId: string, dodge = true): boolean {
    if (this.finished) return false;
    const u = this.unit(unitId);
    if (!u || u.side !== "player") return false;
    const target = selectTarget(this.state, u, "nearest");
    return !!target && arenaDash(this.state, u, target, dodge);
  }

  /** Withdraw without resetting HP, statuses or cooldowns; preserve active slot count. */
  switchPlayer(unitId: string, reserveId: string): boolean {
    return this.switchUnit("player",unitId,reserveId);
  }

  switchUnit(side: Side, unitId: string, reserveId: string): boolean {
    if (this.finished) return false;
    if (this.state.time < (this.switchReadyAt[side] ?? 0)) return false;
    const outgoing = this.unit(unitId), incoming = this.unit(reserveId);
    const reserves = this.state.reserves[side];
    if (!outgoing?.alive || !outgoing.deployed || outgoing.side !== side ||
        !incoming?.alive || incoming.deployed || incoming.side !== side || !reserves.includes(reserveId)) return false;
    if(outgoing.travelMove)return false;
    outgoing.deployed = false;
    this.arenaPlans.delete(unitId);
    this.arenaPlans.delete(reserveId);
    outgoing.targetId = null;
    incoming.targetId = null;
    reserves.splice(reserves.indexOf(reserveId), 1);
    reserves.push(unitId);
    this.aimed.cancel(unitId);
    this.strikes = this.strikes.filter(hit => hit.source !== unitId && hit.target !== unitId);
    this.skillStrikes = this.skillStrikes.filter(hit => hit.source !== unitId && hit.target !== unitId);
    emit(this.state, {type: "POKEMON_WITHDRAWN", unitId, replacement: reserveId});
    deploy(this.state, incoming, outgoing.slot);
      this.switchReadyAt[side]=this.state.time+2000;
    return true;
  }

  healPlayer(unitId: string, amount: number): boolean {
    const u = this.unit(unitId);
    if (this.finished || !u?.alive || !u.deployed || u.side !== "player" || u.hp >= u.maxHp || !(amount > 0)) return false;
    heal(this.state, u, u, Math.min(amount, u.maxHp - u.hp));
    return true;
  }

  /** Remove an enemy from the field because it was caught (not a faint; no replacement). */
  removeCaptured(unitId: string): void {
    const u = this.state.units.get(unitId);
    if (!u || !u.alive || !u.deployed || u.side !== "enemy") return;
    u.alive = false;
    u.deployed = false;
    emit(this.state, { type: "POKEMON_CAPTURED", unitId });
    if (this.state.arena) replaceFainted(this.state, u);
    checkVictory(this.state);
  }

  /** Advance the simulation by `seconds` of battle time (may run several fixed ticks). */
  advance(seconds: number, stopWhen?: () => boolean): void {
    this.accumulator += seconds;
    while (this.accumulator >= TICK && !this.finished) {
      this.step(TICK);
      this.accumulator -= TICK;
      if (stopWhen?.()) {
        this.accumulator = 0; // don't burst through the remaining time when play resumes
        return;
      }
    }
  }

  /** Run to completion (tests, headless sims). */
  runToEnd(maxSeconds = DEFAULT_TIME_LIMIT + 5): void {
    const limit = maxSeconds / TICK;
    for (let i = 0; i < limit && !this.finished; i++) this.step(TICK);
  }

  drainEvents(): BattleEvent[] {
    const e = this.state.events;
    this.state.events = [];
    return e;
  }

  step(dt: number): void {
    const s = this.state;
    if (s.result) return;
    s.time += dt * 1000;
    this.aimed.step(dt);
    stepPotions(s);

    // Windups aim at a position: leaving that position can avoid an attack.
    const due = this.strikes.filter(hit => hit.at <= s.time);
    this.strikes = this.strikes.filter(hit => hit.at > s.time);
    for (const hit of due) {
      const source = this.unit(hit.source), target = this.unit(hit.target);
      if (!source?.alive || !target?.alive || !target.deployed || hasStatus(source, "stun")) continue;
      if (dist(target, hit) > 0.9 || (source.spec.attackRange <= 2 && dist(source, target) > source.spec.attackRange + 0.4) || s.time < (target.dodgeUntil ?? 0)) {
        emit(s, {type: "ATTACK_DODGED", source: hit.source, target: hit.target});
      } else dealDamage(s, source, target, source.spec.basic,source.spec.attackRange<=2?source:hit.from??source);
    }
    const dueSkills=this.skillStrikes.filter(hit=>hit.at<=s.time);
    this.skillStrikes=this.skillStrikes.filter(hit=>hit.at>s.time);
    for(const hit of dueSkills){
      const source=this.unit(hit.source),target=this.unit(hit.target),skill=source?.spec.skills.find(sk=>sk.id===hit.skillId);
      if(!source?.alive||!source.deployed||!target?.alive||!target.deployed||!skill||hasStatus(source,"stun"))continue;
      if(skill.aoeRadius<=0 && (dist(target,hit)>.9 || arenaMoveProfile(skill.name,skill.range).delivery==="melee" && dist(source,target)>skill.range+.4))emit(s,{type:"ATTACK_DODGED",source:hit.source,target:hit.target});
      else resolveSkillDamage(s,source,target,skill,hit,skill.range<=2?source:hit.from);
    }

    for (const id of s.order) {
      const u = s.units.get(id)!;
      if (!u.alive || !u.deployed) continue;
      this.updateUnit(u, dt);
    }
    this.resolveFaints();
    checkVictory(s);
  }

  private updateUnit(u: BattleUnit, dt: number): void {
    const s = this.state;

    // cooldowns
    u.basicCooldown -= dt * speedMultiplier(u);
    for (const sk of u.spec.skills) u.skillCooldowns[sk.id] = (u.skillCooldowns[sk.id] ?? 0) - dt;

    // damage over time
    u.dotRemainder += tickStatuses(u, dt);
    // pulse in chunks of ~2% max HP so a burn shows as readable ticks, not a 20 Hz stream of "-1"
    const pulse = Math.max(1, Math.ceil(u.maxHp * 0.02));
    if (u.dotRemainder >= pulse) {
      const whole = Math.floor(u.dotRemainder);
      u.dotRemainder -= whole;
      applyDamage(s, null, u, whole, 1, "status");
      if (!u.alive) return;
    }
    if ((hasStatus(u, "stun") || hasStatus(u,"sleep")) || u.travelMove || s.time<(u.channelUntil??0)) return;
    if (s.arena && this.controlled.has(u.side)) {
      const input = this.movement.get(u.side);
      if (input && (input.x || input.y)) {
        const step = u.spec.movementSpeed * speedMultiplier(u,s.time) * dt;
        const x = Math.max(0, Math.min(s.grid.cols - 1, u.x + input.x * step));
        const y = Math.max(0, Math.min(s.grid.rowsPerSide * 2 + s.grid.gapRows - 1, u.y + input.y * step));
        for(const next of [{x,y},{x,y:u.y},{x:u.x,y}]) {
          if(dist(u,next)<.0001||blockedLine(s.obstacles,u,next,.32)||[...s.units.values()].some(v=>v!==u&&v.alive&&v.deployed&&dist(v,next)<.75&&dist(v,next)<dist(v,u)))continue;
          u.x=next.x;u.y=next.y;emit(s,{type:"POKEMON_MOVED",unitId:u.spec.id,...next});break;
        }
      }
      return;
    }
    if (s.arena && s.time < (u.actionReadyAt ?? 0)) return;

    const auto = s.auto[u.side];
    if (s.arena) { this.updateArenaCombat(u, dt); return; }

    // automatic skills (ultimate first so it isn't starved by cheaper skills)
    if (auto.skills || auto.ultimate) {
      for (const slot of SLOT_ORDER) {
        if (slot === "ultimate" ? !auto.ultimate : !auto.skills) continue;
        for (const sk of u.spec.skills) {
          if (sk.slot !== slot || !skillReady(u, sk)) continue;
          if (castSkill(s, u, sk, false)) {
            break;
          }
        }
      }
    }

    // pick a target
    const target = selectTarget(s, u, u.spec.targetStrategy);
    if (!target) return;
    if (u.targetId !== target.spec.id) {
      u.targetId = target.spec.id;
      emit(s, { type: "POKEMON_TARGETED", source: u.spec.id, target: target.spec.id });
    }

    if (dist(u, target) > u.spec.attackRange) {
      moveToward(s, u, target, dt, u.spec.attackRange * 0.9);
      return;
    }
    if (u.basicCooldown <= 0 && auto.basic) {
      const b = u.spec.basic;
      emit(s, { type: "ATTACK_STARTED", source: u.spec.id, target: target.spec.id, move: b.name });
      dealDamage(s, u, target, b);
      u.basicCooldown = u.spec.attackCooldown;
    }
  }

  private updateArenaCombat(u: BattleUnit, dt: number): void {
    const s = this.state, auto = s.auto[u.side], id = u.spec.id;
    // Healing remains conditional; attacking plans never make a wounded support chase an ally.
    for (const sk of u.spec.skills) {
      if (sk.kind !== "damage" && sk.kind !== "control" && (sk.slot === "ultimate" ? auto.ultimate : auto.skills) && castSkill(s, u, sk, false)) return;
    }
    let plan = this.arenaPlans.get(id);
    const plannedSkill = plan?.skillId ? u.spec.skills.find(sk => sk.id === plan!.skillId) : undefined;
    if (plan && (!this.unit(plan.targetId)?.alive || !this.unit(plan.targetId)?.deployed ||
      s.time - plan.startedAt > 3500 || (plannedSkill ? !skillReady(u, plannedSkill) || !(plannedSkill.slot === "ultimate" ? auto.ultimate : auto.skills) : !auto.basic))) {
      this.arenaPlans.delete(id); plan = undefined;
    }
    if (!plan) {
      const options: {skillId: string | null; targetId: string; range: number; delivery: MoveDelivery; score: number}[] = [];
      for (const sk of u.spec.skills) {
        if ((sk.kind !== "damage" && sk.kind !== "control") || !skillReady(u, sk) || !(sk.slot === "ultimate" ? auto.ultimate : auto.skills)) continue;
        const target = selectTarget(s, u, sk.targetStrategy);
        if (!target) continue;
        const delivery = arenaMoveProfile(sk.name, sk.range).delivery;
        const effectiveness = typeEffectiveness(sk.type, target.spec.types);
        options.push({skillId: sk.id, targetId: target.spec.id, range: sk.range, delivery,
          score: (effectiveness === 0 ? -100 : 6 * Math.log2(effectiveness)) + (delivery !== this.lastDelivery.get(id) ? 4 : 0) + (dist(u, target) <= sk.range ? 1 : 0) + (sk.slot === "ultimate" ? 0.5 : 0) + sk.power / 300});
      }
      if (auto.basic && u.basicCooldown <= 0) {
        const target = selectTarget(s, u, u.spec.targetStrategy);
        if (target) {
          const delivery = arenaMoveProfile(u.spec.basic.name, u.spec.attackRange).delivery;
          const effectiveness = typeEffectiveness(u.spec.basic.type, target.spec.types);
          options.push({skillId: null, targetId: target.spec.id, range: u.spec.attackRange, delivery,
            score: (effectiveness === 0 ? -100 : 6 * Math.log2(effectiveness)) + (delivery !== this.lastDelivery.get(id) ? 4 : 0) + (dist(u, target) <= u.spec.attackRange ? 1 : 0)});
        }
      }
      options.sort((a, b) => b.score - a.score);
      if (options[0]) {
        plan = {...options[0], startedAt: s.time};
        this.arenaPlans.set(id, plan);
      }
    }
    const target = plan ? this.unit(plan.targetId) : selectTarget(s, u, u.spec.targetStrategy);
    if (!target) return;
    if (u.targetId !== target.spec.id) {
      u.targetId = target.spec.id;
      emit(s, {type: "POKEMON_TARGETED", source: id, target: target.spec.id});
    }
    if (!plan) { circleTarget(s, u, target, dt); return; }
    if(blockedLine(s.obstacles,u,target)) {moveToward(s,u,target,dt,0);return;}
    if (dist(u, target) > plan.range) {
      if (plan.delivery === "melee" && arenaDash(s, u, target, false, plan.range)) return;
      moveToward(s, u, target, dt, plan.range * 0.9);
      return;
    }
    // A short, bounded disengagement creates a readable ranged exchange after contact.
    if (plan.delivery === "ranged" && dist(u, target) < plan.range * 0.65 && s.time - plan.startedAt < 650 && retreatFrom(s, u, target, dt)) return;
    if (plan.skillId) {
      const skill = u.spec.skills.find(sk => sk.id === plan!.skillId)!;
      if (!this.commandMove(id,u.spec.skills.indexOf(skill)+1,{x:target.x,y:target.y})) { this.arenaPlans.delete(id); return; }
    } else if(s.arenaId) {
      this.commandMove(id,0,{x:target.x,y:target.y});
    } else {
      emit(s,{type:"ATTACK_STARTED",source:id,target:target.spec.id,move:u.spec.basic.name});
      this.strikes.push({source:id,target:target.spec.id,x:target.x,y:target.y,at:s.time+300});
      u.basicCooldown=u.spec.attackCooldown;u.actionReadyAt=s.time+350;
      if(s.rng.next()<.32)arenaDash(s,target,u,true);
    }
    this.lastDelivery.set(id, plan.delivery);
    this.arenaPlans.delete(id);
  }

  /** Swap in reserves for anything that fainted this tick. */
  private resolveFaints(): void {
    for (const id of this.state.order) {
      const u = this.state.units.get(id)!;
      if (!u.alive && u.deployed) {
        u.deployed = false;
        replaceFainted(this.state, u);
      }
    }
  }
}
