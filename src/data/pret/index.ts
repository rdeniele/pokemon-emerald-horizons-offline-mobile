import { PRET } from "./generated";
import type { PretMove, PretTrainer } from "./types";

export { PRET };
export type { PretData } from "./types";

/** True when the bundled pret/pokeemerald import is present (see docs/PRET_IMPORT.md). */
export const hasPret = PRET !== null;

export const pretMove = (slug: string): PretMove | undefined => PRET?.moves[slug];
export const pretLearnset = (slug: string): [number, string][] | undefined => PRET?.learnsets[slug];
export const pretTrainer = (id: string): PretTrainer | undefined => PRET?.trainers[id];

/** Dialogue pages for a pret text label, or undefined. Substitutes {PLAYER}; other placeholders stay readable. */
export function pretText(label: string | undefined, playerName = "Trainer", vars: Record<string, string> = {}): string[] | undefined {
  if (!label) return undefined;
  const pages = PRET?.text[label];
  return pages?.map((p) =>
    p
      .replace(/\{PLAYER\}/g, playerName)
      .replace(/\{RIVAL\}/g, "RIVAL")
      .replace(/\{(STR_VAR_\d)\}/g, (_, k: string) => vars[k] ?? "POKéMON"),
  );
}

/** First text label referenced by a pret script, e.g. an NPC's `msgbox`. */
export const pretScriptTexts = (script: string | undefined): string[] => (script ? (PRET?.scripts[script]?.texts ?? []) : []);
export const pretScriptTrainer = (script: string | undefined) => (script ? PRET?.scripts[script]?.trainer : undefined);
