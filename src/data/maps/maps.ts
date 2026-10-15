import { PRET_MAPS, PRET_START } from "@/data/pret/maps.generated";
import { Grid } from "./builder";
import type { MapDef, NpcDef } from "./types";

function littleroot(): MapDef {
  const g = new Grid(20, 14).border("T");
  g.rect(9, 0, 2, 10, "p").rect(9, 8, 7, 1, "p").rect(15, 5, 1, 4, "p").rect(4, 5, 1, 4, "p").rect(4, 8, 6, 1, "p");
  g.house(2, 2);
  g.set(4, 4, "w"); // decorative house: door not enterable
  g.house(13, 2); // Professor's lab (door at 15,4)
  for (const [x, y] of [[6, 6], [7, 11], [12, 11], [16, 10], [3, 10], [17, 7]]) g.set(x, y, "f");
  g.set(8, 6, "S");
  g.set(2, 9, "O").set(17, 12, "O").set(3, 12, "b");
  return {
    id: "littleroot",
    name: "Littleroot Town",
    width: 20,
    height: 14,
    tiles: g.rows(),
    assetGroup: "outdoor",
    warps: [
      { x: 9, y: 0, to: "route101", tx: 6, ty: 22 },
      { x: 10, y: 0, to: "route101", tx: 7, ty: 22 },
      { x: 15, y: 4, to: "birchLab", tx: 5, ty: 6 },
    ],
    npcs: [
      { id: "lr_twin", name: "Girl", x: 6, y: 10, dialogueId: "littleroot_girl", pretScript: "LittlerootTown_EventScript_Twin", color: 0xe8749a },
      { id: "lr_fatman", name: "Man", x: 12, y: 12, dialogueId: "littleroot_man", pretScript: "LittlerootTown_EventScript_FatMan", color: 0x8d6e63 },
      { id: "lr_boy", name: "Boy", x: 16, y: 11, dialogueId: "littleroot_boy", pretScript: "LittlerootTown_EventScript_Boy", color: 0x5c9ad6 },
    ],
    signs: [
      { x: 8, y: 6, text: ["LITTLEROOT TOWN", "A town that can't be shaded any hue."], pretText: "LittlerootTown_Text_TownSign" },
    ],
  };
}

function birchLab(): MapDef {
  const g = new Grid(10, 8, "i").border("N").rect(0, 0, 10, 2, "N").rect(2, 2, 6, 1, "L");
  g.set(5, 7, "D");
  return {
    id: "birchLab",
    name: "Professor's Lab",
    width: 10,
    height: 8,
    tiles: g.rows(),
    assetGroup: "indoor",
    warps: [{ x: 5, y: 7, to: "littleroot", tx: 15, ty: 5 }],
    npcs: [
      { id: "birch", name: "Prof. Birch", x: 5, y: 4, scene: "labBirch", showIf: { flag: "rescuedBirch", is: true }, color: 0xf2f2f2 },
      { id: "lab_aide", name: "Aide", x: 8, y: 5, dialogueId: "lab_aide", pretScript: "LittlerootTown_ProfessorBirchsLab_EventScript_Aide", color: 0xb0bec5 },
    ],
    signs: [],
  };
}

function route101(): MapDef {
  const g = new Grid(14, 24).border("T");
  g.rect(6, 0, 2, 24, "p");
  g.rect(1, 3, 5, 7, '"').rect(8, 10, 5, 8, '"').rect(1, 14, 5, 7, '"');
  for (const [x, y] of [[9, 3], [11, 5], [8, 20], [11, 21], [3, 12]]) g.set(x, y, "f");
  g.set(10, 6, "O").set(2, 21, "O").set(12, 2, "T").set(1, 11, "b").set(8, 21, "S");
  return {
    id: "route101",
    name: "Route 101",
    width: 14,
    height: 24,
    tiles: g.rows(),
    assetGroup: "outdoor",
    encounterZone: "route101",
    warps: [
      { x: 6, y: 0, to: "oldale", tx: 9, ty: 12 },
      { x: 7, y: 0, to: "oldale", tx: 10, ty: 12 },
      { x: 6, y: 23, to: "littleroot", tx: 9, ty: 1 },
      { x: 7, y: 23, to: "littleroot", tx: 10, ty: 1 },
    ],
    npcs: [
      { id: "r101_kid", name: "Youngster", x: 5, y: 12, dialogueId: "route101_kid", pretScript: "Route101_EventScript_Youngster", color: 0x4a7bd1 },
      { id: "r101_boy", name: "Boy", x: 2, y: 12, dialogueId: "route101_boy", pretScript: "Route101_EventScript_Boy", color: 0x7e57c2 },
    ],
    signs: [{ x: 8, y: 21, text: ["ROUTE 101", "↑ OLDALE TOWN"], pretText: "Route101_Text_RouteSign" }],
    // the Birch rescue: stepping north into the grass without a Pokémon
    triggers: [
      { x: 6, y: 19, scene: "birchRescue", when: { flag: "rescuedBirch", is: false } },
      { x: 7, y: 19, scene: "birchRescue", when: { flag: "rescuedBirch", is: false } },
    ],
  };
}

function oldale(): MapDef {
  const g = new Grid(20, 14).border("T");
  g.rect(9, 6, 2, 8, "p").rect(0, 6, 19, 2, "p");
  g.house(3, 1);
  g.set(5, 3, "w");
  g.house(13, 1);
  g.set(15, 3, "w");
  for (const [x, y] of [[4, 9], [15, 10], [12, 4], [7, 4]]) g.set(x, y, "f");
  g.set(8, 4, "S").set(2, 11, "O").set(17, 11, "O");
  return {
    id: "oldale",
    name: "Oldale Town",
    width: 20,
    height: 14,
    tiles: g.rows(),
    assetGroup: "outdoor",
    warps: [
      { x: 9, y: 13, to: "route101", tx: 6, ty: 1 },
      { x: 10, y: 13, to: "route101", tx: 7, ty: 1 },
      { x: 0, y: 6, to: "route102", tx: 26, ty: 5 },
      { x: 0, y: 7, to: "route102", tx: 26, ty: 6 },
    ],
    npcs: [
      { id: "oldale_nurse", name: "Nurse", x: 10, y: 4, dialogueId: "oldale_nurse", color: 0xf59bb8 },
      { id: "oldale_girl", name: "Girl", x: 16, y: 9, dialogueId: "oldale_girl", pretScript: "OldaleTown_EventScript_Girl", color: 0xec7ab0 },
      { id: "oldale_mart", name: "Mart Employee", x: 13, y: 5, dialogueId: "oldale_mart", pretScript: "OldaleTown_EventScript_MartEmployee", color: 0x4db6ac },
      { id: "oldale_maniac", name: "Man", x: 6, y: 9, dialogueId: "oldale_maniac", pretScript: "OldaleTown_EventScript_FootprintsMan", color: 0x8d6e63 },
    ],
    signs: [{ x: 8, y: 4, text: ["OLDALE TOWN", "Where things start off scarce."], pretText: "OldaleTown_Text_TownSign" }],
  };
}

function route102(): MapDef {
  const g = new Grid(28, 12).border("T");
  g.rect(0, 5, 28, 2, "p");
  g.rect(2, 1, 6, 4, '"').rect(2, 7, 6, 4, '"').rect(18, 7, 8, 4, '"').rect(19, 1, 6, 3, '"');
  g.rect(11, 1, 5, 3, "W"); // pond (placeholder water)
  for (const [x, y] of [[9, 8], [16, 8], [10, 5], [26, 3]]) g.set(x, y, "f");
  g.set(9, 3, "O").set(16, 10, "O").set(12, 8, "b");
  return {
    id: "route102",
    name: "Route 102",
    width: 28,
    height: 12,
    tiles: g.rows(),
    assetGroup: "outdoor",
    encounterZone: "route102",
    warps: [
      { x: 27, y: 5, to: "oldale", tx: 1, ty: 6 },
      { x: 27, y: 6, to: "oldale", tx: 1, ty: 7 },
      { x: 0, y: 5, to: "petalburg", tx: 18, ty: 6 },
      { x: 0, y: 6, to: "petalburg", tx: 18, ty: 7 },
    ],
    npcs: [
      { id: "r102_boy", name: "Boy", x: 20, y: 4, dialogueId: "route102_catcher", pretScript: "Route102_EventScript_Boy", color: 0x6aa84f },
      { id: "r102_littleboy", name: "Little Boy", x: 13, y: 8, dialogueId: "route102_littleboy", pretScript: "Route102_EventScript_LittleBoy", color: 0x90caf9 },
      { id: "r102_allen", name: "Allen", x: 8, y: 2, pretScript: "Route102_EventScript_Allen", requiresPret: true, color: 0x4a7bd1 },
      { id: "r102_tiana", name: "Tiana", x: 4, y: 9, pretScript: "Route102_EventScript_Tiana", requiresPret: true, color: 0xec7ab0 },
      { id: "r102_rick", name: "Rick", x: 21, y: 9, pretScript: "Route102_EventScript_Rick", requiresPret: true, color: 0x6aa84f },
      { id: "r102_calvin", name: "Calvin", x: 22, y: 2, pretScript: "Route102_EventScript_Calvin", requiresPret: true, color: 0x4a7bd1 },
    ],
    signs: [],
  };
}

function petalburg(): MapDef {
  const g = new Grid(20, 14).border("T");
  g.rect(1, 6, 19, 2, "p");
  g.house(2, 1);
  g.set(4, 3, "w");
  g.house(8, 1);
  g.set(10, 3, "w");
  g.house(14, 1); // gym (decorative in this slice)
  g.set(16, 3, "w");
  for (const [x, y] of [[5, 10], [12, 10], [3, 5], [17, 10]]) g.set(x, y, "f");
  g.set(13, 4, "S").set(2, 11, "O").set(16, 12, "O");
  return {
    id: "petalburg",
    name: "Petalburg City",
    width: 20,
    height: 14,
    tiles: g.rows(),
    assetGroup: "outdoor",
    warps: [
      { x: 19, y: 6, to: "route102", tx: 1, ty: 5 },
      { x: 19, y: 7, to: "route102", tx: 1, ty: 6 },
    ],
    npcs: [
      { id: "pb_gymboy", name: "Boy", x: 9, y: 9, dialogueId: "petalburg_guide", pretScript: "PetalburgCity_EventScript_GymBoy", setsFlag: "talkedPetalburgGuide", color: 0xd9a441 },
      { id: "pb_mom", name: "Woman", x: 15, y: 9, dialogueId: "petalburg_woman", pretScript: "PetalburgCity_EventScript_WallysMom", color: 0xe57373 },
      { id: "pb_boy", name: "Boy", x: 6, y: 9, dialogueId: "petalburg_boy", pretScript: "PetalburgCity_EventScript_Boy", color: 0x5c9ad6 },
      { id: "pb_gent", name: "Gentleman", x: 11, y: 11, dialogueId: "petalburg_gent", pretScript: "PetalburgCity_EventScript_Gentleman", color: 0x455a64 },
    ],
    signs: [{ x: 13, y: 4, text: ["PETALBURG CITY GYM", "The gym is closed. (Coming soon!)"], pretText: "PetalburgCity_Text_GymSign" }],
  };
}

const HAND_MAPS: Record<string, MapDef> = Object.fromEntries(
  [littleroot(), birchLab(), route101(), oldale(), route102(), petalburg()].map((m) => [m.id, m]),
);

/** True when the local pret/pokeemerald map import is present (real layouts, tilesets and sprites). */
export const hasPretMaps = PRET_MAPS !== null;

/**
 * Our behaviour for NPCs whose Emerald scripts are bigger than this prototype (the nurse, moms, Birch in
 * his lab...). Keyed by pret script label; merged onto the imported NPC.
 */
const NPC_OVERRIDES: Record<string, Partial<NpcDef>> = {
  OldaleTown_PokemonCenter_1F_EventScript_Nurse: { dialogueId: "nurse", ownDialogue: true },
  PetalburgCity_PokemonCenter_1F_EventScript_Nurse: { dialogueId: "nurse", ownDialogue: true },
  PlayersHouse_1F_EventScript_Mom: { dialogueId: "mom", ownDialogue: true },
  RivalsHouse_1F_EventScript_RivalMom: { dialogueId: "rival_mom", ownDialogue: true },
  PetalburgCity_EventScript_GymBoy: { setsFlag: "talkedPetalburgGuide" },
};

function withOverrides(maps: Record<string, MapDef>): Record<string, MapDef> {
  return Object.fromEntries(
    Object.entries(maps).map(([k, m]) => [
      k,
      { ...m, npcs: m.npcs.map((n) => ({ ...n, ...(n.pretScript ? NPC_OVERRIDES[n.pretScript] : undefined) })) },
    ]),
  );
}

export const MAPS: Record<string, MapDef> = PRET_MAPS ? withOverrides(PRET_MAPS) : HAND_MAPS;

/**
 * Where you wake up after blacking out: the Pokémon Center you last visited (or home).
 * Spots are the nurse's counter (Emerald puts you there); only maps that exist are listed.
 */
const HEAL_CANDIDATES: Record<string, { x: number; y: number; facing: "up" | "down" | "left" | "right" }> = {
  brendansHouse2F: { x: 4, y: 2, facing: "down" },
  oldaleCenter: { x: 7, y: 4, facing: "up" },
  petalburgCenter: { x: 7, y: 4, facing: "up" },
};
export const HEAL_SPOTS = Object.fromEntries(Object.entries(HEAL_CANDIDATES).filter(([id]) => id in MAPS));

export const START_LOCATION = PRET_START ?? { map: "littleroot", x: 10, y: 10, facing: "up" as const };

/** First heal spot = home (the start of the game) when real maps exist, otherwise the start location. */
export const DEFAULT_HEAL: { map: string; x: number; y: number; facing: "up" | "down" | "left" | "right" } = HEAL_SPOTS.brendansHouse2F
  ? { map: "brendansHouse2F", ...HEAL_SPOTS.brendansHouse2F }
  : { map: START_LOCATION.map, x: START_LOCATION.x, y: START_LOCATION.y, facing: START_LOCATION.facing };
