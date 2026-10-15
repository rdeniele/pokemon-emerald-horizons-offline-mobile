import generated from "@/data/pokemon/species.generated.json";
import type { BaseStats } from "@/battle/types";
import type { PokemonType } from "../types/typeChart";

export type Role = "melee" | "ranged" | "support";

export interface Evolution {
  to: number;
  level: number;
}

export interface PokemonSpecies {
  /** Base species use dex IDs; forms retain stable internal IDs for saved collections. */
  id: number;
  nationalDexNumber: number;
  name: string;
  slug: string;
  types: PokemonType[];
  baseStats: BaseStats;
  baseExp: number;
  /** 0..255, higher = easier (mainline convention) */
  catchRate: number;
  role: Role;
  evolution?: Evolution;
  generation: number;
  form?: "mega" | "gigantamax";
}

interface Raw {
  name?: string;
  id: number;
  slug: string;
  types: string[];
  baseStats: BaseStats;
  baseExp: number;
  catchRate?: number;
  nationalDexNumber?: number;
  form?: "mega" | "gigantamax";
}

const EVOLUTIONS: Record<number, Evolution> = {
  252: { to: 253, level: 16 }, 253: { to: 254, level: 36 },
  255: { to: 256, level: 16 }, 256: { to: 257, level: 36 },
  258: { to: 259, level: 16 }, 259: { to: 260, level: 36 },
  261: { to: 262, level: 18 },
  263: { to: 264, level: 20 },
  280: { to: 281, level: 20 }, 281: { to: 282, level: 30 },
};

/** Species that heal allies instead of pure damage. */
const SUPPORT = new Set([280, 281, 282]);

export function generationOf(dex: number): number {
  const caps = [151, 251, 386, 493, 649, 721, 809, 905, 1025];
  return caps.findIndex((c) => dex <= c) + 1;
}

const titleCase = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

function build(raw: Raw): PokemonSpecies {
  const b = raw.baseStats;
  const role: Role = SUPPORT.has(raw.id) ? "support" : b.spa > b.atk ? "ranged" : "melee";
  return {
    id: raw.id,
    nationalDexNumber: raw.nationalDexNumber ?? raw.id,
    name: raw.name??raw.slug.split("-").map(titleCase).join(" "),
    slug: raw.slug,
    types: raw.types as PokemonType[],
    baseStats: b,
    baseExp: raw.baseExp,
    catchRate: raw.catchRate ?? 45, // real catch rate from PokéAPI (0-255, higher = easier)
    role,
    evolution: EVOLUTIONS[raw.id],
    generation: generationOf(raw.nationalDexNumber ?? raw.id),
    form: raw.form,
  };
}

export const SPECIES: Record<number, PokemonSpecies> = Object.fromEntries(
  Object.values(generated as unknown as Record<string, Raw>).map((r) => [r.id, build(r)]),
);

export function getSpecies(id: number): PokemonSpecies {
  const s = SPECIES[id];
  if (!s) throw new Error(`Unknown species ${id}`);
  return s;
}

export const speciesIdBySlug = (slug: string): number | undefined => Object.values(SPECIES).find((s) => s.slug === slug)?.id;

export const allSpecies = (): PokemonSpecies[] => Object.values(SPECIES);
