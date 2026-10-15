export interface Warp {
  x: number;
  y: number;
  to: string;
  tx: number;
  ty: number;
  /** destination isn't part of this prototype yet: the door just won't open */
  locked?: boolean;
}

export type Dir = "up" | "down" | "left" | "right";

/** Seamless edge-to-edge link to a neighbouring map (Emerald routes). `offset` shifts the neighbour along the shared edge. */
export interface Connection {
  dir: Dir;
  to: string;
  offset: number;
}

export interface FlagCondition {
  flag: string;
  is: boolean;
}

export interface NpcDef {
  id: string;
  name: string;
  x: number;
  y: number;
  /** placeholder body color until real NPC sprites are licensed */
  color: number;
  /** our own fallback dialogue (data/dialogue). Used when no pret text is available. */
  dialogueId?: string;
  /** pret/pokeemerald script label (e.g. "Route102_EventScript_Calvin"): its text/trainer data is used when imported */
  pretScript?: string;
  /** run a named cutscene (data/cutscenes) instead of plain dialogue */
  scene?: string;
  /** story flag set to true when the player talks to this NPC */
  setsFlag?: string;
  /** only present while this story flag has this value */
  showIf?: FlagCondition;
  /** overworld sprite sheet name (local pret import); frames: 0 south, 1 north, 2 west (east = flipped) */
  sprite?: string;
  facing?: Dir;
  /** use dialogueId even if imported text exists (our own behaviour, e.g. the nurse) */
  ownDialogue?: boolean;
  /** trainers spot you when you stand within `range` clear tiles in one of `dirs` (line of sight) */
  sight?: { range: number; dirs: Dir[] };
  /** NPC only exists when the pret import is present (e.g. trainers whose teams come from pret) */
  requiresPret?: boolean;
}

export interface SignDef {
  x: number;
  y: number;
  text: string[];
  /** pret text label that overrides `text` when imported */
  pretText?: string;
  /** pret script label whose first message is shown (local import) */
  pretScript?: string;
}

/** Stepping on (x, y) runs a cutscene when `when` holds. */
export interface Trigger {
  x: number;
  y: number;
  scene: string;
  when?: FlagCondition;
}

export interface MapDef {
  id: string;
  name: string;
  width: number;
  height: number;
  /** one string per row, one char per tile; meaning defined in tileDefs.ts */
  tiles: string[];
  warps: Warp[];
  npcs: NpcDef[];
  signs: SignDef[];
  triggers?: Trigger[];
  /** encounter table id (data/encounters) used by encounter tiles on this map */
  encounterZone?: string;
  /** assets to preload when entering (so a small route doesn't load a whole world) */
  assetGroup: "outdoor" | "indoor";
  connections?: Connection[];
  /** pre-rendered layers (local pret import): `under` is drawn beneath characters, `over` above them */
  render?: { under: string; over: string };
}
