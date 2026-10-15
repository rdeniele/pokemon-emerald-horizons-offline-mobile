import { SPECIES } from "@/pokemon/species/species";

export interface StarterGeneration {
  generation: number;
  region: string;
  /** [grass, fire, water] national dex numbers */
  choices: number[];
}

/** Data-driven. The UI renders whatever is here, filtered to species that exist in the database. */
const ALL: StarterGeneration[] = [
  { generation: 1, region: "Kanto", choices: [1, 4, 7] },
  { generation: 2, region: "Johto", choices: [152, 155, 158] },
  { generation: 3, region: "Hoenn", choices: [252, 255, 258] },
  { generation: 4, region: "Sinnoh", choices: [387, 390, 393] },
  { generation: 5, region: "Unova", choices: [495, 498, 501] },
  { generation: 6, region: "Kalos", choices: [650, 653, 656] },
  { generation: 7, region: "Alola", choices: [722, 725, 728] },
  { generation: 8, region: "Galar", choices: [810, 813, 816] },
  { generation: 9, region: "Paldea", choices: [906, 909, 912] },
];

export const STARTER_LEVEL = 5;

export const STARTER_GENERATIONS: StarterGeneration[] = ALL.map((g) => ({
  ...g,
  choices: g.choices.filter((id) => SPECIES[id]),
})).filter((g) => g.choices.length > 0);
