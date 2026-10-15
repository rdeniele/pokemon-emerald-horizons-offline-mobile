/** Painted fan-art launch set. Uncovered species keep their existing assets. */
export const FAN_ART: Readonly<Record<number, string>> = {};

export function hasFanArt(speciesId: number, shiny = false): boolean {
  return !shiny && !!FAN_ART[speciesId];
}
