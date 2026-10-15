import { PRET } from "@/data/pret";
import { speciesIdBySlug } from "@/pokemon/species/species";

export interface EncounterEntry {
  speciesId: number;
  weight: number;
  minLevel: number;
  maxLevel: number;
}

export interface EncounterZone {
  id: string;
  /** chance per step on an encounter tile, 0..1 */
  encounterRate: number;
  speciesPool: EncounterEntry[];
}

/** Hand-written fallback tables, used when the pret import isn't present. */
const FALLBACK: Record<string, EncounterZone> = {
  route101: {
    id: "route101",
    encounterRate: 0.12,
    speciesPool: [
      { speciesId: 263, weight: 45, minLevel: 2, maxLevel: 3 }, // Zigzagoon
      { speciesId: 265, weight: 45, minLevel: 2, maxLevel: 3 }, // Wurmple
      { speciesId: 261, weight: 10, minLevel: 2, maxLevel: 3 }, // Poochyena
    ],
  },
  route102: {
    id: "route102",
    encounterRate: 0.12,
    speciesPool: [
      { speciesId: 263, weight: 20, minLevel: 3, maxLevel: 4 },
      { speciesId: 265, weight: 15, minLevel: 3, maxLevel: 4 },
      { speciesId: 261, weight: 15, minLevel: 3, maxLevel: 4 },
      { speciesId: 270, weight: 15, minLevel: 3, maxLevel: 4 }, // Lotad
      { speciesId: 273, weight: 15, minLevel: 3, maxLevel: 4 }, // Seedot
      { speciesId: 280, weight: 4, minLevel: 4, maxLevel: 4 }, // Ralts
      { speciesId: 276, weight: 10, minLevel: 3, maxLevel: 4 }, // Taillow
    ],
  },
};

/**
 * Real Emerald land-encounter slots (species, level range, slot percentage). The game's per-step
 * chance is rate*16/2880 (= rate/180). Each encounter rolls one wild Pokémon.
 */
function fromPret(key: string): EncounterZone | undefined {
  const e = PRET?.encounters[key];
  if (!e) return undefined;
  const speciesPool: EncounterEntry[] = [];
  for (const slot of e.slots) {
    const speciesId = speciesIdBySlug(slot.species);
    if (!speciesId) continue; // no sprite/stats for it yet
    const same = speciesPool.find((p) => p.speciesId === speciesId && p.minLevel === slot.min && p.maxLevel === slot.max);
    if (same) same.weight += slot.weight;
    else speciesPool.push({ speciesId, weight: slot.weight, minLevel: slot.min, maxLevel: slot.max });
  }
  if (!speciesPool.length) return undefined;
  return { id: key, encounterRate: e.rate / 180, speciesPool };
}

/** Encounter tables by zone id. Add rows (or pret maps) here; no code changes needed elsewhere. */
export const ENCOUNTER_ZONES: Record<string, EncounterZone> = Object.fromEntries(
  Object.keys(FALLBACK).map((k) => [k, fromPret(k) ?? FALLBACK[k]]),
);
