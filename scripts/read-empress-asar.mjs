import fs from 'node:fs';
import path from 'node:path';

export const source = 'C:/Users/ronde/Downloads/Empress-Pokemon-2D-win/resources/app.asar';
const fd = fs.openSync(source, 'r');
const prefix = Buffer.alloc(16);
fs.readSync(fd, prefix, 0, 16, 0);
const header = Buffer.alloc(prefix.readUInt32LE(12));
fs.readSync(fd, header, 0, header.length, 16);
const files = JSON.parse(header.toString()).files;
const dataOffset = 8 + prefix.readUInt32LE(4);
export function readAsset(name) {
  let entry = { files };
  for (const part of name.split('/')) entry = entry?.files?.[part];
  if (!entry || entry.files || entry.unpacked || entry.link) throw new Error(`Not a packed regular file: ${name}`);
  const bytes = Buffer.alloc(entry.size);
  const count = fs.readSync(fd, bytes, 0, bytes.length, dataOffset + Number(entry.offset));
  if (count !== bytes.length) throw new Error(`Truncated member: ${name}`);
  return bytes;
}
export function extractAsset(name, destination) {
  const target = path.resolve(destination);
  if (!target.startsWith(path.resolve('.') + path.sep)) throw new Error('Extraction outside project');
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, readAsset(name));
}
