import fs from 'node:fs';
import path from 'node:path';
const root=process.argv[2]||'D:/work/acqron/pokemon-emerald-horizons/third-party/pokeemerald';
const walk=d=>fs.readdirSync(d,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(d,e.name)):[path.join(d,e.name)]);
const constants={TRUE:1,FALSE:0};
const expressions=[];
for(const file of walk(path.join(root,'include/constants')).filter(f=>f.endsWith('.h'))){
 const source=fs.readFileSync(file,'utf8');
 for(const m of source.matchAll(/^\s*#define\s+(\w+)\s+([^\r\n]+)/gm))if(!m[2].startsWith('(')||!m[2].includes('...'))expressions.push([m[1],m[2].split('//')[0].trim()]);
}
for(let pass=0;pass<12;pass++)for(const [name,raw]of expressions){
 let exp=raw.replace(/\/\*.*?\*\//g,'').replace(/\b(0x[\da-f]+|\d+)[uUlL]+\b/gi,'$1').replace(/\b[A-Za-z_]\w*\b/g,x=>Object.hasOwn(constants,x)?String(constants[x]):x);
 if(/^[\d\sa-fx()+*/%<>&|~^-]+$/i.test(exp))try{const n=Function(`"use strict";return (${exp})`)();if(Number.isFinite(n))constants[name]=n;}catch{}
}
const instructions=[],labels={},texts={},movements={},sources={},shops={};
const files=walk(path.join(root,'data')).filter(f=>/\.(inc|s)$/.test(f)&&(/[/\\]maps[/\\].*scripts\.inc$/.test(f)||/[/\\](scripts|text|maps)[/\\]/.test(f)||/event_scripts\.s$/.test(f)));
for(const file of files){
 let current=null;
 for(const raw of fs.readFileSync(file,'utf8').split(/\r?\n/)){
  const line=raw.replace(/\s+@.*$/,'').trim();if(!line||line.startsWith('@')||line.startsWith('#'))continue;
  const label=line.match(/^([\w.]+)::?\s*$/);if(label){current=label[1];labels[current]=instructions.length;sources[current]=path.relative(root,file).replaceAll('\\','/');continue;}
  if(line.startsWith('.string')){const m=line.match(/"(.*)"/);if(m&&current)texts[current]=(texts[current]||'')+m[1].replace(/\\n/g,'\n').replace(/\\[pl]/g,'\n\n').replace(/\$$/,'');continue;}
  const stock=line.match(/^\.(?:2byte|hword)\s+(ITEM_\w+)$/);if(stock&&current){if(stock[1]!=='ITEM_NONE')(shops[current]??=[]).push(stock[1]);continue;}
  if(line.startsWith('.')&&!line.startsWith('.4byte'))continue;
  const m=line.match(/^([\w.]+)(?:\s+(.*))?$/);if(!m)continue;
  const args=(m[2]||'').split(/,(?=(?:[^"]*"[^"]*")*[^"]*$)/).map(s=>s.trim()).filter(Boolean);
  instructions.push({op:m[1],args});
 }
 // Prevent accidental fallthrough into a different assembly unit.
 instructions.push({op:'end',args:[]});
}
for(const[label,pc]of Object.entries(labels))if(/Movement/.test(label)){const list=[];for(let p=pc;p<instructions.length;p++){const i=instructions[p];list.push(i);if(['step_end','end'].includes(i.op))break;}movements[label]=list;}
const parties={};const partyText=fs.readFileSync(path.join(root,'src/data/trainer_parties.h'),'utf8');
for(const m of partyText.matchAll(/\b(sParty_\w+)\[\]\s*=\s*\{([\s\S]*?)\n\};/g))parties[m[1]]=[...m[2].matchAll(/\.lvl\s*=\s*(\d+),\s*\.species\s*=\s*(SPECIES_\w+)/g)].map(x=>({level:+x[1],species:x[2]}));
const trainers={};const trainerText=fs.readFileSync(path.join(root,'src/data/trainers.h'),'utf8');
const moneySource=fs.readFileSync(path.join(root,'src/battle_main.c'),'utf8').split('gTrainerMoneyTable[]')[1].split('};')[0];
const trainerMoney=Object.fromEntries([...moneySource.matchAll(/\{(TRAINER_CLASS_\w+),\s*(\d+)\}/g)].map(m=>[m[1],+m[2]]));
for(const m of trainerText.matchAll(/\[(TRAINER_\w+)\]\s*=\s*\{([\s\S]*?)\n    \},/g)){const party=m[2].match(/(?:MOVES|Moves)\((sParty_\w+)\)/);const team=parties[party?.[1]]||[],trainerClass=m[2].match(/\.trainerClass\s*=\s*(TRAINER_CLASS_\w+)/)?.[1],doubleBattle=/\.doubleBattle\s*=\s*TRUE/.test(m[2]);trainers[m[1]]={name:m[2].match(/\.trainerName\s*=\s*_\("([^"]*)"\)/)?.[1]||m[1],team,trainerClass,doubleBattle,rewardMoney:4*(team.at(-1)?.level||0)*(trainerMoney[trainerClass]||0)*(doubleBattle?2:1)};}
const speciesNational={};let dex=0;const pokedex=fs.readFileSync(path.join(root,'include/constants/pokedex.h'),'utf8').split('NATIONAL_DEX_COUNT')[0];
for(const m of pokedex.matchAll(/^\s*NATIONAL_DEX_(\w+)(?:\s*=\s*(\d+))?,/gm)){if(m[2])dex=+m[2];speciesNational[`SPECIES_${m[1]}`]=dex++;}
const wildEncounters=JSON.parse(fs.readFileSync(path.join(root,'src/data/wild_encounters.json'),'utf8')).wild_encounter_groups.filter(g=>g.for_maps).flatMap(g=>g.encounters);
const healLocations=JSON.parse(fs.readFileSync(path.join(root,'src/data/heal_locations.json'),'utf8')).heal_locations;
const stdScripts=[];const stdSource=fs.readFileSync(path.join(root,'data/event_scripts.s'),'utf8').split('gStdScripts::')[1].split('gStdScripts_End::')[0];
for(const match of stdSource.matchAll(/\.4byte\s+(\w+)\s+@\s+(\w+)/g)){constants[match[2]]=stdScripts.length;stdScripts.push(match[1]);}
const stringsSource=fs.readFileSync(path.join(root,'src/strings.c'),'utf8');
for(const match of stringsSource.matchAll(/\b(gText_\w+)\[\]\s*=\s*_\("((?:[^"\\]|\\.)*)"\)/g))texts[match[1]]=match[2].replace(/\\n/g,'\n').replace(/\\[pl]/g,'\n\n').replace(/\$$/,'');
const menuSource=fs.readFileSync(path.join(root,'src/data/script_menu.h'),'utf8'),choiceLists={};
for(const match of menuSource.matchAll(/\b(MultichoiceList_\w+)\[\]\s*=\s*\{([\s\S]*?)\n\};/g))choiceLists[match[1]]=[...match[2].matchAll(/\{\s*(\w+)\s*[,}]/g)].map(m=>texts[m[1]]??m[1]);
const choices={};for(const match of menuSource.matchAll(/\[(MULTI_\w+)\]\s*=\s*MULTICHOICE\((\w+)\)/g))choices[match[1]]=choiceLists[match[2]]||[];
const output={provenance:'pret/pokeemerald event scripts; generated from local reference source',instructions,labels,texts,movements,constants,trainers,shops,choices,sources,speciesNational,wildEncounters,healLocations,stdScripts};
fs.writeFileSync('src/data/emerald-events.generated.json',JSON.stringify(output));
console.log(JSON.stringify({files:files.length,labels:Object.keys(labels).length,texts:Object.keys(texts).length,instructions:instructions.length,constants:Object.keys(constants).length,trainers:Object.keys(trainers).length}));
