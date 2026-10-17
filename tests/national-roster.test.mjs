import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = p => JSON.parse(fs.readFileSync(p));
const roster = read('game/data/national-species.json');
const moves = new Map([...read('game/data/national-moves.json').moves, ...read('game/data/moves.json').moves].map(move => [move.id, move]));

test('all 1025 National Dex numbers have usable stats, growth, attacks and own artwork', () => {
  assert.deepEqual(Object.values(roster).map(s => s.dex_no).sort((a, b) => a - b), Array.from({ length: 1025 }, (_, i) => i + 1));
  for (const [name, species] of Object.entries(roster)) {
    assert.ok(Object.values(species.base).every(stat => stat > 0), name);
    assert.ok(species.catch_rate >= 3 && species.catch_rate <= 255, name);
    assert.ok(species.growth, name);
    assert.ok(species.moves.length > 0, name);
    for (const move of species.moves) assert.ok(moves.has(move), `${name}/${move}`);
    for (const [, move] of species.learnset) assert.ok(moves.has(move), `${name}/${move}`);
    const dir = `game/assets/pokemon/${species.asset_slug}`;
    const bytes = fs.readFileSync(`${dir}/overworld.png`);
    assert.equal(bytes.subarray(1, 4).toString(), 'PNG', name);
    const cfg = read(`${dir}/sprite.json`);
    assert.equal(bytes.readUInt32BE(16) % cfg.hframes, 0, name);
    assert.equal(bytes.readUInt32BE(20) % cfg.vframes, 0, name);
  }
});

test('every species is obtainable without an unsupported evolution or network service', () => {
  const original = fs.readdirSync('game/data/encounters').filter(p => p.endsWith('.json')).flatMap(file => read(`game/data/encounters/${file}`).entries);
  const additions = Object.values(read('game/data/national-encounters.json')).flat();
  const available = new Set([...original, ...additions].map(entry => entry.species));
  for (const name of Object.keys(roster)) assert.ok(available.has(name), name);
  const types = read('game/data/national-types.json');
  assert.equal(types.chart.dragon.fairy, 0);
  assert.equal(types.chart.fairy.dragon, 2);
  assert.equal(types.chart.steel.fairy, 2);
});
