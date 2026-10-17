// Static extraction only: never evaluates any code from the supplied game.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { source, readAsset, extractAsset } from './read-empress-asar.mjs';

const json = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const write = (p, v) => { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, JSON.stringify(v, null, 2) + '\n'); };
const catalog = JSON.parse(readAsset('client/data/catalog.json').toString('utf8'));
const movement = JSON.parse(readAsset('client/data/movement.json').toString('utf8'));
const inventory = new Set(json('reference/empress/asar-inventory.json').map(v => v.path));
const national = json('game/data/national-species.json');
const reportPath = 'reference/empress/asset-import.json';
const preserved = fs.existsSync(reportPath) ? json(reportPath).preservedSpecies : fs.readdirSync('game/assets/pokemon').filter(n => fs.statSync(`game/assets/pokemon/${n}`).isDirectory());
const preservedSet = new Set(preserved.map(n => n.toLowerCase()));
const member = src => {
  const p = 'client/' + src.replace(/^\//, '');
  if (!inventory.has(p)) throw new Error(`Missing source asset ${p}`);
  return p;
};
const records = [];
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const extract = (src, dest) => { const p = member(src); extractAsset(p, dest); return { source: p, destination: dest, sha256: sha(readAsset(p)) }; };
for (const [name, data] of Object.entries(national)) {
  if (!data || typeof data !== 'object' || !data.dex_no) continue;
  const entry = catalog.species.find(s => s.num === data.dex_no && !s.forme);
  if (!entry) throw new Error(`No base catalog entry for ${name} #${data.dex_no}`);
  const slug = data.asset_slug ?? name.toLowerCase().replaceAll(' ', '_').replaceAll('.', '').replaceAll("'", '');
  if (!/^[a-z0-9_-]+$/.test(slug)) throw new Error(`Unsafe species directory ${slug}`);
  if (preservedSet.has(slug)) continue;
  const dir = `game/assets/pokemon/${slug}`;
  const m = movement[entry.id];
  const files = [];
  const visible = Math.max(0.45, Math.min(2.2, entry.heightm));
  let mode;
  if (m?.idle?.src) {
    mode = 'directional';
    const anims = {};
    const choices = { Idle: ['idle'], Walk: ['walk', 'idle'], Attack: ['attack', 'walk', 'idle'], Shoot: ['shoot', 'special', 'attack', 'idle'], Hurt: ['hurt', 'idle'], Faint: ['faint', 'hurt', 'idle'], Charge: ['charge', 'special', 'idle'], Sleep: ['sleep', 'idle'] };
    const copied = new Set();
    for (const [action, options] of Object.entries(choices)) {
      const selected = options.find(k => m[k]?.src);
      const a = m[selected];
      const file = path.basename(a.src);
      if (!copied.has(file)) { files.push(extract(a.src, `${dir}/pmd/${file}`)); copied.add(file); }
      anims[action] = { file, w: a.frameWidth, h: a.frameHeight, dirs: a.directions, durations: a.durations, anchor: a.anchors, rush: a.rushFrame ?? -1, hit: a.hitFrame ?? -1, return: a.returnFrame ?? -1, sourceAnimation: a.sourceAnimation, requestedAnimation: action };
      if (!a.anchors || !a.durations || a.durations.length !== a.frames) throw new Error(`Incomplete animation ${entry.id}/${action}`);
    }
    write(`${dir}/pmd/anims.json`, anims);
    files.push(extract(m.idle.src, `${dir}/overworld.png`));
    write(`${dir}/sprite.json`, { hframes: m.idle.frames, vframes: m.idle.directions, rows: { down: 0, right: m.idle.directions === 8 ? 2 : 0, up: m.idle.directions === 8 ? 4 : 0, left: m.idle.directions === 8 ? 6 : 0 }, height_m: entry.heightm, visible_m: visible, real: true });
    // Credit text paths are upstream provenance; Empress does not bundle them.
    if (m.creditFile && inventory.has('client' + m.creditFile)) files.push(extract(m.creditFile, `${dir}/pmd/credits.txt`));
  } else {
    mode = 'static';
    const src = member(entry.sprite);
    fs.mkdirSync(dir, { recursive: true });
    if (entry.sprite.endsWith('.png')) files.push(extract(entry.sprite, `${dir}/overworld.png`));
    else {
      const temporary = `${dir}/.source.gif`;
      extractAsset(src, temporary);
      const result = spawnSync('C:/ffmpeg/bin/ffmpeg.exe', ['-v', 'error', '-y', '-i', temporary, '-frames:v', '1', `${dir}/overworld.png`], { encoding: 'utf8' });
      fs.unlinkSync(temporary);
      if (result.status !== 0) throw new Error(`GIF conversion failed for ${name}: ${result.stderr}`);
      files.push({ source: src, destination: `${dir}/overworld.png`, sourceSha256: sha(readAsset(src)), sha256: sha(fs.readFileSync(`${dir}/overworld.png`)), conversion: 'GIF first frame to PNG, ffmpeg' });
    }
    write(`${dir}/sprite.json`, { hframes: 1, vframes: 1, rows: { down: 0, right: 0, up: 0, left: 0 }, height_m: entry.heightm, visible_m: visible, real: true, staticArtwork: true });
  }
  records.push({ name, dexNo: entry.num, catalogId: entry.id, assetSlug: slug, mode, walkingFallback: Boolean(m?.idle && m.walk?.sourceAnimation !== 'Walk'), sharedArtwork: Boolean(m?.sharedArtwork || entry.spriteSharesBase), authors: m?.authors ?? [], sourcePath: m?.sourcePath ?? entry.spriteSource, upstreamCreditFile: m?.creditFile ?? null, spriteSource: entry.spriteSource, files });
}
const counts = { imported: records.length, directional: records.filter(r => r.mode === 'directional').length, static: records.filter(r => r.mode === 'static').length, walkingFallback: records.filter(r => r.walkingFallback).length, shared: records.filter(r => r.sharedArtwork).length, preserved: preserved.length };
write(reportPath, { sourceArchive: source, preservedSpecies: preserved, counts, species: records });
write('game/data/national-asset-credits.json', { source: 'User-supplied Empress: Pokémon 2D Windows app.asar', dataVersion: catalog.dataVersion, notice: 'Pokémon characters belong to their respective rights holders. Authorship and shared-artwork metadata below is retained from the supplied game; extraction does not imply a new license.', counts, species: records.map(({ files, ...r }) => r) });
const artists = new Map();
for (const author of records.flatMap(r => r.authors)) artists.set(author.name, author.contact || 'Sprite contributor');
write('game/data/national-credits-summary.json', { sections: [
  { title: 'National Pokédex expansion', lines: [
    '1,025 base Pokémon from Generations 1–9.',
    'Additional sprites and cries: supplied Empress: Pokémon 2D package.',
    'Pokémon Showdown data and art; SpriteCollab directional sprites.',
    'Species metadata: PokeAPI.',
    'Original Pokémon rights: Nintendo, Game Freak and Creatures.'
  ] },
  { title: 'Additional sprite artists', entries: [...artists].sort(([a], [b]) => a.localeCompare(b, 'en')).map(([name, detail]) => ({ name, detail })) }
] });
console.log(JSON.stringify(counts));
