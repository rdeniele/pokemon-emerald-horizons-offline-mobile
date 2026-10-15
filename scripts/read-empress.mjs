import fs from 'node:fs';
const path='C:/Users/ronde/Downloads/Empress-Pokemon-2D-win/resources/app.asar';
const fd=fs.openSync(path,'r'), prefix=Buffer.alloc(16);fs.readSync(fd,prefix,0,16,0);
const header=Buffer.alloc(prefix.readUInt32LE(12));fs.readSync(fd,header,0,header.length,16);
const tree=JSON.parse(header),base=8+prefix.readUInt32LE(4);
function read(name){let e=tree;for(const part of name.split('/'))e=e.files?.[part];if(!e||e.unpacked||e.link)throw Error(name);const b=Buffer.alloc(+e.size);fs.readSync(fd,b,0,b.length,base+(+e.offset));return b;}
function walk(t,p=''){return Object.entries(t.files||{}).flatMap(([name,e])=>e.files?walk(e,p+name+'/'):[{path:p+name,size:e.size}]);}
fs.mkdirSync('build/reference',{recursive:true});
const inventory=walk(tree);fs.writeFileSync('build/reference/empress-inventory.json',JSON.stringify(inventory,null,2));
for(const name of ['client/app.js','client/index.html','client/combat.mjs','client/controls.mjs','client/story.mjs','server/engine.cjs','server/rules.cjs','package.json'])fs.writeFileSync('build/reference/'+name.replaceAll('/','-'),read(name));
fs.mkdirSync('public/assets/offline/trainers',{recursive:true});
for(const entry of inventory.filter(x=>x.path.startsWith('client/assets/trainers/')&&x.path.endsWith('.png')))fs.writeFileSync('public/assets/offline/trainers/'+entry.path.split('/').at(-1),read(entry.path));
console.log(JSON.stringify(inventory.filter(x=>/story|world|tile|map|trainer|player|grass|tree/i.test(x.path)).slice(0,100),null,2));
fs.closeSync(fd);
