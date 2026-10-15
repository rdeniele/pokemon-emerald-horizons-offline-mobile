/** Shared by simulation and renderer: visual shape must describe the real hit test. */
export type MoveBehavior = "projectile"|"melee"|"circle"|"flame"|"water"|"wind"|"beam"|"whip"|"fly"|"dig"|"dive"|"vanish"|"sleep"|"bind"|"vortex"|"meteors";
export function moveBehavior(name:string):MoveBehavior {
  const n=name.toLowerCase().replaceAll("-"," ");
  if(n==="twister")return "vortex";
  if(n==="draco meteor"||n==="dracometeor")return "meteors";
  if(/^(fly|bounce|sky drop)$/.test(n))return "fly";
  if(n==="dig")return "dig";
  if(n==="dive")return "dive";
  if(/^(phantom force|shadow force)$/.test(n))return "vanish";
  if(/^(earthquake|bulldoze|magnitude|discharge|lava plume|sludge wave|boomburst|self destruct|explosion|rapid spin|brutal swing|darkest lariat|dazzling gleam|misty explosion|petal dance)$/.test(n))return "circle";
  if(/^(water gun|hydro pump|hydro cannon|scald|water spout|chilling water|brine|bubble beam)$/.test(n))return "water";
  if(/^(thunderbolt|thunder|zap cannon|electro shot|ice beam|aurora beam|solar beam|hyper beam|charge beam|psybeam|flash cannon|steel beam|meteor beam|signal beam|power gem|light of ruin)$/.test(n))return "beam";
  if(/^(icy wind|frost breath|blizzard|gust|fairy wind|ominous wind|hurricane|leaf storm|leaf tornado|snarl|bug buzz|round|echoed voice|disarming voice|alluring voice|psychic noise)$/.test(n))return "wind";
  if(/^(flamethrower|dragon breath|incinerate|heat wave)$/.test(n))return "flame";
  if(/^(vine whip|power whip)$/.test(n))return "whip";
  if(/^(sleep powder|spore|hypnosis|sing|lovely kiss|yawn|dark void|grass whistle)$/.test(n))return "sleep";
  if(/^(bind|wrap|constrict|infestation|thousand waves|mean look|spider web|block)$/.test(n))return "bind";
  return "projectile";
}
export const isTravelMove=(kind:MoveBehavior)=>["fly","dig","dive","vanish"].includes(kind);
export const isConeMove=(kind:MoveBehavior)=>["flame","water","wind"].includes(kind);
export const isStreamMove=(kind:MoveBehavior)=>isConeMove(kind)||kind==="beam";
export const isAreaMove=(kind:MoveBehavior)=>kind==="vortex"||kind==="meteors";
/** Shared timing and footprint for ground-targeted area attacks. */
export const areaMoveProfile=(kind:MoveBehavior)=>kind==="meteors"
  ?{radius:2.2,windup:650,duration:1500,pulses:5}
  :{radius:1.4,windup:350,duration:1200,pulses:3};
export const STREAM_DURATION=1200;
export const STREAM_CLASH_DURATION=1400;
export type MoveVisual="default"|"sphere"|"bullet"|"bone"|"punch"|"kick"|"charge";
export function moveVisual(name:string):MoveVisual {
  const n=name.toLowerCase().replaceAll("-"," ");
  if(/^(bone rush|bone club)$/.test(n))return "bone";
  if(/punch|meteor mash|hammer arm|arm thrust|force palm/.test(n))return "punch";
  if(/kick/.test(n))return "kick";
  if(/sphere|ball|focus blast/.test(n))return "sphere";
  if(/bullet|missile|shard|shuriken|sting|needle|water pulse/.test(n))return "bullet";
  if(/flare blitz|flame charge|volt tackle|wild charge/.test(n))return "charge";
  return "default";
}
export const projectileRadius=(name:string)=>moveVisual(name)==="sphere"?.55:moveVisual(name)==="bullet"?.1:.18;
export function moveBehaviorLabel(name:string):string|undefined {
  const behavior=moveBehavior(name);
  if(isTravelMove(behavior))return `${behavior} · 2s → area`;
  return ({circle:"circle AoE",flame:"sustained flame",water:"sustained water",wind:"sustained wave",beam:"sustained beam",whip:"aimed whip",sleep:"ranged sleep",bind:"binding hit",vortex:"aimed vortex AoE",meteors:"meteor shower AoE"} as Partial<Record<MoveBehavior,string>>)[behavior];
}
