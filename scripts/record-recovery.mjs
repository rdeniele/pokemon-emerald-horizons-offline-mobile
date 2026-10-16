import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const original = path.resolve('reference/prototype/original');
const modified = new Set(['project.godot', 'scripts/analytics.gd', 'scripts/ui/touch_controls.gd', 'scripts/controls.gd', 'scripts/settings.gd', 'scripts/front/main_menu.gd', 'scripts/ui/battle_hud.gd', 'scripts/ui/ui_draw.gd']);
const entries = [];
function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === '.godot' || entry.name === 'addons' || entry.name === 'gdre_export.log') continue;
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(full);
    else {
      const relative = path.relative(original, full).replaceAll('\\', '/');
      const destination = path.join('game', relative);
      const sourceHash = hash(fs.readFileSync(full));
      const outputHash = fs.existsSync(destination) ? hash(fs.readFileSync(destination)) : null;
      entries.push({ path: relative, originalSha256: sourceHash, portSha256: outputHash, adapted: modified.has(relative) });
    }
  }
}
walk(original);
const source = 'C:/Users/ronde/Downloads/Archive/PokemonPrototypeDemo.pck';
fs.writeFileSync('reference/prototype/recovery-manifest.json', JSON.stringify({
  source, sha256: hash(fs.readFileSync(source)), tool: 'GDRE Tools 2.7.4', engine: '4.7.1',
  scriptsDecompiled: 146, resourcesConverted: 2724, lossyResourceConversions: 59,
  entries,
}, null, 2) + '\n');
const unexpected = entries.filter(entry => !entry.adapted && entry.originalSha256 !== entry.portSha256);
if (unexpected.length) throw new Error(`Unexpected source differences: ${JSON.stringify(unexpected)}`);
console.log(`Verified ${entries.length} recovered files; only ${modified.size} declared adaptation files differ.`);
