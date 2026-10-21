import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

// Inspect the pixels that Xcode actually packaged, including Apple CgBI PNGs.
// This is diagnostic decoding only; it does not alter or regenerate artwork.
const argument = process.argv[2];
assert(argument, 'Usage: node Tools/check-packaged-icon.mjs <app-directory-or-icon.png>');
const icons = fs.statSync(argument).isDirectory()
  ? fs.readdirSync(argument).filter(name => /^NullSignBlue.*\.png$/.test(name)).map(name => path.join(argument, name))
  : [argument];
assert(icons.length > 0, 'The packaged app must contain the fresh NullSignBlue icon files.');

function inspect(file) {
  const data = fs.readFileSync(file);
  let width, height, channels, cgbi = false;
  const compressed = [];
  assert(data.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])));
  for (let offset = 8; offset < data.length;) {
    const size = data.readUInt32BE(offset);
    const type = data.toString('ascii', offset + 4, offset + 8);
    assert(offset + size + 12 <= data.length, 'Truncated PNG chunk');
    const body = data.subarray(offset + 8, offset + 8 + size);
    if (type === 'CgBI') cgbi = true;
    if (type === 'IHDR') {
      width = body.readUInt32BE(0); height = body.readUInt32BE(4);
      assert(body[8] === 8 && [2, 6].includes(body[9]) && body[12] === 0, 'Expected non-interlaced 8-bit RGB/RGBA PNG');
      channels = body[9] === 6 ? 4 : 3;
    }
    if (type === 'IDAT') compressed.push(body);
    offset += size + 12;
  }
  assert(width > 0 && height > 0 && width <= 2048 && height <= 2048 && channels);
  const bytes = Buffer.concat(compressed);
  const raw = cgbi ? zlib.inflateRawSync(bytes) : zlib.inflateSync(bytes);
  const stride = width * channels;
  assert.equal(raw.length, height * (stride + 1));
  let previous = Buffer.alloc(stride), cursor = 0, blue = 0, teal = 0, white = 0;
  for (let y = 0; y < height; y++) {
    const filter = raw[cursor++], row = Buffer.alloc(stride);
    for (let x = 0; x < stride; x++) {
      const left = x >= channels ? row[x - channels] : 0;
      const up = previous[x], upperLeft = x >= channels ? previous[x - channels] : 0;
      let prediction = 0;
      if (filter === 1) prediction = left;
      else if (filter === 2) prediction = up;
      else if (filter === 3) prediction = Math.floor((left + up) / 2);
      else if (filter === 4) {
        const p = left + up - upperLeft, a = Math.abs(p - left), b = Math.abs(p - up), c = Math.abs(p - upperLeft);
        prediction = a <= b && a <= c ? left : (b <= c ? up : upperLeft);
      } else assert.equal(filter, 0, 'Unexpected PNG filter');
      row[x] = (raw[cursor++] + prediction) & 255;
    }
    for (let x = 0; x < stride; x += channels) {
      const r = row[x + (cgbi ? 2 : 0)], g = row[x + 1], b = row[x + (cgbi ? 0 : 2)];
      const alpha = channels === 4 ? row[x + 3] : 255;
      if (alpha < 240) continue;
      if (b > 150 && r < 90 && g > 70 && b - r > 90) blue++;
      if (g > 130 && r < 100 && Math.abs(g - b) < 90) teal++;
      if (r > 210 && g > 210 && b > 210) white++;
    }
    previous = row;
  }
  const area = width * height;
  assert(blue / area > 0.08 && teal / area > 0.001, `${file}: missing blue mark or turquoise accent`);
  assert(white / area < 0.02, `${file}: appears to contain the old white mark`);
  console.log(JSON.stringify({ file, width, height, bluePixels: blue, turquoisePixels: teal, whitePixels: white }));
}

for (const file of icons) inspect(file);
console.log('Packaged icon pixel checks passed.');
