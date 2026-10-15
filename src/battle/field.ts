export const ARENA_GRID = {cols:18,rowsPerSide:5,gapRows:2};
export const ARENA_OBSTACLES = [
  {x:5,y:3,w:1.5,h:2},{x:11.5,y:6,w:1.5,h:2},
  {x:8,y:1.5,w:2,h:1},{x:7,y:8.5,w:2,h:1},
];
export type Obstacle = typeof ARENA_OBSTACLES[number];
export function blockedPoint(obstacles:readonly Obstacle[]|undefined,x:number,y:number,pad=.32) {
  return (obstacles??[]).some(o=>x>o.x-pad&&x<o.x+o.w+pad&&y>o.y-pad&&y<o.y+o.h+pad);
}
/** Sample the whole path, so fast dashes cannot tunnel through cover. */
export function blockedLine(obstacles:readonly Obstacle[]|undefined,a:{x:number;y:number},b:{x:number;y:number},pad=0) {
  const steps=Math.max(1,Math.ceil(Math.hypot(b.x-a.x,b.y-a.y)*20));
  for(let i=0;i<=steps;i++)if(blockedPoint(obstacles,a.x+(b.x-a.x)*i/steps,a.y+(b.y-a.y)*i/steps,pad))return true;
  return false;
}
