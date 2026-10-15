import type { PokemonType } from "@/pokemon/types/typeChart";

export type Side = "player" | "enemy";
export type MoveCategory = "physical" | "special";

export type TargetStrategy =
  | "nearest"
  | "lowestHP"
  | "highestThreat"
  | "lowestDefense"
  | "random"
  | "manual"
  | "lowestHPAlly";

export type StatusKind = "burn" | "poison" | "paralysis" | "stun" | "slow" | "sleep" | "root";

export interface StatusApplication {
  kind: StatusKind;
  /** 0..1 chance on hit */
  chance: number;
  /** seconds */
  duration: number;
}

export type SkillSlot = "skill1" | "skill2" | "ultimate";

export interface Skill {
  id: string;
  name: string;
  slot: SkillSlot;
  type: PokemonType;
  category: MoveCategory;
  kind: "damage" | "heal" | "buff" | "control";
  buff?: "attack" | "defense" | "speed";
  /** Pokémon-style base power (damage) or % of max HP healed (heal) */
  power: number;
  /** seconds */
  cooldown: number;
  /** grid cells */
  range: number;
  /** 0 = single target; >0 hits everything within this many cells of the target */
  aoeRadius: number;
  targetStrategy: TargetStrategy;
  status?: StatusApplication;
}

export interface BaseStats {
  hp: number;
  atk: number;
  def: number;
  spa: number;
  spd: number;
  spe: number;
}

/** Everything the battle engine needs to know about one combatant. Engine never reads species DB. */
export interface UnitSpec {
  id: string;
  name: string;
  speciesId: number;
  level: number;
  types: PokemonType[];
  stats: BaseStats; // final computed stats
  /** seconds between basic attacks */
  attackCooldown: number;
  /** grid cells */
  attackRange: number;
  /** grid cells / second */
  movementSpeed: number;
  /** PvE stage advantage only; omitted for wild battles and multiplayer. */
  damageDealtMultiplier?: number;
  basic: { name: string; type: PokemonType; category: MoveCategory; power: number };
  targetStrategy: TargetStrategy;
  skills: Skill[];
}

export interface FormationSlot {
  unitId: string;
  x: number;
  y: number;
}

export interface GridConfig {
  cols: number;
  /** rows owned by each side. Enemy occupies top rows. */
  rowsPerSide: number;
  /** empty rows between the two sides: units must walk across, so position and range matter */
  gapRows: number;
}

export const totalRows = (g: GridConfig) => g.rowsPerSide * 2 + g.gapRows;

export const DEFAULT_GRID: GridConfig = { cols: 6, rowsPerSide: 3, gapRows: 2 };

export interface AutoConfig {
  basic: boolean;
  skills: boolean;
  ultimate: boolean;
}

export interface BattleSideSetup {
  /** full roster in priority order; the first maxUnits (by formation) deploy, the rest are reserves */
  roster: UnitSpec[];
  formation: FormationSlot[];
  maxUnits: number;
}

export interface BattleSetup {
  /** Free-moving arena combat; omitted for legacy simulation consumers. */
  arena?: boolean;
  arenaId?: string;
  obstacles?: import("./field").Obstacle[];
  seed: number;
  grid?: GridConfig;
  player: BattleSideSetup;
  enemy: BattleSideSetup;
  /** seconds before the player side is declared the loser */
  timeLimit?: number;
}

export interface StatusState {
  kind: StatusKind;
  remaining: number;
}

export interface BattleUnit {
  channelUntil?:number;
  travelMove?: {kind:"fly"|"dig"|"dive"|"vanish";started:number;until:number;x:number;y:number};
  buff?: {kind: "attack" | "defense" | "speed"; until:number};
  dashReadyAt?: number;
  dodgeUntil?: number;
  actionReadyAt?: number;
  spec: UnitSpec;
  side: Side;
  x: number;
  y: number;
  hp: number;
  maxHp: number;
  alive: boolean;
  deployed: boolean;
  /** seconds until next basic attack */
  basicCooldown: number;
  skillCooldowns: Record<string, number>;
  statuses: StatusState[];
  threat: number;
  /** fractional damage-over-time carried between ticks */
  dotRemainder: number;
  targetId: string | null;
  manualTargetId: string | null;
  /** home slot, so a replacement can take over the position */
  slot: { x: number; y: number };
}
