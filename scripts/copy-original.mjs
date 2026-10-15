import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';
if(fs.existsSync('src/battle/engine/BattleEngine.ts'))throw Error('Adapted source already exists. Do not overwrite it by rerunning the initial source-copy operation.');
const source='D:/work/acqron/pokemon-emerald-horizons';const manifest=[];
function copy(relative,target=relative){const src=path.join(source,relative),dst=path.resolve(target);if(fs.statSync(src).isDirectory()){for(const entry of fs.readdirSync(src))copy(relative+'/'+entry,target+'/'+entry);}else{fs.mkdirSync(path.dirname(dst),{recursive:true});const bytes=fs.readFileSync(src);fs.writeFileSync(dst,bytes);manifest.push({source:relative,target,sha256:createHash('sha256').update(bytes).digest('hex')});}}
for(const d of ['src/battle','src/pokemon','src/data','src/assets'])copy(d);
for(const n of ['ArenaCanvas.tsx','BattleParty.tsx','BattleActions.tsx','KeyIcon.tsx','UiIcon.tsx','ControlGuide.tsx','Pager.tsx','battleCamera.ts','combatAnimation.ts','moveEffects.ts','stages.css'])copy('src/components/stages/'+n);
for(const n of ['audio.ts','trainerName.ts'])copy('src/game/'+n);
for(const n of ['layout.tsx','globals.css'])copy('src/app/'+n);
copy('src/multiplayer/protocol.ts','src/battle/viewProtocol.ts');
copy('src/components/stages/StageGame.tsx','docs/source/StageGame.original.tsx.txt');copy('src/components/HomeMenu.tsx','docs/source/HomeMenu.original.tsx.txt');copy('src/app/page.tsx','src/app/page.tsx');copy('src/game/stages.ts','docs/source/stages.original.ts.txt');
for(const n of ['arena-audio','empress','humble-paper','vryell','samy','pokemon','pret','fan-art'])copy('public/assets/'+n);
for(const n of ['player.gif','rival.png','display.woff2','FONT-LICENSE.txt']){fs.mkdirSync('public/assets/offline',{recursive:true});fs.copyFileSync('web/assets/'+n,'public/assets/offline/'+n);}
copy('AGENTS.md');copy('tsconfig.json');copy('postcss.config.mjs');
fs.writeFileSync('docs/source-copy-manifest.json',JSON.stringify({source,files:manifest},null,2));
console.log('Copied '+manifest.length+' original source/assets; no dependencies, secrets, caches or Git history.');
