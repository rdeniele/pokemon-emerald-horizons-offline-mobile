import data from "@/data/pokemon/arena-kits.generated.json";
import type {Skill,StatusApplication,UnitSpec} from "@/battle/types";
import type {PokemonType} from "../types/typeChart";
import {arenaMoveProfile} from "./arenaProfile";
interface Entry {slug:string;name:string;type:string;category:string;kind:string;buff?:string;status?:StatusApplication}
const kits=data.kits as unknown as Record<string,Entry[]>;
/** Every roster entry is checked against a bundled learnset during import and in tests. */
export function applyArenaKit(unit:UnitSpec):void {
  const kit=kits[unit.speciesId];if(!kit)throw Error(`Missing arena moves for ${unit.speciesId}`);
  const [q,e,r,x]=kit;
  unit.basic={name:q.name,type:q.type as PokemonType,category:q.category as "physical"|"special",power:40};
  unit.attackRange=arenaMoveProfile(q.name).range;
  unit.skills=[e,r,x].map((m,i):Skill=>({id:m.slug,name:m.name,slot:(["skill1","skill2","ultimate"] as const)[i],type:m.type as PokemonType,category:m.category as "physical"|"special",kind:m.kind as Skill["kind"],buff:m.buff as Skill["buff"],power:m.kind==="damage"?(i===2?100:60):0,cooldown:i===0?3:8,range:m.kind==="buff"?99:arenaMoveProfile(m.name).range,aoeRadius:/earthquake|surf|discharge|heat wave|blizzard|sludge wave|hyper voice/i.test(m.name)?1.4:0,targetStrategy:"nearest",status:m.status}));
}
