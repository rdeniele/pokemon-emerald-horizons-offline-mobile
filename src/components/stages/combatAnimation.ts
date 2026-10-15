import manifest from "@/data/pokemon/empress-animation.generated.json";
export interface AnimationSheet {src:string;frameWidth:number;frameHeight:number;frames:number;durations:number[];fps:number;directions:number;anchors?:number[][][]}
export type AnimationState="idle"|"walk"|"attack"|"special"|"shoot"|"hurt"|"charge"|"sleep";
export const combatAnimations=manifest as unknown as Record<string,Partial<Record<AnimationState,AnimationSheet>>>;
// Authored row order: Down, DownRight, Right, UpRight, Up, UpLeft, Left, DownLeft.
export function animationDirection(dx:number,dy:number):number {
  return ((Math.round(Math.atan2(dx,dy)/(Math.PI/4))%8)+8)%8;
}
export function animationFrame(sheet:AnimationSheet,age:number,loop:boolean):number {
  const durations=Array.from({length:sheet.frames},(_,i)=>Math.max(1,sheet.durations[i]??6));
  const total=durations.reduce((a,b)=>a+b,0);
  let ticks=Math.max(0,age)*sheet.fps/1000;
  ticks=loop?ticks%total:Math.min(ticks,total-0.001);
  for(let i=0;i<durations.length;i++){ticks-=durations[i];if(ticks<0)return i;}
  return sheet.frames-1;
}
/** Pin each frame's authored foot anchor to the fighter position. */
export function drawCombatAnimation(ctx:CanvasRenderingContext2D,image:HTMLImageElement,sheet:AnimationSheet,age:number,direction:number,x:number,y:number,loop:boolean,reduced:boolean):boolean {
  if(!image.complete||!image.naturalWidth)return false;
  const frame=animationFrame(sheet,reduced?0:age,loop),row=sheet.directions===1?0:direction;
  const anchor=sheet.anchors?.[row]?.[frame]??[sheet.frameWidth/2,sheet.frameHeight*.75];
  const scale=2;
  ctx.drawImage(image,frame*sheet.frameWidth,row*sheet.frameHeight,sheet.frameWidth,sheet.frameHeight,x-anchor[0]*scale,y+20-anchor[1]*scale,sheet.frameWidth*scale,sheet.frameHeight*scale);
  return true;
}
