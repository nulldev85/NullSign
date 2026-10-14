import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

// A source-policy check, not an iOS rendering test. Unstyled Text inherits the
// presentation root; explicit font overrides must use the rounded helper.
function unroundedFonts(source) {
  const code = source.replace(
    /\/\*[\s\S]*?\*\/|\/\/[^\n]*|"(?:\\[\s\S]|[^"\\])*"/g,
    match => match.replace(/[^\n]/g, ' ')
  );
  const lines = [];
  for (const match of code.matchAll(/\.font\s*\(\s*/g)) {
    if (!/^\.roundedUI\s*\(/.test(code.slice(match.index + match[0].length))) {
      lines.push(code.slice(0, match.index).split('\n').length);
    }
  }
  return lines;
}

function swiftFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const location = path.join(directory, entry.name);
    return entry.isDirectory() ? swiftFiles(location) : (entry.name.endsWith('.swift') ? [location] : []);
  });
}

if (process.argv.includes('--self-test')) {
  assert.deepEqual(unroundedFonts('Text("Title").font(.title)\nText("Body").font(.system(size: 17))'), [1, 2]);
  assert.deepEqual(unroundedFonts('Text("OK").font(.roundedUI(.body))'), []);
  assert.deepEqual(unroundedFonts('Text(".font(.body)") // .font(.title)\n/* .font(.caption) */'), []);
  assert.deepEqual(unroundedFonts('Text("Title")\n.font(\n  .title.weight(.heavy)\n)'), [2]);
  assert.deepEqual(unroundedFonts('Text("Body").font(customFont)'), [1]);
  console.log('Typography checker self-tests passed.');
}

const files = [
  ...swiftFiles(path.join(root, 'Feather', 'Views')),
  ...swiftFiles(path.join(root, 'NimbleKit', 'Sources', 'NimbleViews'))
];
const violations = files.flatMap(file => unroundedFonts(fs.readFileSync(file, 'utf8'))
  .map(line => `${path.relative(root, file)}:${line}: use .roundedUI(...) for explicit font overrides`));
assert.equal(violations.length, 0, violations.join('\n'));

const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
const appFonts = read('Feather/Extensions/Font+RoundedUI.swift');
const componentFonts = read('NimbleKit/Sources/NimbleViews/Extensions/Font+RoundedUI.swift');
const fontExtension = source => source.slice(source.indexOf('extension Font {')).replace(/\s+/g, '');
assert.equal(fontExtension(appFonts), fontExtension(componentFonts), 'App and shared-component font policies must agree.');
assert(appFonts.includes('design: .rounded') && appFonts.includes('return .heavy') && appFonts.includes('return .bold'));
assert(appFonts.includes('content.fontDesign(.rounded)') && appFonts.includes('#available(iOS 16.1, *)'));

const app = read('Feather/FeatherApp.swift');
assert(app.includes('.nullSignTypography()'), 'Window root must install typography.');
assert(read('Feather/Extensions/UIFont+RoundedUI.swift').includes('withDesign(.rounded)'));
assert(app.includes('UIFont.roundedUI(') && app.includes('UIBarButtonItem.appearance().setTitleTextAttributes'));
assert(read('Feather/Views/Sources/Apps/SourceAppsView.swift').includes('NullSignSearchTypography()'));
const search = read('Feather/Views/Common/NullSignSearchTypography.swift');
assert(search.includes('searchBar.searchTextField') && search.includes('UIFont.roundedUI(') && search.includes('field.adjustsFontForContentSizeCategory = true'));
for (const file of [
  'Feather/Views/Common/NullSignDesign.swift',
  'Feather/Views/Common/NullSignMenuSheet.swift',
  'Feather/Views/Sources/SourcesAddView.swift',
  'Feather/Views/Sources/Apps/News/SourceNewsCardInfoView.swift'
]) assert(read(file).includes('.nullSignTypography()'), `${file}: missing presentation-root typography`);
const hosted = read('Feather/Views/Sources/Apps/UIKit/SourceAppsTableRepresentableView.swift');
assert.equal((hosted.match(/\.nullSignTypography\(\)/g) ?? []).length, 3, 'News, app-cell, and section-header hosting roots must install typography.');
assert(read('NimbleKit/Sources/NimbleViews/Views/NBNavigationView.swift').includes('.modifier(NBRoundedFontDesign())'));
for (const name of ['NBToolbarButton', 'NBToolbarMenu']) {
  assert(read(`NimbleKit/Sources/NimbleViews/Views/${name}.swift`).includes('.font(.roundedUI(.body, weight: .bold))'));
}
console.log(`SF Rounded policy passed across ${files.length} Swift UI/component files and independent presentation roots.`);
console.log('Native system dialogs/pickers and third-party web content keep platform/content typography.');
