/**
 * Central Pokémon sprite resolver. Nothing else in the app builds sprite paths.
 *
 * Normalized layout (see docs/ASSET_PIPELINE.md):
 *   /assets/pokemon/<dex padded to 3>/front.png | back.png | shiny-front.png | shiny-back.png
 * Files are optional; scripts/fetch-sprites.mjs writes manifest.json listing what exists.
 * Missing variants fall back (back -> front, shiny -> normal) and finally to a generated placeholder.
 */
import { FAN_ART, hasFanArt } from "./fanArt";
import empressSprites from "@/data/pokemon/empress-sprites.generated.json";
const importedSprites=empressSprites as Record<string,string>;

export const getEmpressSprite=(speciesId:number):string=>importedSprites[speciesId]??`/assets/pokemon/${pad3(speciesId)}/front.png`;

export type SpriteSide = "front" | "back";

export interface SpriteOptions {
  side?: SpriteSide;
  shiny?: boolean;
}

export const pad3 = (n: number) => String(n).padStart(3, "0");

export type SpriteManifest = Record<string, { slug: string; variants: string[] }>;

let manifest: SpriteManifest = {};
export function setSpriteManifest(m: SpriteManifest) {
  manifest = m;
}
export const getSpriteManifest = () => manifest;

export function spriteVariantName(side: SpriteSide, shiny: boolean): string {
  return `${shiny ? "shiny-" : ""}${side}`;
}

/** The variant that will actually be served after fallbacks, or null if none exists. */
export function resolveVariant(speciesId: number, { side = "front", shiny = false }: SpriteOptions = {}): string | null {
  const have = manifest[speciesId]?.variants;
  if (!have) return null;
  const order = [
    spriteVariantName(side, shiny),
    spriteVariantName("front", shiny),
    spriteVariantName(side, false),
    spriteVariantName("front", false),
  ];
  return order.find((v) => have.includes(v)) ?? null;
}

export function getPokemonSprite(speciesId: number, opts: SpriteOptions = {}): string | null {
  if(importedSprites[speciesId]&&!opts.shiny)return importedSprites[speciesId];
  if (opts.side !== "back" && hasFanArt(speciesId, opts.shiny)) return FAN_ART[speciesId];
  const v = resolveVariant(speciesId, opts);
  return v ? `/assets/pokemon/${pad3(speciesId)}/${v}.png` : null;
}

/** Phaser texture key for a species variant (one texture per resolved file). */
export function pokemonTextureKey(speciesId: number, opts: SpriteOptions = {}): string {
  if (opts.side !== "back" && hasFanArt(speciesId, opts.shiny)) return `pokemon:painted:${speciesId}:v1`;
  return `pokemon:${pad3(speciesId)}:${resolveVariant(speciesId, opts) ?? "placeholder"}`;
}
