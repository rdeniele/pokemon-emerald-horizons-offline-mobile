import type { PokemonType } from "../types/typeChart";
import type { Skill, SkillSlot, StatusApplication } from "@/battle/types";
import { arenaMoveProfile } from "./arenaProfile";

/** Move names per type: [basic, skill1, skill2, ultimate]. Data, not logic. */
const NAMES: Record<PokemonType, [string, string, string, string]> = {
  normal: ["Tackle", "Quick Attack", "Hyper Voice", "Hyper Beam"],
  fire: ["Ember", "Flame Burst", "Flamethrower", "Blast Burn"],
  water: ["Water Gun", "Bubble Beam", "Surf", "Hydro Pump"],
  electric: ["Thunder Shock", "Spark", "Thunderbolt", "Thunder"],
  grass: ["Vine Whip", "Razor Leaf", "Energy Ball", "Frenzy Plant"],
  ice: ["Powder Snow", "Ice Shard", "Ice Beam", "Blizzard"],
  fighting: ["Karate Chop", "Brick Break", "Cross Chop", "Focus Blast"],
  poison: ["Poison Sting", "Sludge", "Sludge Bomb", "Gunk Shot"],
  ground: ["Mud-Slap", "Bulldoze", "Earthquake", "Precipice Blades"],
  flying: ["Peck", "Wing Attack", "Air Slash", "Brave Bird"],
  psychic: ["Confusion", "Psybeam", "Psychic", "Future Sight"],
  bug: ["Fury Cutter", "Bug Bite", "X-Scissor", "Megahorn"],
  rock: ["Rock Throw", "Rock Slide", "Power Gem", "Stone Edge"],
  ghost: ["Lick", "Shadow Sneak", "Shadow Ball", "Shadow Force"],
  dragon: ["Dragon Breath", "Dragon Claw", "Dragon Pulse", "Draco Meteor"],
  dark: ["Bite", "Pursuit", "Crunch", "Dark Pulse"],
  steel: ["Metal Claw", "Iron Head", "Flash Cannon", "Meteor Mash"],
  fairy: ["Fairy Wind", "Disarming Voice", "Dazzling Gleam", "Moonblast"],
};

const STATUS_BY_TYPE: Partial<Record<PokemonType, (slot: SkillSlot) => StatusApplication>> = {
  fire: (s) => ({ kind: "burn", chance: s === "ultimate" ? 1 : 0.3, duration: 5 }),
  poison: (s) => ({ kind: "poison", chance: s === "ultimate" ? 1 : 0.4, duration: 6 }),
  electric: (s) => ({ kind: "paralysis", chance: s === "ultimate" ? 1 : 0.35, duration: 5 }),
  ice: (s) => ({ kind: "stun", chance: s === "ultimate" ? 0.8 : 0.1, duration: 1.5 }),
  psychic: (s) => ({ kind: "stun", chance: s === "ultimate" ? 0.6 : 0, duration: 1.2 }),
  ghost: (s) => ({ kind: "stun", chance: s === "ultimate" ? 0.6 : 0, duration: 1.2 }),
};

export interface BasicMove {
  name: string;
  type: PokemonType;
  category: "physical" | "special";
  power: number;
}

export const BASIC_POWER = 40;

export function basicMove(type: PokemonType, category: "physical" | "special"): BasicMove {
  return { name: NAMES[type][0], type, category, power: BASIC_POWER };
}

/** Skill templates by slot. Power/cooldown/range/AoE live here so balance is one table. */
const SLOT_TEMPLATE: Record<SkillSlot, { power: number; cooldown: number; aoeRadius: number; nameIdx: number }> = {
  skill1: { power: 60, cooldown: 5, aoeRadius: 0, nameIdx: 1 },
  skill2: { power: 80, cooldown: 9, aoeRadius: 1.3, nameIdx: 2 },
  ultimate: { power: 130, cooldown: 18, aoeRadius: 2, nameIdx: 3 },
};

export function buildSkill(
  type: PokemonType,
  slot: SkillSlot,
  category: "physical" | "special",
  ranged: boolean,
): Skill {
  const t = SLOT_TEMPLATE[slot];
  const status = STATUS_BY_TYPE[type]?.(slot);
  return {
    id: `${type}-${slot}`,
    name: NAMES[type][t.nameIdx],
    slot,
    type,
    category,
    kind: "damage",
    power: t.power,
    cooldown: t.cooldown,
    range: arenaMoveProfile(NAMES[type][t.nameIdx]).range,
    aoeRadius: t.aoeRadius,
    targetStrategy: slot === "ultimate" ? "highestThreat" : ranged ? "lowestHP" : "nearest",
    status: status && status.chance > 0 ? status : undefined,
  };
}

/** Support heal skill (% of max HP) targeting the most wounded ally. */
export const healSkill = (slot: SkillSlot = "skill1"): Skill => ({
  id: `heal-${slot}`,
  name: "Wish",
  slot,
  type: "normal",
  category: "special",
  kind: "heal",
  power: 30,
  cooldown: 10,
  range: 99,
  aoeRadius: 0,
  targetStrategy: "lowestHPAlly",
});
