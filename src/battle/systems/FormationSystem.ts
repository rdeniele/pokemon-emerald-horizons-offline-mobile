import type { FormationSlot, GridConfig, Side } from "../types";

/** Inclusive row range owned by a side. Enemy = top rows, player = bottom rows. */
export function sideRows(grid: GridConfig, side: Side): { minY: number; maxY: number } {
  return side === "enemy"
    ? { minY: 0, maxY: grid.rowsPerSide - 1 }
    : { minY: grid.rowsPerSide + grid.gapRows, maxY: grid.rowsPerSide * 2 + grid.gapRows - 1 };
}

export function isValidSlot(grid: GridConfig, side: Side, x: number, y: number): boolean {
  const { minY, maxY } = sideRows(grid, side);
  return Number.isInteger(x) && Number.isInteger(y) && x >= 0 && x < grid.cols && y >= minY && y <= maxY;
}

/** Returns a list of problems; empty means valid. */
export function validateFormation(
  grid: GridConfig,
  side: Side,
  formation: FormationSlot[],
  maxUnits: number,
): string[] {
  const errors: string[] = [];
  const seenCells = new Set<string>();
  const seenUnits = new Set<string>();
  if (formation.length > maxUnits) errors.push(`too many units (${formation.length} > ${maxUnits})`);
  for (const s of formation) {
    if (!isValidSlot(grid, side, s.x, s.y)) errors.push(`${s.unitId}: slot (${s.x},${s.y}) outside ${side} side`);
    const key = `${s.x},${s.y}`;
    if (seenCells.has(key)) errors.push(`${s.unitId}: slot (${key}) already occupied`);
    seenCells.add(key);
    if (seenUnits.has(s.unitId)) errors.push(`${s.unitId}: placed twice`);
    seenUnits.add(s.unitId);
  }
  return errors;
}

/** Place/move a unit; swaps with whoever occupies the target cell. Pure: returns a new formation. */
export function placeUnit(formation: FormationSlot[], unitId: string, x: number, y: number): FormationSlot[] {
  const mine = formation.find((s) => s.unitId === unitId);
  const occupant = formation.find((s) => s.x === x && s.y === y && s.unitId !== unitId);
  const out = formation.filter((s) => s.unitId !== unitId && s !== occupant);
  out.push({ unitId, x, y });
  if (occupant && mine) out.push({ unitId: occupant.unitId, x: mine.x, y: mine.y });
  return out;
}

export const removeUnit = (formation: FormationSlot[], unitId: string): FormationSlot[] =>
  formation.filter((s) => s.unitId !== unitId);

function centreOutColumns(cols: number): number[] {
  const mid = (cols - 1) / 2;
  return Array.from({ length: cols }, (_, i) => i).sort((a, b) => Math.abs(a - mid) - Math.abs(b - mid) || a - b);
}

/** First free cell scanning the front row (closest to the enemy) first. */
export function firstFreeSlot(
  grid: GridConfig,
  side: Side,
  occupied: { x: number; y: number }[],
): { x: number; y: number } | null {
  const { minY, maxY } = sideRows(grid, side);
  const ys: number[] = [];
  if (side === "player") for (let y = minY; y <= maxY; y++) ys.push(y);
  else for (let y = maxY; y >= minY; y--) ys.push(y);
  for (const y of ys)
    for (const x of centreOutColumns(grid.cols)) if (!occupied.some((o) => o.x === x && o.y === y)) return { x, y };
  return null;
}

/** Auto-formation by role: short-range/sturdy in front, long-range behind. */
export function autoFormation(
  grid: GridConfig,
  side: Side,
  units: { id: string; range: number; hp: number }[],
): FormationSlot[] {
  const { minY, maxY } = sideRows(grid, side);
  const front = side === "player" ? minY : maxY;
  const back = side === "player" ? maxY : minY;
  const sorted = [...units].sort((a, b) => a.range - b.range || b.hp - a.hp);
  const cols = centreOutColumns(grid.cols);
  const frontCount = Math.ceil(sorted.length / 2);
  return sorted.map((u, i) => {
    const isFront = i < frontCount;
    const idx = isFront ? i : i - frontCount;
    return { unitId: u.id, x: cols[idx % cols.length], y: isFront ? front : back };
  });
}
