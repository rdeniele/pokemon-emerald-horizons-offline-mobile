import { getPokemonSprite, type SpriteOptions } from "@/pokemon/sprites/resolver";

/**
 * Centralized asset registry. Components and Phaser scenes ask for assets by logical name;
 * only this file knows where files live.
 */
export const ENV_TILESET = { key: "env:tiles", url: "/assets/environment/kenney-tiny-town/tilemap_packed.png", tileSize: 16 } as const;

/** Frame indices into the Kenney Tiny Town packed tilemap (12 columns). */
export const ENV_FRAMES = {
  grass: 0,
  grassTufts: 1,
  grassFlowers: 2,
  path: 24,
  treeGreen: 28,
  treeOrange: 27,
  bush: 5,
  mushrooms: 29,
  roofRedL: 52,
  roofRedM: 53,
  roofRedR: 54,
  roofRedLow: 65,
  wallBrick: 73,
  windowWall: 84,
  door: 85,
  sign: 83,
  fenceH: 81,
  stone: 43,
} as const;
export type EnvName = keyof typeof ENV_FRAMES;

export const assets = {
  pokemon: {
    front: (speciesId: number, opts: Omit<SpriteOptions, "side"> = {}) => getPokemonSprite(speciesId, { ...opts, side: "front" }),
    back: (speciesId: number, opts: Omit<SpriteOptions, "side"> = {}) => getPokemonSprite(speciesId, { ...opts, side: "back" }),
  },
  environment: (name: EnvName) => ({ texture: ENV_TILESET.key, frame: ENV_FRAMES[name] }),
} as const;
