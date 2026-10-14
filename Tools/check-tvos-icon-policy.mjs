import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8').replaceAll('\r\n', '\n');
const view = read('Feather/Views/Common/FRAppIconView.swift');
assert(!/bundledFallbackAssetName|LineupTV|StadiumSyncTV|com\.nulldev85\.nullsports/.test(view),
  'Library previews must not override package artwork with bundle-ID-specific images.');
assert(view.includes('if app != nil {\n\t\t\t\t_load()'), 'Every imported/signed app must load its own icon.');
assert(view.includes('if TVIconSelection.isTVApp(info) {\n\t\t\treturn tvOSIcon(in: bundleURL, info: info)'));
assert(!/tvOSIcon\([^\n]+\)\s*\?\?\s*iconTest/.test(view), 'tvOS must not fall through to the iOS IconServices recipe.');
assert(!/UIImage\(named:|iconBonus|DirectoryEnumerator/.test(view), 'Do not select unrelated catalog/loose artwork.');
assert(view.includes('TVIconSelection.assetNames(in: info)') && view.includes('url.path.hasPrefix(root)'));

const objc = read('Feather/Utilities/iconPoc.m');
assert(!/flattenedUIImage|flattenedImage|layerStackWithName/.test(objc), 'Foreign tvOS stacks must not use private flattening helpers.');
assert(objc.includes('[namedImage isKindOfClass:imageClass]'), 'Only ordinary CoreUI image objects may be decoded.');
const tvReader = objc.slice(objc.indexOf('UIImage* tvOSIconTest'), objc.indexOf('UIImage* iconTest'));
assert(!tvReader.includes('IconServices.framework/'));
assert(tvReader.includes('FRCompositeTVIconLayers(catalog, name)') && tvReader.includes('@catch (NSException *exception)'));
const compositor = objc.slice(objc.indexOf('static UIImage *FRCompositeTVIconLayers'), objc.indexOf('@interface LSApplicationRecordFake'));
assert(compositor.includes('@[@"Background", @"Middle", @"Foreground"]'));
assert(compositor.includes('FRLargestCatalogImage(catalog, iconName)'));
assert(compositor.includes('[layer drawInRect:rect]'));
console.log('tvOS icon source policy passed: actual package artwork, primary-only lookup, and no foreign stack flattening.');
