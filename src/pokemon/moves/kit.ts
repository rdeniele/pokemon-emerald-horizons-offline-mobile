import { pretLearnset, pretMove } from "@/data/pret";
import type { PretMove } from "@/data/pret/types";
import type { Skill, SkillSlot, StatusApplication, StatusKind } from "@/battle/types";
import type { BasicMove } from "./moves";
import type { PokemonType } from "../types/typeChart";
import { arenaMoveProfile } from "./arenaProfile";

/** Gen 3 decides physical/special by the move's TYPE, not per move. */
const PHYSICAL_TYPES = new Set<string>(["normal", "fighting", "flying", "ground", "rock", "bug", "ghost", "steel", "poison"]);
export const gen3Category = (type: string): "physical" | "special" => (PHYSICAL_TYPES.has(type) ? "physical" : "special");

/** Effects that need a turn structure / conditions we don't model yet. */
const UNSUPPORTED = /EXPLOSION|FOCUS_PUNCH|OHKO|ENDEAVOR|COUNTER|MIRROR_COAT|BIDE|DREAM_EATER|SNORE|SPIT_UP|FAKE_OUT|SKY_ATTACK|RAZOR_WIND|SKULL_BASH|SOLARBEAM|FLY|DIG|BOUNCE|DIVE|TRAP|RAGE|FALSE_SWIPE|PSYWAVE|SUPER_FANG|LEVEL_DAMAGE|FIXED|PAIN_SPLIT|PURSUIT|SPECIAL_DEFENSE|MAGNITUDE|PRESENT|FURY_CUTTER|ROLLOUT|ICE_BALL|FLAIL|REVERSAL|RETURN|FRUSTRATION|HIDDEN_POWER|BEAT_UP|WEATHER_BALL|FUTURE_SIGHT|DOOM_DESIRE|SMELLING_SALT|FACADE|REVENGE/;

const HEAL_EFFECTS = new Set(["RESTORE_HP", "MORNING_SUN", "SYNTHESIS", "MOONLIGHT", "WISH"]);

const STATUS_EFFECTS: Record<string, { kind: StatusKind; duration: number }> = {
  BURN_HIT: { kind: "burn", duration: 5 },
  POISON_HIT: { kind: "poison", duration: 6 },
  TWINEEDLE: { kind: "poison", duration: 6 },
  PARALYZE_HIT: { kind: "paralysis", duration: 5 },
  FREEZE_HIT: { kind: "stun", duration: 1.5 },
  FLINCH_HIT: { kind: "stun", duration: 0.8 },
  CONFUSE_HIT: { kind: "stun", duration: 1 },
};

export interface RealKit {
  basic?: BasicMove;
  skills: Partial<Record<SkillSlot, Skill>>;
}

const clamp = (v: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, v));

function statusOf(m: PretMove): StatusApplication | undefined {
  const s = STATUS_EFFECTS[m.effect];
  // turn-based chances feel too rare in real time where moves fire every few seconds
  return s ? { kind: s.kind, duration: s.duration, chance: clamp((m.chance / 100) * 2, 0.1, 1) } : undefined;
}

function toSkill(slug: string, m: PretMove, slot: SkillSlot, ranged: boolean): Skill {
  const base = { skill1: [3, 20, 4, 8], skill2: [5, 15, 6, 12], ultimate: [10, 10, 14, 22] }[slot];
  const aoe = m.target === "BOTH" || m.target === "FOES_AND_ALLY";
  return {
    id: slug,
    name: m.name,
    slot,
    type: m.type as PokemonType,
    category: gen3Category(m.type),
    kind: "damage",
    power: m.power,
    cooldown: clamp(base[0] + m.power / base[1], base[2], base[3]),
    range: arenaMoveProfile(m.name).range,
    aoeRadius: aoe ? 1.6 : 0,
    targetStrategy: slot === "ultimate" ? "highestThreat" : ranged ? "lowestHP" : "nearest",
    status: statusOf(m),
  };
}

/**
 * Builds a skill kit from the real Emerald level-up learnset (when imported):
 * weakest damaging move = basic attack, the rest fill skill1 / skill2 / ultimate by power.
 * Slots the species can't fill yet are left empty for the caller to fill with type templates.
 */
export function buildRealKit(slug: string, level: number, ranged: boolean): RealKit | null {
  const learnset = pretLearnset(slug);
  if (!learnset) return null;
  const known = new Map<string, number>();
  for (const [lv, move] of learnset) if (lv <= level) known.set(move, lv);

  const damaging: { slug: string; m: PretMove }[] = [];
  let heal: { slug: string; m: PretMove } | undefined;
  for (const move of known.keys()) {
    const m = pretMove(move);
    if (!m) continue;
    if (HEAL_EFFECTS.has(m.effect)) heal = { slug: move, m };
    else if (m.power > 1 && !UNSUPPORTED.test(m.effect)) damaging.push({ slug: move, m });
  }
  damaging.sort((a, b) => a.m.power - b.m.power);

  const kit: RealKit = { skills: {} };
  const basic = damaging.shift();
  if (basic) kit.basic = { name: basic.m.name, type: basic.m.type as PokemonType, category: gen3Category(basic.m.type), power: clamp(basic.m.power, 20, 60) };

  // ultimate needs a real heavy hitter (>=70 power), skill2 a decent one (>=50); otherwise the
  // type template fills that slot so the kit always has something to press
  const rest = damaging;
  const ult = rest.length && rest[rest.length - 1].m.power >= 70 ? rest.pop() : undefined;
  const s1 = rest.shift();
  const s2 = rest.length && rest[rest.length - 1].m.power >= 50 ? rest.pop() : undefined;
  if (s1) kit.skills.skill1 = toSkill(s1.slug, s1.m, "skill1", ranged);
  if (s2) kit.skills.skill2 = toSkill(s2.slug, s2.m, "skill2", ranged);
  if (ult) kit.skills.ultimate = toSkill(ult.slug, ult.m, "ultimate", ranged);

  if (heal) {
    kit.skills.skill1 = {
      id: heal.slug,
      name: heal.m.name,
      slot: "skill1",
      type: heal.m.type as PokemonType,
      category: "special",
      kind: "heal",
      power: 30,
      cooldown: 10,
      range: 99,
      aoeRadius: 0,
      targetStrategy: "lowestHPAlly",
    };
  }
  return kit;
}
