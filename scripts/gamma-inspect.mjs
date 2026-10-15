import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

// Read-only inspection. Does not execute the supplied game or decrypt assets.
const root = process.argv[2] || 'C:/Users/ronde/Downloads/gamma-emerald-ea-windows';
const manifestPath = path.join(root, 'Manifest_UFSFiles_Win64.txt');
const manifest = fs.readFileSync(manifestPath);
const entries = manifest.toString('utf8').split(/\r?\n/).filter(Boolean).map((line, i) => ({ line: i + 1, path: line.split('\t')[0] }));
const pakPath = path.join(root, 'PokemonEmerald/Content/Paks/PokemonEmerald-Windows.pak');
const size = fs.statSync(pakPath).size;
const fd = fs.openSync(pakPath, 'r');
const tail = Buffer.alloc(512);
fs.readSync(fd, tail, 0, tail.length, size - tail.length);
fs.closeSync(fd);
let footer;
for (let i = 17; i < tail.length - 44; i++) {
  if (tail.readUInt32LE(i) !== 0x5a6f12e1) continue;
  footer = {
    magicOffset: size - tail.length + i,
    magic: '0x5a6f12e1',
    version: tail.readUInt32LE(i + 4),
    encryptedIndexFlag: tail[i - 1],
    indexOffset: Number(tail.readBigUInt64LE(i + 8)),
    indexSize: Number(tail.readBigUInt64LE(i + 16)),
    indexSha1: tail.subarray(i + 24, i + 44).toString('hex'),
    firstCompressionName: tail.subarray(i + 44, i + 76).toString().replace(/\0.*$/, ''),
  };
}
console.log(JSON.stringify({
  inspectedAt: new Date().toISOString(),
  root,
  manifestSha256: crypto.createHash('sha256').update(manifest).digest('hex'),
  manifestEntryCount: entries.length,
  pak: { path: pakPath, size, footer },
  maps: entries.filter(e => e.path.startsWith('PokemonEmerald/Content/MAPS/') && e.path.endsWith('.umap')),
  dialogue: entries.filter(e => e.path.startsWith('PokemonEmerald/Content/DialogueForEntireGame/') && e.path.endsWith('.uasset')),
  cutscenes: entries.filter(e => /^PokemonEmerald\/Content\/(SEQ|BPS\/CUTSCENES)\//.test(e.path) && e.path.endsWith('.uasset')),
  limitations: [
    'Inventory names establish shipped candidate assets, not reachability, exact dialogue, event order or actual runtime behavior.',
    'Encrypted pak index not decrypted. No encryption key searched for or recovered.',
    'No game execution, camera observation, asset extraction or full-campaign verification performed.',
  ],
}, null, 2));
