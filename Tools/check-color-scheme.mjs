import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
function swiftFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? swiftFiles(file) : entry.name.endsWith('.swift') ? [file] : [];
  });
}

// Source-policy checks only; screenshots/native rendering still need iOS.
const design = read('Feather/Views/Common/NullSignDesign.swift');
assert(design.includes('static let canvas = Color(red: 0.11, green: 0.11, blue: 0.12)'));
assert(design.includes('static let groupedSurface = Color(red: 0.17, green: 0.17, blue: 0.18)'));
assert(design.includes('static let surface = groupedSurface'), 'Ordinary cards must use Settings’ card color.');
assert(design.includes('var fill: Color = NullSignStyle.surface'));
assert(design.includes('.background(NullSignStyle.canvas)') && design.includes('.toolbarBackground(NullSignStyle.canvas, for: .navigationBar)'));
assert(read('Feather/Views/Settings/SettingsView.swift').includes('.nullSignSurface(fill: NullSignStyle.groupedSurface)'));
for (const name of [
  'Settings/SettingsView.swift', 'Sources/SourcesView.swift', 'Library/LibraryView.swift',
  'Sources/Apps/SourceAppsView.swift', 'Sources/Apps/Detail/SourceAppsDetailView.swift',
  'Sources/Apps/Detail/VersionHistoryView.swift', 'Sources/Apps/Detail/ScreenshotPreviewView.swift',
  'Sources/Apps/News/SourceNewsCardInfoView.swift'
]) {
  const source = read(`Feather/Views/${name}`);
  assert(source.includes('.nullSignPage()'), `${name}: page and navigation must share Settings’ canvas`);
  assert(!/\.tint\(\.white\)/.test(source), `${name}: page-level actions must retain the blue accent`);
}

for (const file of swiftFiles(path.join(root, 'Feather/Views'))) {
  const source = fs.readFileSync(file, 'utf8');
  assert(!/NullSignStyle\.(sky|ink)|\.background\(Color\.black(?:\)|\.ignoresSafeArea)|Color\.black\.ignoresSafeArea/.test(source), `${path.relative(root, file)}: legacy blue/black page palette`);
}
const banner = read('Feather/Views/Common/NullSignOverviewBanner.swift');
assert(banner.includes('.background(NullSignStyle.canvas)'));
assert(banner.includes('RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous)'));
assert(banner.includes('.strokeBorder(NullSignStyle.faint.opacity(0.35), lineWidth: 1)'));
assert(!/NullSignOverviewWave|\.fill\(/.test(banner), 'Overview must outline the card, not draw filled waves.');
assert(banner.includes('.clipped()') && banner.includes('.allowsHitTesting(false)'));
assert(!/\.fill\(NullSignStyle\.(accent|teal)|NullSignStyle\.yellow/.test(banner), 'Overview chrome must be charcoal, with category-colored glyphs.');
assert(banner.includes('NullSignStyle.categoryColor(for: systemImage)'));
assert(read('Feather/Views/TabView/VariedTabbarView.swift').includes('.background(NullSignStyle.canvas)'));
assert(read('Feather/Views/Sources/Apps/UIKit/SourceAppsTableRepresentableView.swift').includes('UIColor(NullSignStyle.canvas).withAlphaComponent(0.85)'));
// The dock's selected-state shade is shared across all tabs, not an alternate
// page/card palette. App artwork and screenshot pixels are never recolored.
console.log('Shared Settings palette passed: charcoal page/navigation, matching card fills, overview chrome, and UIKit headers.');
