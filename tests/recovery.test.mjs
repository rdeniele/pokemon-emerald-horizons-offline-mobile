import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';

test('unmodified recovered gameplay and resources retain their source hashes', () => {
  const manifest = JSON.parse(fs.readFileSync('reference/prototype/recovery-manifest.json'));
  assert.equal(manifest.scriptsDecompiled, 146);
  for (const entry of manifest.entries.filter(entry => !entry.adapted)) {
    const bytes = fs.readFileSync(`game/${entry.path}`);
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), entry.originalSha256, entry.path);
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
