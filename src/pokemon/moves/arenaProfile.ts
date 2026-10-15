import {moveBehavior,isStreamMove,isAreaMove} from "./behavior";
export type MoveDelivery = "melee" | "ranged";
export const MELEE_REACH = 2;

export const isDashMove = (name:string) => /quick attack|extreme speed|aqua jet|volt tackle|flame charge|flare blitz|wild charge|head charge|take down/i.test(name);

/** Arena choreography follows the move, independently of Gen-3 damage category or species role. */
const CONTACT = /arm thrust|force palm|crabhammer|flame wheel|flare blitz|wild charge|iron tail|dragon tail|punch|kick|claw|fang|bite|tackle|scratch|pound|slap|chop|headbutt|slam|peck|whip|slash|leaf blade|\bcut\b|rollout|stomp|reversal|flail|take down|double.edge|rock smash|fury cutter|quick attack|extreme speed|wing attack|brave bird|brick break|cross chop|bug bite|x-scissor|megahorn|lick|shadow sneak|shadow force|pursuit|crunch|iron head|meteor mash|spark|body press|play rough|draining kiss/i;

export function arenaMoveProfile(name: string, fallbackRange = 4): {delivery: MoveDelivery; range: number} {
  if(isAreaMove(moveBehavior(name)))return {delivery:"ranged",range:6};
  if(moveBehavior(name)==="circle")return {delivery:"melee",range:3};
  if(/^(bone rush|bone club)$/i.test(name))return {delivery:"melee",range:MELEE_REACH};
  if(isStreamMove(moveBehavior(name)))return {delivery:"ranged",range:4};
  if (/^(fly|dig|dive|bounce|sky drop|phantom force|shadow force)$/i.test(name)) return {delivery:"ranged",range:6};
  if (/^(earthquake|bulldoze|magnitude|discharge|lava plume|sludge wave|boomburst)$/i.test(name)) return {delivery:"melee",range:3};
  if (/^(vine whip|power whip)$/i.test(name)) return {delivery:"melee",range:3};
  if (/mud[ -]?slap|air slash|psycho cut/i.test(name)) return {delivery: "ranged", range: 4};
  if (/^(aqua jet|flame charge|head charge|giga impact|liquidation|waterfall|wave crash|poison jab|assurance|astonish|branch poke|chip away|covet|dragon ascent|facade|feint attack|first impression|flip turn|foul play|glaive rush|grassy glide|head smash|headlong rush|high horsepower|knock off|lash out|leech life|low sweep|outrage|pluck|pounce|razor shell|retaliate|sacred sword|skitter smack|skull bash|steel roller|steel wing|stomping tantrum|sucker punch|supercell slam|superpower|temper flare|thief|thrash|throat chop|trailblaze|u-turn|upper hand|vise grip|wicked blow|wood hammer)$/i.test(name) || CONTACT.test(name)) return {delivery: "melee", range: MELEE_REACH};
  // An unknown imported move keeps its explicit range; known projectiles need no species restriction.
  const projectile = /beam|ball|bolt|blast|burst|gun|pump|surf|wave|voice|breath|pulse|throw|slide|shard|shuriken|leaf|wind|snow|blizzard|thunder|ember|confusion|psychic|absorb|drain|earthquake|bulldoze|precipice|power gem|stone edge|future sight|sludge|sting|flamethrower|frenzy plant/i;
  if (projectile.test(name)) return {delivery: "ranged", range: 4};
  return {delivery: fallbackRange <= 2 ? "melee" : "ranged", range: fallbackRange <= 2 ? MELEE_REACH : fallbackRange};
}
