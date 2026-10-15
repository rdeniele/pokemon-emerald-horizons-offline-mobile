export interface BattleCamera {x:number;y:number;zoom:number}
export interface CameraPoint {x:number;y:number}
export const FULL_ARENA_CAMERA:BattleCamera={x:360,y:210,zoom:1};
const clamp=(n:number,min:number,max:number)=>Math.max(min,Math.min(max,n));

/** Gentle render-only framing: cap zoom at 1.2× and widen when fighters spread out. */
export function followBattleCamera(current:BattleCamera,points:readonly CameraPoint[],dt:number,reduced=false):BattleCamera{
  if(reduced||!points.length)return {...FULL_ARENA_CAMERA};
  const left=clamp(Math.min(...points.map(p=>p.x))-70,0,720);
  const right=clamp(Math.max(...points.map(p=>p.x))+70,0,720);
  const top=clamp(Math.min(...points.map(p=>p.y))-85,0,420);
  const bottom=clamp(Math.max(...points.map(p=>p.y))+55,0,420);
  const fit=Math.min(1.2,720/Math.max(1,right-left),420/Math.max(1,bottom-top));
  const targetZoom=Math.max(1,fit),step=Math.max(0,Math.min(.1,dt));
  // Ease in both directions; the inner safety frame can override lag on a fast dodge.
  const safeLeft=clamp(Math.min(...points.map(p=>p.x))-50,0,720),safeRight=clamp(Math.max(...points.map(p=>p.x))+50,0,720);
  const safeTop=clamp(Math.min(...points.map(p=>p.y))-75,0,420),safeBottom=clamp(Math.max(...points.map(p=>p.y))+45,0,420);
  const safeFit=Math.min(1.2,720/Math.max(1,safeRight-safeLeft),420/Math.max(1,safeBottom-safeTop));
  const zoom=Math.max(1,Math.min(safeFit,current.zoom+(targetZoom-current.zoom)*(1-Math.exp(-step*(targetZoom<current.zoom?8:4)))));
  const halfW=360/zoom,halfH=210/zoom,alpha=1-Math.exp(-step*7);
  const x=current.x+((left+right)/2-current.x)*alpha;
  const y=current.y+((top+bottom)/2-current.y)*alpha;
  return {zoom,
    x:clamp(x,Math.max(halfW,safeRight-halfW),Math.min(720-halfW,safeLeft+halfW)),
    y:clamp(y,Math.max(halfH,safeBottom-halfH),Math.min(420-halfH,safeTop+halfH))};
}
export function cameraToWorld(camera:BattleCamera,screen:CameraPoint):CameraPoint{
  return {x:camera.x+(screen.x-360)/camera.zoom,y:camera.y+(screen.y-210)/camera.zoom};
}
