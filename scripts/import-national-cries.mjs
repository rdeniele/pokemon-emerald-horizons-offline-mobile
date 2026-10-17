import fs from 'node:fs';
import { readAsset, extractAsset } from './read-empress-asar.mjs';
const catalog = JSON.parse(readAsset('client/data/catalog.json'));
const national = JSON.parse(fs.readFileSync('game/data/national-species.json'));
const byId = Object.fromEntries(catalog.species.map(s => [s.id, s]));
let count = 0;
for (const [name, record] of Object.entries(national)) {
  if (['ogg', 'mp3', 'wav'].some(ext => fs.existsSync(`game/assets/audio/cries/${name.toLowerCase()}.${ext}`))) continue;
  const s = byId[record.national_id];
  if (!s.cry) throw Error(`Missing cry ${name}`);
  extractAsset(`client${s.cry}`, `game/assets/audio/cries/national/${s.id}.mp3`);
  count++;
}
fs.writeFileSync('reference/empress/cry-import.json', JSON.stringify({ imported: count, source: 'Supplied Empress ASAR catalog cry paths', sourceRights: 'Original Pokémon audio attribution retained in game credits.' }, null, 2) + '\n');
console.log(`Imported ${count} species cries; existing native cries preserved.`);
