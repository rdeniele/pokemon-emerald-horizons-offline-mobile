import Image from "next/image";
import {getEmpressSprite} from "@/pokemon/sprites/resolver";
import type {BattleUnit} from "@/battle/types";

/** Roster order matches the number keys used to switch Pokémon. */
export default function BattleParty({units,label,onSwitch}:{units:BattleUnit[];label:string;onSwitch?:(id:string)=>void}){
  return <div className="battle-party" role="group" aria-label={label}>{units.map((unit,index)=>{
    const status=!unit.alive?"Fainted":unit.deployed?"Active":"Alive";
    const description=`${index+1}: ${unit.spec.name} · ${status} · ${unit.hp}/${unit.maxHp} HP`;
    const className=`party-portrait${!unit.alive?" is-fainted":""}${unit.alive&&unit.deployed?" is-active":""}`;
    const portrait=<><Image unoptimized src={getEmpressSprite(unit.spec.speciesId)} alt="" width={26} height={26}/><span aria-hidden="true">{index+1}</span></>;
    return onSwitch?<button key={unit.spec.id} className={className} title={description} aria-label={description} aria-current={unit.alive&&unit.deployed?"true":undefined} disabled={!unit.alive||unit.deployed} onClick={()=>onSwitch(unit.spec.id)}>{portrait}</button>:<span key={unit.spec.id} className={className} title={description} aria-label={description} role="img">{portrait}</span>;
  })}</div>;
}
