# Blue and charcoal icon refresh

Build 21 keeps NullSign's existing thick, rounded, two-part diagonal mark and
small accent dot. The built-in image-generation tool edited the existing raster
icon; it did not introduce a new logo type. The palette targets the interface's
electric blue, turquoise accent, and charcoal canvas. SF Rounded UI fonts are
unchanged.

## Installed assets

The chosen image is mechanically downscaled, without cropping, to an opaque
1024 × 1024 sRGB PNG. The same file is installed at these workspace paths:

- `Feather/Resources/NullSignBlue.icon/Assets/nullsign.png`
- `Feather/Resources/Assets.xcassets/NullSignBlue.appiconset/nullsign.png`
- `Feather/Resources/Assets.xcassets/NullSignBlue.appiconset/nullsign_dark.png`
- `Feather/Resources/Assets.xcassets/NullSignBlue.appiconset/nullsign_tint.png`
- `Feather/Resources/Assets.xcassets/NullSignBrand.imageset/nullsign.png`

Build 22 gives the catalogs a fresh `NullSignBlue` name and displays the About
artwork directly through `NullSignBrand`, rather than the cached system icon
renderer. The Icon Composer background also uses charcoal. Existing system
appearance handling and the in-app template glyph remain intact. Previous
artwork is recoverable from Git history.

`Tools/prepare-app-icon.mjs` handles only format/size packaging of the chosen
generation. `node Tools/check-app-icon.mjs` verifies dimensions, RGB mode,
absence of transparency, and byte equality across the five installed assets.
The asset check also runs before the GitHub IPA build.

`Tools/check-packaged-icon.mjs` also decodes Xcode's optimized CgBI icon PNGs and
verifies the actual blue/turquoise pixels inside the IPA. It successfully checked
the build-21 artifact's 120px icon (1,609 blue pixels and 32 turquoise pixels).
The macOS workflow applies this check to each packaged build-22 icon.

## Final edit prompt

Built-in image-generation edit, with the previous
`Feather/Resources/AppIcon.icon/Assets/nullsign.png` as its local edit target:

> Use case: precise-object-edit. Asset type: production iOS app icon, 1024 by
> 1024 square, fully opaque. Image 1 is the edit target: NullSign's existing
> icon. Keep exactly the same thick rounded interlocking diagonal symbol, its
> two-part silhouette, the central negative-space channel, its position, scale,
> generous margins, and the small circular accent dot in exactly its existing
> position. Recolor only to match NullSign's new interface: main symbol vivid
> electric blue #0094FF, small accent dot turquoise #2ED9B0, background solid
> dark charcoal #1C1C1F instead of pure black. Preserve the same simple, flat,
> crisp rounded icon type; do not redesign the symbol or add anything. No text,
> no watermark, no mockup, no bevels, no 3D, no shadows, no gradients, no border,
> no outer rounded-corner mask. Background must fill the entire square edge to
> edge; iOS supplies the icon corner mask.

## Build failure repair

Build 20's compiler log reported a type-checking timeout in
`VersionHistoryView.swift` at the nested Download button expression. Build 21
extracts the row and buttons into smaller views and explicitly types the
accessibility labels. Download provenance, copy confirmation, and SF Rounded
remain unchanged. Native compilation is verified by the macOS IPA workflow,
not by the local source-policy checks on Windows.
