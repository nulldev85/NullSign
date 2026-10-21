import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');

// Source-policy regression checks, not a substitute for rendering on iOS.
const design = read('Feather/Views/Common/NullSignDesign.swift');
const tile = design.slice(design.indexOf('struct NullSignIconTile:'), design.indexOf('struct NullSignChip:'));
assert(tile.includes('var tint: Color? = nil'), 'Untinted tiles must resolve a category color, not default to white.');
assert(tile.includes('var filled: Bool = true'), 'Row tiles must default to a colored surface.');
assert(tile.includes('tint ?? NullSignStyle.categoryColor(for: systemImage)'));
assert(tile.includes('.symbolRenderingMode(.monochrome)'));
assert(tile.includes('UIImage(systemName: systemImage) == nil ? "square.dashed" : systemImage'),
  'Unavailable symbols must not render as empty tiles.');

const categorySource = design.slice(design.indexOf('static func categoryColor'), design.indexOf('// MARK: - Surfaces'));
const categories = new Map();
for (const match of categorySource.matchAll(/case ([^:]+):\s*return (\w+)/g)) {
  for (const symbol of match[1].matchAll(/"([^"]+)"/g)) categories.set(symbol[1], match[2]);
}
for (const [symbol, color] of [
  ['shield', 'success'], ['key', 'success'], ['checkmark.seal', 'success'],
  ['folder', 'warning'], ['folder.badge.person.crop', 'warning'],
  ['puzzlepiece.extension', 'purple'], ['gamecontroller', 'purple'], ['character.bubble', 'purple'],
  ['music.note.list', 'danger'], ['trash', 'danger'],
  ['arrow.triangle.2.circlepath', 'teal'], ['speedometer', 'teal']
]) assert.equal(categories.get(symbol), color, `${symbol}: lost its category color`);

for (const file of [
  'Feather/Views/Settings/Signing Options/ConfigurationView.swift',
  'Feather/Views/Signing/Shared/SigningOptionsView.swift'
]) {
  const source = read(file);
  assert(!/link\.badge\.minus|doc\.badge\.minus/.test(source), `${file}: blank cleanup symbols returned`);
  for (const symbol of ['link', 'doc.text']) {
    assert(source.includes(`systemImage: "${symbol}",`) &&
      new RegExp(`systemImage: "${symbol.replaceAll('.', '\\.')}"[,]\\s*tint: NullSignStyle.danger`).test(source),
    `${file}: cleanup must use a visible glyph and warning color`);
  }
  assert(source.includes('NullSignIconTile(systemImage: systemImage, tint: tint'));
  assert(source.includes('.disabled('), `${file}: compatibility controls must retain disabled states`);
}

const certificates = read('Feather/Views/Settings/Certificates/CertificatesView.swift');
for (const symbol of ['plus', 'ellipsis']) {
  const label = certificates.slice(certificates.indexOf(`Image(systemName: "${symbol}")`));
  assert(/^[\s\S]{0,150}\.foregroundStyle\(NullSignStyle.accent\)/.test(label), `${symbol}: certificate action lost its blue accent`);
}
assert(certificates.includes('.opacity(isCompatible ? 1 : 0.4)'), 'Incompatible certificates must remain visually disabled.');
assert(!read('Feather/Views/Settings/Certificates/CertificatesAddView.swift').includes('file == nil ? .white'));

const menu = read('Feather/Views/Common/NullSignMenuSheet.swift');
assert(/if #available\(iOS 26\.0, \*\)\s*\{\s*Color\.clear\s*\}\s*else\s*\{\s*Circle\(\)\.fill\(NullSignStyle\.fill\)/.test(menu),
  'Modern toolbar close buttons must not stack custom and system circles.');
assert(menu.includes('.frame(width: 44, height: 44)') && menu.includes('.accessibilityLabel(.localized("Close"))'));

console.log('Icon style policy passed: colored row defaults, cleanup glyphs, certificate actions, and single-surface popup close buttons.');
