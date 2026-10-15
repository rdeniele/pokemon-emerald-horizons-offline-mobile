/** Shape of the optional, locally-generated pret/pokeemerald data (see docs/PRET_IMPORT.md). */
export interface PretMove {
  name: string;
  type: string;
  power: number;
  accuracy: number;
  pp: number;
  /** EFFECT_* from the decomp without the prefix, e.g. "BURN_HIT" */
  effect: string;
  chance: number;
  /** MOVE_TARGET_* without prefix: SELECTED, BOTH, FOES_AND_ALLY, USER... */
  target: string;
  priority: number;
}

export interface PretTrainerMon {
  species: string;
  level: number;
  moves?: string[];
}

export interface PretTrainer {
  name: string;
  class: string;
  double: boolean;
  party: PretTrainerMon[];
}

export interface PretScript {
  texts: string[];
  trainer?: { kind: string; id: string; a: string; b?: string };
}

export interface PretData {
  source: string;
  encounters: Record<string, { rate: number; slots: { species: string; min: number; max: number; weight: number }[] }>;
  moves: Record<string, PretMove>;
  /** species slug -> [level, move slug][] */
  learnsets: Record<string, [number, string][]>;
  trainers: Record<string, PretTrainer>;
  /** text label -> pages */
  text: Record<string, string[]>;
  scripts: Record<string, PretScript>;
  maps: Record<string, { npcs: { gfx: string; x: number; y: number; script: string; trainer: boolean; sight: number }[]; signs: { x: number; y: number; script: string }[] }>;
}
