import fs from 'node:fs';
import crypto from 'node:crypto';
import ts from 'typescript';
import { readAsset, source } from './read-empress-asar.mjs';

const json = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const write = (p, value) => fs.writeFileSync(p, JSON.stringify(value, null, 2) + '\n');
const id = s => s.toLowerCase().normalize('NFD').replace(/[^a-z0-9]/g, '');
const slug = s => s.toLowerCase().replaceAll(' ', '_').replaceAll('.', '').replaceAll("'", '');
const csv = p => {
  const [header, ...rows] = fs.readFileSync(p, 'utf8').trim().split(/\r?\n/).map(s => s.split(','));
  return rows.map(row => Object.fromEntries(header.map((key, i) => [key, row[i]])));
};
// Read literal data from Showdown's packaged module without executing it.
function literal(node) {
  if (ts.isStringLiteral(node) || ts.isNumericLiteral(node)) return ts.isNumericLiteral(node) ? Number(node.text) : node.text;
  if (node.kind === ts.SyntaxKind.TrueKeyword) return true;
  if (node.kind === ts.SyntaxKind.FalseKeyword) return false;
  if (node.kind === ts.SyntaxKind.NullKeyword) return null;
  if (ts.isPrefixUnaryExpression(node) && node.operator === ts.SyntaxKind.MinusToken) return -literal(node.operand);
  if (ts.isArrayLiteralExpression(node)) return node.elements.map(literal);
  if (ts.isObjectLiteralExpression(node)) return Object.fromEntries(node.properties.map(p => {
    if (!ts.isPropertyAssignment(p)) throw Error('Non-data object property');
    return [p.name.text, literal(p.initializer)];
  }));
  throw Error(`Non-literal syntax: ${ts.SyntaxKind[node.kind]}`);
}
function exportData(member, exportName) {
  const tree = ts.createSourceFile(member, readAsset(member).toString('utf8'), ts.ScriptTarget.Latest, true);
  let result;
  function visit(n) {
    if (ts.isBinaryExpression(n) && n.left.getText(tree) === `exports.${exportName}` && ts.isObjectLiteralExpression(n.right)) result = literal(n.right);
    if (!result) ts.forEachChild(n, visit);
  }
  visit(tree);
  if (!result) throw Error(`Missing data export ${exportName}`);
  return result;
}

const catalog = JSON.parse(readAsset('client/data/catalog.json'));
const pokedex = exportData('node_modules/@pkmn/sim/build/cjs/data/pokedex.js', 'Pokedex');
const learnsets = exportData('node_modules/@pkmn/sim/build/cjs/data/learnsets.js', 'Learnsets');
const speciesMeta = Object.fromEntries(csv('reference/empress/pokemon_species.csv').map(row => [Number(row.id), row]));
const pokemonMeta = Object.fromEntries(csv('reference/empress/pokemon.csv').filter(row => row.is_default === '1').map(row => [Number(row.species_id), row]));
const effort = {};
const statNames = { 1: 'hp', 2: 'atk', 3: 'def', 4: 'spa', 5: 'spd', 6: 'spe' };
for (const row of csv('reference/empress/pokemon_stats.csv')) {
  effort[row.pokemon_id] ||= {};
  if (Number(row.effort) > 0) effort[row.pokemon_id][statNames[row.stat_id]] = Number(row.effort);
}
const originalSpecies = json('game/data/species.json');
const originalByNumber = Object.fromEntries(Object.entries(originalSpecies).filter(([key]) => key !== '_doc').map(([key, value]) => [value.dex_no, key]));
const originalMoves = json('game/data/moves.json').moves;
const supported = new Map(originalMoves.map(move => [id(move.id), move]));
const newMoves = [];
const originalAbilities = json('game/data/abilities.json');
const abilities = { ...originalAbilities };
for (const ability of Object.values(catalog.abilities)) {
  const key = id(ability.name);
  if (!abilities[key]) abilities[key] = { name: ability.name, desc: ability.description || '', display_only: true };
}
// Translate only damaging moves to already implemented action kinds. Special
// modern move mechanics are not represented as a canonical simulator.
const statuses = { brn: 'burn', psn: 'poison', tox: 'poison', par: 'paralysis', slp: 'sleep', frz: 'freeze' };
for (const move of Object.values(catalog.moves)) {
  if (supported.has(move.id) || move.category === 'Status' || !(move.basePower > 0)) continue;
  const kind = ({ melee: 'arc', projectile: 'projectile', pulse: 'aoe_self', target: 'aoe_target', self: 'arc' })[move.arena?.kind] || (move.category === 'Physical' ? 'arc' : 'projectile');
  const imported = { id: move.id, name: move.name, desc: `A ${move.type.toLowerCase()} attack with ${move.basePower} power.`, type: move.type.toLowerCase(), category: move.category.toLowerCase(), kind, power: move.basePower, uses: Math.max(1, move.pp), accuracy: move.accuracy === true ? 100 : move.accuracy, range: kind === 'arc' ? 2.0 : 9.0, speed: 16, knockback: 4, angle: 90, radius: kind === 'aoe_self' ? 3.5 : 1.6, windup: 0.3, national_adaptation: true };
  if (move.secondary?.status && statuses[move.secondary.status]) imported.effect = { status: statuses[move.secondary.status], chance: (move.secondary.chance || 100) / 100 };
  supported.set(move.id, imported);
  newMoves.push(imported);
}
if (!supported.has('struggle')) throw Error('Missing safe last-resort move');
const growth = { 1: 'slow', 2: 'medium_fast', 3: 'fast', 4: 'medium_slow', 5: 'erratic', 6: 'fluctuating' };
const base = catalog.species.filter(s => s.num >= 1 && s.num <= 1025 && !s.forme).sort((a, b) => a.num - b.num);
if (base.length !== 1025 || new Set(base.map(s => s.num)).size !== 1025) throw Error('Incomplete National Dex');
const names = Object.fromEntries(base.map(s => [s.id, originalByNumber[s.num] || s.name]));
const records = {};
const adaptations = [];
for (const s of base) {
  const name = names[s.id];
  const old = originalSpecies[name];
  const meta = speciesMeta[s.num];
  const info = pokemonMeta[s.num];
  const dex = pokedex[s.id];
  if (!meta || !info || !dex) throw Error(`Missing canonical metadata: ${name}`);
  const natural = learnsets[s.id]?.learnset || {};
  const learned = [];
  for (const [moveId, methods] of Object.entries(natural)) {
    const move = supported.get(moveId);
    if (!move) continue;
    const byLevel = methods.map(method => /^([1-9])L(\d+)$/.exec(method)).filter(Boolean);
    if (!byLevel.length) continue;
    const generation = Math.max(...byLevel.map(match => Number(match[1])));
    const level = Math.min(...byLevel.filter(match => Number(match[1]) === generation).map(match => Number(match[2])));
    learned.push([Math.max(1, level), move.id]);
  }
  learned.sort((a, b) => a[0] - b[0] || a[1].localeCompare(b[1]));
  const damaging = learned.find(([, moveId]) => Number(supported.get(id(moveId))?.power) > 0);
  if (!damaging || damaging[0] > 1) {
    const knownDamage = Object.keys(natural).map(key => supported.get(key)).find(move => move?.power > 0) || supported.get('struggle');
    learned.unshift([1, damaging?.[1] || knownDamage.id]);
    adaptations.push({ species: name, starterMove: learned[0][1], reason: 'Playable low-level encounter kit; canonical learn levels retained after starter move.' });
  }
  const starting = [...new Set(learned.filter(([level]) => level === 1).map(([, move]) => move))].slice(-4);
  if (!starting.some(move => supported.get(id(move))?.power > 0)) starting[0] = learned.find(([, move]) => supported.get(id(move))?.power > 0)[1];
  const stats = s.baseStats;
  const record = { ...(old || {}), dex_no: s.num, generation: s.gen, national_id: s.id, asset_slug: old ? slug(name) : s.id, types: s.types.map(type => type.toLowerCase()), base: stats, height_m: s.heightm, weight_kg: s.weightkg, catch_rate: Number(meta.capture_rate), gender_ratio: Number(meta.gender_rate) < 0 ? -1 : Number(meta.gender_rate) / 8, base_exp: Number(info.base_experience) || 100, growth: growth[meta.growth_rate_id], legendary: meta.is_legendary === '1' || meta.is_mythical === '1' };
  if (!old) Object.assign(record, { abilities: Object.values(s.abilities).map(id), pp: 100, moves: starting, learnset: learned, ev_yield: effort[info.id] || {}, jump_height: 0.8, locomotion: s.types.includes('Flying') ? 'fly' : 'ground', fly_height: s.types.includes('Flying') ? 0.65 : 0, swimmer: s.types.includes('Water'), fish: false, category: `Generation ${s.gen} Pokémon`, flavor: `National Pokédex No. ${s.num}. Found among the visiting Pokémon of Kanto.`, native_learnset_source: 'Showdown packaged level-up records; supported action moves only.' });
  if (!old) {
    const target = base.find(candidate => pokedex[candidate.id]?.prevo && id(pokedex[candidate.id].prevo) === s.id && pokedex[candidate.id].evoLevel && !pokedex[candidate.id].evoType);
    if (target) record.evolution = { level: pokedex[target.id].evoLevel, into: names[target.id] };
  }
  records[name] = record;
}
const types = json('game/data/types.json');
types._doc = 'Generation 9 type chart from the supplied Empress catalog. Missing pairs are neutral.';
types.colors.fairy = [1.0, 0.57, 0.76];
types.chart = Object.fromEntries(catalog.types.map(type => [type.id, {}]));
for (const defending of catalog.types) for (const attacking of catalog.types) {
  const code = defending.damageTaken[attacking.name] || 0;
  if (code) types.chart[attacking.id][defending.id] = ({ 1: 2, 2: 0.5, 3: 0 })[code];
}
// Place every species in reachable existing tables. Original residents remain
// half the encounter pool; level ranges and story gates are unchanged.
const tables = fs.readdirSync('game/data/encounters').filter(file => file.endsWith('.json')).map(file => ({ name: file.replace('.json', ''), data: json(`game/data/encounters/${file}`) })).filter(table => table.data.entries?.length && table.data.entries.some(e => ['both', 'grass', 'visible'].includes(e.mode)));
const extras = Object.fromEntries(tables.map(table => [table.name, []]));
const originalResidents = new Set(tables.flatMap(table => table.data.entries.map(e => e.species)));
for (const s of base) {
  const name = names[s.id];
  if (originalResidents.has(name)) continue;
  const table = tables[(s.num * 7 + s.gen) % tables.length];
  const levels = table.data.entries.filter(e => e.level_range).map(e => e.level_range);
  const low = Math.min(...levels.map(r => r[0]));
  const high = Math.max(...levels.map(r => r[1]));
  extras[table.name].push({ species: name, level_range: [low, high], weight: records[name].legendary ? 0.1 : 1, mode: 'both', time: 'any', behaviour: 'passive' });
}
write('game/data/national-species.json', records);
write('game/data/national-moves.json', { moves: newMoves, _doc: 'Damaging moves adapted to existing real-time action kinds; special modern mechanics are not simulated.' });
write('game/data/national-types.json', types);
write('game/data/national-abilities.json', abilities);
write('game/data/national-encounters.json', extras);
write('reference/empress/data-import.json', { source, sourceSha256: crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'), baseSpecies: base.length, addedSpecies: base.length - (Object.keys(originalSpecies).length - 1), generations: Object.fromEntries(Array.from({ length: 9 }, (_, i) => [i + 1, base.filter(s => s.gen === i + 1).length])), addedMoves: newMoves.length, originalMoves: originalMoves.length, existingSourceSpeciesRetained: Object.keys(originalSpecies).length - 1, encounterTables: tables.map(t => t.name), starterMoveAdaptations: adaptations, metadataSources: ['https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/pokemon_species.csv', 'https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/pokemon.csv'], limitations: ['Abilities remain display-only in original engine.', 'Special evolutions are obtainable directly; only source-supported level evolutions are automatic.', 'Some low-level visiting species receive an adapted supported starter attack.', 'Only the 1025 base National Dex species are imported, not every alternate form.'] });
console.log(`Imported ${base.length} base species, ${newMoves.length} additional action moves, ${tables.length} mixed encounter pools.`);
