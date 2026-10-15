/** Tiny helper for authoring tile maps in code (avoids hand-counting ASCII widths). */
export class Grid {
  private cells: string[][];
  constructor(
    readonly width: number,
    readonly height: number,
    fill = ".",
  ) {
    this.cells = Array.from({ length: height }, () => Array<string>(width).fill(fill));
  }
  set(x: number, y: number, ch: string): this {
    if (x >= 0 && y >= 0 && x < this.width && y < this.height) this.cells[y][x] = ch;
    return this;
  }
  rect(x: number, y: number, w: number, h: number, ch: string): this {
    for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) this.set(i, j, ch);
    return this;
  }
  border(ch: string): this {
    this.rect(0, 0, this.width, 1, ch).rect(0, this.height - 1, this.width, 1, ch);
    this.rect(0, 0, 1, this.height, ch).rect(this.width - 1, 0, 1, this.height, ch);
    return this;
  }
  /** 5x3 house; door at (x+2, y+2). */
  house(x: number, y: number): { doorX: number; doorY: number } {
    this.rect(x, y, 5, 1, "R").rect(x, y + 1, 5, 1, "r");
    "wkDkw".split("").forEach((c, i) => this.set(x + i, y + 2, c));
    return { doorX: x + 2, doorY: y + 2 };
  }
  rows(): string[] {
    return this.cells.map((r) => r.join(""));
  }
}
