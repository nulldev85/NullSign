import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

// Packaging only: resize the chosen image-generation output to Apple's canvas.
// Do not alter the design, colors, composition, or aspect ratio.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const input = process.argv[2];
assert(input, 'Usage: node Tools/prepare-app-icon.mjs <chosen-square.png> [node-modules-directory]');
const require = createRequire(import.meta.url);
const sharp = process.argv[3] ? require(path.resolve(process.argv[3], 'sharp')) : require('sharp');
const metadata = await sharp(input).metadata();
assert.equal(metadata.width, metadata.height, 'The selected icon must already be square; do not crop the mark.');
const icon = await sharp(input)
  .resize(1024, 1024, { kernel: 'lanczos3' })
  .toColourspace('srgb')
  .removeAlpha()
  .png({ compressionLevel: 9 })
  .toBuffer();
const targets = [
  'Feather/Resources/AppIcon.icon/Assets/nullsign.png',
  'Feather/Resources/Assets.xcassets/AppIcon.appiconset/nullsign.png',
  'Feather/Resources/Assets.xcassets/AppIcon.appiconset/nullsign_dark.png',
  'Feather/Resources/Assets.xcassets/AppIcon.appiconset/nullsign_tint.png'
];
for (const target of targets) {
  const destination = path.join(root, target);
  assert(fs.lstatSync(destination).isFile(), `Expected an existing regular icon file: ${target}`);
  fs.writeFileSync(destination, icon);
  console.log(`Saved 1024px opaque RGB icon: ${target}`);
}
