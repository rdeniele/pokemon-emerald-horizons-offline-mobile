import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

test('unmodified recovered gameplay and resources retain their source hashes', () => {
  const manifest = JSON.parse(fs.readFileSync('reference/prototype/recovery-manifest.json'));
  const extensions = new Set(JSON.parse(fs.readFileSync('reference/empress/runtime-changes.json')).changes.map(entry => entry.path));
  assert.equal(manifest.scriptsDecompiled, 146);
  for (const entry of manifest.entries.filter(entry => !entry.adapted && !extensions.has(entry.path))) {
    const bytes = fs.readFileSync(`game/${entry.path}`);
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), entry.originalSha256, entry.path);
  }
});

test('national runtime changes are explicitly recorded against the original recovery', () => {
  const manifest = JSON.parse(fs.readFileSync('reference/prototype/recovery-manifest.json'));
  const extensions = JSON.parse(fs.readFileSync('reference/empress/runtime-changes.json'));
  for (const entry of extensions.changes) {
    assert.equal(entry.originalSha256, manifest.entries.find(original => original.path === entry.path).originalSha256);
    assert.equal(crypto.createHash('sha256').update(fs.readFileSync(`game/${entry.path}`)).digest('hex'), entry.extendedSha256);
  }
});

test('reapplying mobile adaptations produces identical files', () => {
  const files = JSON.parse(fs.readFileSync('reference/prototype/recovery-manifest.json')).entries.filter(entry => entry.adapted);
  const snapshot = () => files.map(entry => fs.readFileSync(`game/${entry.path}`, 'utf8'));
  const before = snapshot();
  execFileSync(process.execPath, ['scripts/adapt-prototype.mjs']);
  assert.deepEqual(snapshot(), before);
  execFileSync(process.execPath, ['scripts/adapt-prototype.mjs']);
  assert.deepEqual(snapshot(), before);
});
