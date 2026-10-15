import { ENV_FRAMES } from "@/assets/registry";

export interface TileDef {
  /** frame in the Kenney tilemap, or null => draw `placeholderColor` */
  base: number | null;
  /** optional sprite drawn on top (trees, roofs...) */
  over?: number;
  tint?: number;
  placeholderColor?: number;
  solid?: boolean;
  /** triggers wild encounter checks */
  encounter?: boolean;
}

/**
 * Tile legend. Maps only contain these single characters.
 * TODO: Replace placeholders (water, tall grass tint) with properly licensed assets.
 */
export const TILE_DEFS: Record<string, TileDef> = {
  ".": { base: ENV_FRAMES.grass },
  ",": { base: ENV_FRAMES.grassTufts },
  f: { base: ENV_FRAMES.grassFlowers },
  p: { base: ENV_FRAMES.path },
  '"': { base: ENV_FRAMES.grassTufts, tint: 0x3a9e4a, encounter: true }, // tall grass (tinted tile = placeholder)
  T: { base: ENV_FRAMES.grass, over: ENV_FRAMES.treeGreen, solid: true },
  O: { base: ENV_FRAMES.grass, over: ENV_FRAMES.treeOrange, solid: true },
  b: { base: ENV_FRAMES.grass, over: ENV_FRAMES.bush, solid: true },
  m: { base: ENV_FRAMES.grass, over: ENV_FRAMES.mushrooms },
  F: { base: ENV_FRAMES.grass, over: ENV_FRAMES.fenceH, solid: true },
  S: { base: ENV_FRAMES.grass, over: ENV_FRAMES.sign, solid: true },
  W: { base: null, placeholderColor: 0x3b82c4, solid: true }, // water placeholder
  // grid-only chars used by pre-rendered (pret) maps, whose visuals come from baked images
  _: { base: null, placeholderColor: 0x000000 },
  "#": { base: null, placeholderColor: 0x000000, solid: true },
  // houses
  R: { base: ENV_FRAMES.roofRedM, solid: true },
  r: { base: ENV_FRAMES.roofRedLow, solid: true },
  w: { base: ENV_FRAMES.wallBrick, solid: true },
  k: { base: ENV_FRAMES.windowWall, solid: true },
  D: { base: ENV_FRAMES.door },
  // interiors
  i: { base: 109 },
  N: { base: 126, solid: true },
  L: { base: 99, solid: true },
};

export const tileAt = (rows: string[], x: number, y: number): TileDef | undefined => {
  const ch = rows[y]?.[x];
  return ch === undefined ? undefined : TILE_DEFS[ch];
};
