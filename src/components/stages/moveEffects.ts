import {isConeMove,isAreaMove,areaMoveProfile,moveVisual,projectileRadius,type MoveBehavior} from "@/pokemon/moves/behavior";
import {blockedPoint,type Obstacle} from "@/battle/field";
export interface MoveEffect {from:{x:number;y:number};to:{x:number;y:number};color:string;behavior?:MoveBehavior;radius?:number;travel?:number;moveName?:string;kind?:string}
/** Coordinates use the same 650×350 field projection as authoritative hit tests. */
export function drawMoveEffect(ctx:CanvasRenderingContext2D,fx:MoveEffect,age:number,reduced:boolean,obstacles?:readonly Obstacle[]):boolean {
  const behavior=fx.behavior;
  const visual=moveVisual(fx.moveName??"");
  const dx=fx.to.x-fx.from.x,dy=fx.to.y-fx.from.y;
  if(behavior&&isAreaMove(behavior)){
    const profile=areaMoveProfile(behavior),active=age>=profile.windup;
    const rx=(fx.radius??profile.radius)*650/17,ry=(fx.radius??profile.radius)*350/11;
    ctx.save();ctx.globalAlpha=1;ctx.translate(fx.to.x,fx.to.y);
    ctx.strokeStyle=active?fx.color:"#fff7cb";ctx.fillStyle=fx.color;ctx.lineWidth=2;
    ctx.globalAlpha=active?.16:.08;ctx.beginPath();ctx.ellipse(0,0,rx,ry,0,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;
    ctx.setLineDash(active?[]:[5,4]);ctx.beginPath();ctx.ellipse(0,0,rx,ry,0,0,Math.PI*2);ctx.stroke();ctx.setLineDash([]);
    if(!active){ctx.font="bold 11px monospace";ctx.textAlign="center";ctx.fillStyle="#fff7cb";ctx.strokeStyle="#243d38";ctx.lineWidth=3;const label=behavior==="meteors"?"METEORS":"TWISTER";ctx.strokeText(label,0,-ry-8);ctx.fillText(label,0,-ry-8);}
    if(behavior==="vortex"&&active){
      for(let i=0;i<8;i++){
        const progress=i/8,phase=reduced?i:age*.012+i*.85;
        const width=rx*(.2+progress*.65),x=Math.sin(phase)*rx*.12;
        ctx.strokeStyle=i%2?"#e5faff":fx.color;ctx.lineWidth=i%2?2:4;
        ctx.beginPath();ctx.ellipse(x,-progress*60,width,ry*(.12+progress*.16),Math.sin(phase)*.15,0,Math.PI*2);ctx.stroke();
      }
    }
    if(behavior==="meteors")for(let i=0;i<profile.pulses;i++){
      const impact=profile.windup+i*profile.duration/profile.pulses;
      const t=(age-impact+220)/220;
      const angle=i*2.4,spread=i===0?0:.55;
      const x=Math.cos(angle)*rx*spread,y=Math.sin(angle)*ry*spread;
      if(t>=0&&t<1&&!reduced){
        const mx=x-(1-t)*65,my=y-(1-t)*125;
        ctx.strokeStyle="#f0a45b";ctx.lineWidth=7;ctx.beginPath();ctx.moveTo(mx-15,my-30);ctx.lineTo(mx,my);ctx.stroke();
        ctx.fillStyle="#785e9c";ctx.beginPath();ctx.arc(mx,my,9,0,Math.PI*2);ctx.fill();ctx.strokeStyle="#fff0a0";ctx.lineWidth=2;ctx.stroke();
      }
      if(t>=1&&t<2.2){
        const burst=(t-1)/1.2;ctx.globalAlpha=1-burst;ctx.strokeStyle="#fff0b4";ctx.lineWidth=3;
        ctx.beginPath();ctx.ellipse(x,y,8+burst*22,5+burst*14,0,0,Math.PI*2);ctx.stroke();
        ctx.fillStyle=fx.color;ctx.beginPath();ctx.arc(x,y,reduced?7:10*(1-burst),0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;
      }
    }
    ctx.restore();return true;
  }
  if(["sphere","bullet","bone","punch","kick","charge"].includes(visual)){
    const angle=Math.atan2(dy,dx),t=Math.min(1,Math.max(0,(age-180)/Math.max(1,(fx.travel??450)-180)));
    ctx.save();ctx.fillStyle=fx.color;ctx.strokeStyle=fx.color;ctx.lineWidth=3;
    if((visual==="sphere"||visual==="bullet")&&fx.kind!=="melee"){
      const x=fx.from.x+dx*t,y=fx.from.y+dy*t,r=projectileRadius(fx.moveName??"")*650/17;
      ctx.translate(x,y);ctx.beginPath();ctx.arc(0,0,r,0,Math.PI*2);ctx.fill();
      ctx.strokeStyle="#f3fdff";ctx.lineWidth=2;
      if(visual==="sphere")for(let i=0;i<3;i++){ctx.save();ctx.rotate((reduced?0:age*.012)+i*Math.PI/3);ctx.beginPath();ctx.ellipse(0,0,r*.95,r*.4,0,0,Math.PI*2);ctx.stroke();ctx.restore();}
      ctx.fillStyle="#fff";ctx.beginPath();ctx.arc(-r*.2,-r*.2,r*.3,0,Math.PI*2);ctx.fill();
      if(visual==="sphere"&&!reduced){ctx.strokeStyle=fx.color;ctx.globalAlpha=.5;for(let i=0;i<3;i++){ctx.beginPath();ctx.arc(-Math.cos(angle)*i*12,-Math.sin(angle)*i*12,r*(1-i*.2),0,Math.PI*2);ctx.stroke();}}
    }else if(visual==="bone"){
      ctx.translate(fx.from.x+Math.cos(angle)*24,fx.from.y+Math.sin(angle)*24);ctx.rotate(angle+(reduced?0:Math.sin(age*.025)*1.2));
      ctx.strokeStyle="#64543c";ctx.lineWidth=10;ctx.beginPath();ctx.moveTo(-23,0);ctx.lineTo(23,0);ctx.stroke();ctx.strokeStyle="#fff0c6";ctx.lineWidth=6;ctx.stroke();
      for(const x of [-24,24])for(const y of [-4,4]){ctx.fillStyle="#fff0c6";ctx.beginPath();ctx.arc(x,y,6,0,Math.PI*2);ctx.fill();ctx.strokeStyle="#64543c";ctx.lineWidth=1;ctx.stroke();}
    }else{
      const reach=reduced?35:22+Math.sin(Math.min(1,age/450)*Math.PI)*35;
      ctx.translate(fx.from.x,fx.from.y);ctx.rotate(angle);
      ctx.globalAlpha=.5;ctx.lineWidth=visual==="charge"?18:10;ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(reach,0);ctx.stroke();ctx.globalAlpha=1;
      if(visual==="punch"){ctx.fillRect(reach-10,-10,21,20);ctx.strokeStyle="#fff7cd";ctx.lineWidth=2;ctx.strokeRect(reach-10,-10,21,20);for(let i=0;i<3;i++)ctx.fillRect(reach-8+i*6,-15,5,8);}
      else if(visual==="kick"){ctx.strokeStyle="#fff1c8";ctx.lineWidth=6;ctx.beginPath();ctx.moveTo(0,8);ctx.lineTo(reach,-6);ctx.lineTo(reach+12,2);ctx.stroke();}
      for(let i=0;i<7;i++){const a=i*Math.PI*2/7+(reduced?0:age*.015);ctx.beginPath();ctx.moveTo(reach+Math.cos(a)*13,Math.sin(a)*13);ctx.lineTo(reach+Math.cos(a)*25,Math.sin(a)*25);ctx.stroke();}
      if(visual==="kick"||visual==="charge"){ctx.strokeStyle=fx.color;ctx.lineWidth=4;for(let i=0;i<3;i++){ctx.beginPath();ctx.arc(reach*.5,0,16+i*7,(reduced?0:age*.02)+i,Math.PI+(reduced?0:age*.02)+i);ctx.stroke();}}
    }
    ctx.restore();return true;
  }
  if(!behavior||behavior==="melee"||behavior==="projectile")return false;
  ctx.save();ctx.strokeStyle=fx.color;ctx.fillStyle=fx.color;ctx.lineWidth=3;
  if(["fly","dig","dive","vanish"].includes(behavior)){
    if(age<2000){ctx.restore();return true;}
    const landed=age>=2000,t=Math.min(1,Math.max(0,(age-2000)/350));
    ctx.globalAlpha=landed?1-t:.7;
    ctx.setLineDash(landed?[]:[6,5]);ctx.beginPath();ctx.ellipse(fx.to.x,fx.to.y,(fx.radius??1.8)*650/17,(fx.radius??1.8)*350/11,0,0,Math.PI*2);ctx.stroke();
    ctx.setLineDash([]);
    if(landed){ctx.lineWidth=5;ctx.beginPath();ctx.ellipse(fx.to.x,fx.to.y,10+t*65,7+t*52,0,0,Math.PI*2);ctx.stroke();}
    else {ctx.font="bold 12px monospace";ctx.textAlign="center";ctx.fillText(behavior.toUpperCase(),fx.to.x,fx.to.y-12);}
  }else if(behavior==="circle"){
    const t=reduced?1:Math.min(1,age/450),rx=(fx.radius??3)*650/17,ry=(fx.radius??3)*350/11;
    ctx.globalAlpha=.2;ctx.beginPath();ctx.ellipse(fx.from.x,fx.from.y,rx,ry,0,0,Math.PI*2);ctx.fill();ctx.globalAlpha=1;
    for(let i=0;i<3;i++){const scale=reduced?1:Math.min(1,Math.max(.1,t-i*.16));ctx.beginPath();ctx.ellipse(fx.from.x,fx.from.y,rx*scale,ry*scale,0,0,Math.PI*2);ctx.stroke();}
    for(let i=0;i<8;i++){const a=i*Math.PI/4;ctx.beginPath();ctx.moveTo(fx.from.x+Math.cos(a)*rx*.25,fx.from.y+Math.sin(a)*ry*.25);ctx.lineTo(fx.from.x+Math.cos(a)*rx*.8,fx.from.y+Math.sin(a)*ry*.8);ctx.stroke();}
  }else if(behavior==="beam"){
    const length=Math.hypot(dx/(650/17),dy/(350/11))||1,nx=-(dy/(350/11))/length*.45*650/17,ny=(dx/(650/17))/length*.45*350/11;
    ctx.globalAlpha=.35;ctx.beginPath();ctx.moveTo(fx.from.x+nx,fx.from.y+ny);ctx.lineTo(fx.to.x+nx,fx.to.y+ny);ctx.lineTo(fx.to.x-nx,fx.to.y-ny);ctx.lineTo(fx.from.x-nx,fx.from.y-ny);ctx.closePath();ctx.fill();
    ctx.globalAlpha=1;ctx.lineWidth=7;ctx.beginPath();ctx.moveTo(fx.from.x,fx.from.y);ctx.lineTo(fx.to.x,fx.to.y);ctx.stroke();ctx.strokeStyle="#effcff";ctx.lineWidth=2;ctx.stroke();
    if(/thunder|zap|electro/i.test(fx.moveName??"")){
      ctx.strokeStyle="#fff6ad";ctx.lineWidth=3;
      for(let bolt=0;bolt<3;bolt++){ctx.beginPath();for(let i=0;i<=20;i++){const p=i/20,jitter=i===0||i===20?0:Math.sin(i*7+bolt*3+(reduced?0:age*.035))*11;const x=fx.from.x+dx*p+nx/17*jitter,y=fx.from.y+dy*p+ny/17*jitter;if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);}ctx.stroke();}
    }
  }else if(isConeMove(behavior)){
    // A 60-degree cone in grid space, matching the simulation's dot-product check.
    const gx=dx/(650/17),gy=dy/(350/11),angle=Math.atan2(gy,gx),range=Math.hypot(gx,gy);
    ctx.globalAlpha=.6;ctx.beginPath();ctx.moveTo(fx.from.x,fx.from.y);
    for(let i=0;i<=12;i++){const a=angle-Math.PI/6+i*Math.PI/36;let length=range;for(let d=.1;d<=range;d+=.1){if(blockedPoint(obstacles,(fx.from.x-35)/650*17+Math.cos(a)*d,(fx.from.y-35)/350*11+Math.sin(a)*d,.08)){length=d-.1;break;}}ctx.lineTo(fx.from.x+Math.cos(a)*length*650/17,fx.from.y+Math.sin(a)*length*350/11);}ctx.closePath();ctx.fill();ctx.clip();
    ctx.globalAlpha=1;
    if(behavior==="water"){
      ctx.strokeStyle="#e2faff";ctx.lineWidth=3;
      for(let i=0;i<5;i++){const a=angle+(i-2)*.14;ctx.beginPath();ctx.moveTo(fx.from.x,fx.from.y);ctx.lineTo(fx.from.x+Math.cos(a)*range*650/17,fx.from.y+Math.sin(a)*range*350/11);ctx.stroke();}
    }
    for(let i=0;i<15;i++){const p=(i+1)/16,spread=Math.sin(i*2.4+(reduced?0:age*.025))*.15;const a=angle+spread;ctx.fillStyle=i%2?(behavior==="flame"?"#fff0a0":"#e8fcff"):fx.color;ctx.beginPath();ctx.ellipse(fx.from.x+Math.cos(a)*range*p*650/17,fx.from.y+Math.sin(a)*range*p*350/11,behavior==="wind"?12:5+p*10,behavior==="wind"?2:4+p*6,a,0,Math.PI*2);ctx.fill();}
    if(/blizzard|icy wind|frost breath/i.test(fx.moveName??"")){
      ctx.strokeStyle="#f2ffff";ctx.lineWidth=2;
      for(let i=0;i<18;i++){const p=reduced?(i+1)/19:((i/18+age*.0007)%1),a=angle+Math.sin(i*2.7)*.45,x=fx.from.x+Math.cos(a)*range*p*650/17,y=fx.from.y+Math.sin(a)*range*p*350/11;for(let j=0;j<3;j++){const b=j*Math.PI/3;ctx.beginPath();ctx.moveTo(x-Math.cos(b)*5,y-Math.sin(b)*5);ctx.lineTo(x+Math.cos(b)*5,y+Math.sin(b)*5);ctx.stroke();}}
    }
  }else if(behavior==="whip"){
    const t=reduced?1:Math.sin(Math.min(1,age/450)*Math.PI),x=fx.from.x+dx*t,y=fx.from.y+dy*t;
    ctx.strokeStyle="#397a38";ctx.lineWidth=6;ctx.beginPath();ctx.moveTo(fx.from.x,fx.from.y);ctx.quadraticCurveTo(fx.from.x+dx*.5-dy*.15,fx.from.y+dy*.5+dx*.15,x,y);ctx.stroke();ctx.strokeStyle="#a8df70";ctx.lineWidth=2;ctx.stroke();
  }else if(behavior==="sleep"||behavior==="bind"){
    const t=Math.min(1,Math.max(0,(age-180)/Math.max(1,(fx.travel??450)-180))),x=fx.from.x+dx*t,y=fx.from.y+dy*t;
    ctx.strokeStyle=behavior==="sleep"?"#bba5eb":"#5f9b52";
    for(let i=0;i<3;i++){ctx.beginPath();ctx.ellipse(x-i*7,y+i*4,12+i*3,7+i*2,0,0,Math.PI*2);ctx.stroke();}
    if(behavior==="sleep"){ctx.font="bold 14px monospace";ctx.fillStyle="#eee3ff";ctx.fillText("Z",x,y);}
  }
  ctx.restore();return true;
}
