import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const targets = [
  'Feather/Resources/NullSignBlue.icon/Assets/nullsign.png',
  'Feather/Resources/Assets.xcassets/NullSignBlue.appiconset/nullsign.png',
  'Feather/Resources/Assets.xcassets/NullSignBlue.appiconset/nullsign_dark.png',
  'Feather/Resources/Assets.xcassets/NullSignBlue.appiconset/nullsign_tint.png',
  'Feather/Resources/Assets.xcassets/NullSignBrand.imageset/nullsign.png'
];
let canonical;
for (const target of targets) {
  const bytes = fs.readFileSync(path.join(root, target));
  assert(bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), `${target}: invalid PNG signature`);
  assert.equal(bytes.toString('ascii', 12, 16), 'IHDR', `${target}: missing PNG image header`);
  assert.equal(bytes.readUInt32BE(16), 1024, `${target}: width must be 1024`);
  assert.equal(bytes.readUInt32BE(20), 1024, `${target}: height must be 1024`);
  assert.equal(bytes[24], 8, `${target}: expected 8-bit channels`);
  assert.equal(bytes[25], 2, `${target}: icon must be RGB without an alpha channel`);
  let offset = 8;
  while (offset < bytes.length) {
    const length = bytes.readUInt32BE(offset);
    const type = bytes.toString('ascii', offset + 4, offset + 8);
    assert(offset + length + 12 <= bytes.length, `${target}: truncated PNG chunk`);
    assert.notEqual(type, 'tRNS', `${target}: RGB icon must not declare transparent pixels`);
    offset += length + 12;
  }
  if (canonical) assert(bytes.equals(canonical), `${target}: icon appearance does not match the canonical icon`);
  else canonical = bytes;
}
const project = fs.readFileSync(path.join(root, 'Feather.xcodeproj/project.pbxproj'), 'utf8');
assert.equal((project.match(/ASSETCATALOG_COMPILER_APPICON_NAME = NullSignBlue;/g) ?? []).length, 2);
const display = fs.readFileSync(path.join(root, 'Feather/Views/Common/FRAppIconView.swift'), 'utf8');
assert(display.includes('Image("NullSignBrand")') && display.includes('.renderingMode(.original)'));
console.log('App icon checks passed: five matching, opaque 1024px RGB assets and fresh icon catalog wiring.');
