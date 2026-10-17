import fs from 'node:fs';
import crypto from 'node:crypto';
const original = JSON.parse(fs.readFileSync('reference/prototype/recovery-manifest.json'));
const paths = ['scripts/dex.gd', 'scripts/encounters.gd', 'scripts/state/game_state.gd', 'scripts/ui/pokedex_panel.gd', 'scripts/pokemon_sprites.gd', 'scripts/audio.gd', 'scripts/ui/credits_panel.gd'];
const changes = paths.map(path => ({ path, originalSha256: original.entries.find(entry => entry.path === path).originalSha256, extendedSha256: crypto.createHash('sha256').update(fs.readFileSync(`game/${path}`)).digest('hex') }));
fs.writeFileSync('reference/empress/runtime-changes.json', JSON.stringify({ reason: 'Explicit Gen1–9 roster extension; original recovery manifest retained unchanged.', changes }, null, 2) + '\n');
