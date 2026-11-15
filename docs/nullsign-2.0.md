# NullSign 2.0 on RyukSign

NullSign 2.0 adopts the internals of RyukSign
(github.com/faroukbmiled/RyukSign, GPL-3.0, itself a fork of claration's
Feather) and keeps NullSign's own work on top: its look, app updates,
self-update, source ("repo") support and Apple TV sideloading. RyukSign's
premium sources are removed. The base is RyukSign at `da1f3c2`, committed
unchanged so every NullSign change is its own diff.

## Plan

1. Identity and users' data (build A, 2.0.0 (53)).
2. NullSign's look: design system, typography, screens, tab bar.
3. NullSign's app updates, self-update and source parsing.
4. Apple TV signing, installing and pairing.

## Build A: identity and users' data

- Name NullSign, bundle ID `com.elmat.NullSign` (widget
  `com.elmat.NullSign.FeatherWidgetExtension`), app group
  `group.com.elmat.NullSign`, version 2.0.0 (53). `nullsign://` links open it
  alongside `feather://`.
- Library migration: both apps keep the Core Data store `Feather` and the same
  Documents folders. The model ships NullSign 1.5.2's version unchanged
  (`Feather.xcdatamodel`) and a current version (`Feather 2.xcdatamodel`):
  RyukSign's model plus NullSign's `AppSourceMetadata`, with
  `originalIdentifier` defaulting to empty so 1.x rows migrate. After loading,
  empty `originalIdentifier`s are set to the bundle identifier.
- RyukSign deleted the store, app folders and certificates when the store
  failed to load. NullSign moves the store into `Documents/Library Backups`
  instead and deletes nothing.
- Premium: the Add Source premium section is removed and redeem, restore and
  recover never contact RyukSign's server. The remaining premium code is
  inert for NullSign users and is deleted in a later build.
- RyukSign's self-update checks NullSign's releases, whose tags never parse as
  a version, so it offers nothing until NullSign's self-update replaces it.
  Featured source, GitHub and About links point at NullSign; Ryuk is credited.
- Opening an IPA from Files: the file is copied into the app off the main
  thread (RyukSign copied it on the main thread, which freezes on large or
  iCloud files), then imported, with an alert naming any failure.
- CI builds RyukSign's project with Xcode 27.1, verifies the bundle ID, name,
  numeric build and extension IDs, and publishes as before. The build no
  longer downloads RyukSign's install certificate; the app fetches it itself.

Kept from RyukSign for now: its install manifest service (falls back to
`api.palera.in`) and install certificate pack are RyukSign-hosted; its
curated repository list loads from RyukSign's GitHub.

Saved signing preferences reset to defaults: RyukSign stores them in a
different format.
