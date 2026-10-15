import type { UnitSpec } from "@/battle/types";
import type { Skill, SkillSlot } from "@/battle/types";
import { buildRealKit } from "./moves/kit";
import { basicMove, buildSkill, healSkill } from "./moves/moves";
import { arenaMoveProfile } from "./moves/arenaProfile";
import { getSpecies } from "./species/species";
import { computeStats, expForLevel, expYield, levelForExp, MAX_LEVEL } from "./species/stats";

/** A concrete, owned Pokémon (what gets persisted). Species data is looked up, never copied. */
export interface PokemonInstance {
  id: string;
  speciesId: number;
  level: number;
  exp: number;
  nickname?: string;
  shiny: boolean;
}

let counter = 0;
export function newInstanceId(): string {
  counter++;
  return `pk_${Date.now().toString(36)}_${counter.toString(36)}_${Math.floor(Math.random() * 1e6).toString(36)}`;
}

export function createInstance(speciesId: number, level: number, opts: { id?: string; shiny?: boolean } = {}): PokemonInstance {
  getSpecies(speciesId); // validate
  return { id: opts.id ?? newInstanceId(), speciesId, level, exp: expForLevel(level), shiny: opts.shiny ?? false };
}

export const displayName = (p: PokemonInstance): string => p.nickname ?? getSpecies(p.speciesId).name;

export function instanceStats(p: PokemonInstance) {
  return computeStats(getSpecies(p.speciesId).baseStats, p.level);
}

/** Add EXP, level up, and evolve if the species allows. Pure: returns a new instance + what happened. */
export function gainExp(p: PokemonInstance, amount: number): { pokemon: PokemonInstance; levelsGained: number; evolvedFrom?: number } {
  const exp = p.exp + amount;
  const level = Math.min(MAX_LEVEL, levelForExp(exp));
  let next: PokemonInstance = { ...p, exp, level };
  let evolvedFrom: number | undefined;
  const evo = getSpecies(p.speciesId).evolution;
  if (evo && level >= evo.level) {
    evolvedFrom = p.speciesId;
    next = { ...next, speciesId: evo.to };
  }
  return { pokemon: next, levelsGained: level - p.level, evolvedFrom };
}

export { expYield };

/**
 * Real-time combat has every unit attacking continuously, so mainline HP would melt in a couple of
 * seconds. Battle HP is multiplied (display/menu stats stay mainline) to make fights watchable.
 */
export const BATTLE_HP_MULT = 10;

/** Build the engine's UnitSpec from an owned/wild instance. The only place species data enters battle. */
export function toUnitSpec(p: PokemonInstance, idOverride?: string): UnitSpec {
  const sp = getSpecies(p.speciesId);
  const stats = instanceStats(p);
  const category = sp.baseStats.atk >= sp.baseStats.spa ? "physical" : "special";
  const ranged = sp.role !== "melee";
  const [t1, t2] = sp.types;
  // Real Emerald moves when the pret import is present; type-based templates fill any empty slot.
  const real = buildRealKit(sp.slug, p.level, ranged);
  const basic = real?.basic ?? basicMove(t1, category);
  const tpl: Record<SkillSlot, () => Skill> = {
    skill1: () => buildSkill(t1, "skill1", category, ranged),
    skill2: () => buildSkill(t2 ?? t1, "skill2", category, ranged),
    ultimate: () => buildSkill(t1, "ultimate", category, ranged),
  };
  const skills: Skill[] = (["skill1", "skill2", "ultimate"] as const).map((slot) => real?.skills[slot] ?? tpl[slot]());
  if (sp.role === "support" && !skills.some((s) => s.kind === "heal")) skills[0] = healSkill("skill1");
  // dual-typed Pokémon can produce duplicate template ids; skill ids must be unique per unit
  const seen = new Set<string>();
  for (const s of skills) {
    while (seen.has(s.id)) s.id += "+";
    seen.add(s.id);
  }
  return {
    id: idOverride ?? p.id,
    name: displayName(p),
    speciesId: p.speciesId,
    level: p.level,
    types: sp.types,
    stats: { ...stats, hp: stats.hp * BATTLE_HP_MULT },
    attackCooldown: Math.min(2, Math.max(0.8, 2.2 - sp.baseStats.spe * 0.012)),
    attackRange: arenaMoveProfile(basic.name).range,
    movementSpeed: 1.2 + sp.baseStats.spe / 80,
    basic,
    targetStrategy: sp.role === "ranged" ? "lowestHP" : "nearest",
    skills,
  };
}
