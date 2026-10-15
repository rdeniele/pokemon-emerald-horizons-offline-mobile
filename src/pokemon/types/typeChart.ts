/** Gen 6+ type chart as data. typeChart[attacker][defender] = multiplier; missing entry = 1 (neutral). */
export const POKEMON_TYPES = [
  "normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison", "ground",
  "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel", "fairy",
] as const;
export type PokemonType = (typeof POKEMON_TYPES)[number];

type Row = Partial<Record<PokemonType, number>>;

const row = (se: PokemonType[], nve: PokemonType[], imm: PokemonType[] = []): Row => {
  const r: Row = {};
  for (const t of se) r[t] = 2;
  for (const t of nve) r[t] = 0.5;
  for (const t of imm) r[t] = 0;
  return r;
};

export const typeChart: Record<PokemonType, Row> = {
  normal: row([], ["rock", "steel"], ["ghost"]),
  fire: row(["grass", "ice", "bug", "steel"], ["fire", "water", "rock", "dragon"]),
  water: row(["fire", "ground", "rock"], ["water", "grass", "dragon"]),
  electric: row(["water", "flying"], ["electric", "grass", "dragon"], ["ground"]),
  grass: row(["water", "ground", "rock"], ["fire", "grass", "poison", "flying", "bug", "dragon", "steel"]),
  ice: row(["grass", "ground", "flying", "dragon"], ["fire", "water", "ice", "steel"]),
  fighting: row(["normal", "ice", "rock", "dark", "steel"], ["poison", "flying", "psychic", "bug", "fairy"], ["ghost"]),
  poison: row(["grass", "fairy"], ["poison", "ground", "rock", "ghost"], ["steel"]),
  ground: row(["fire", "electric", "poison", "rock", "steel"], ["grass", "bug"], ["flying"]),
  flying: row(["grass", "fighting", "bug"], ["electric", "rock", "steel"]),
  psychic: row(["fighting", "poison"], ["psychic", "steel"], ["dark"]),
  bug: row(["grass", "psychic", "dark"], ["fire", "fighting", "poison", "flying", "ghost", "steel", "fairy"]),
  rock: row(["fire", "ice", "flying", "bug"], ["fighting", "ground", "steel"]),
  ghost: row(["psychic", "ghost"], ["dark"], ["normal"]),
  dragon: row(["dragon"], ["steel"], ["fairy"]),
  dark: row(["psychic", "ghost"], ["fighting", "dark", "fairy"]),
  steel: row(["ice", "rock", "fairy"], ["fire", "water", "electric", "steel"]),
  fairy: row(["fighting", "dragon", "dark"], ["fire", "poison", "steel"]),
};

/** Combined multiplier of an attacking type against a (possibly dual-typed) defender. */
export function typeEffectiveness(attack: PokemonType, defenderTypes: readonly PokemonType[]): number {
  let m = 1;
  for (const d of defenderTypes) m *= typeChart[attack][d] ?? 1;
  return m;
}

export type EffectivenessLabel = "immune" | "not-very-effective" | "neutral" | "super-effective";
export function effectivenessLabel(m: number): EffectivenessLabel {
  if (m === 0) return "immune";
  if (m < 1) return "not-very-effective";
  if (m > 1) return "super-effective";
  return "neutral";
}
