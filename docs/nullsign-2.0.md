# NullSign 2.0 on RyukSign

NullSign 2.0 adopts the internals of RyukSign
(github.com/faroukbmiled/RyukSign, GPL-3.0, itself a fork of claration's
Feather) and keeps NullSign's own work on top: its look, app updates,
self-update, source ("repo") support and Apple TV sideloading. RyukSign's
premium sources are removed. The base is RyukSign at `da1f3c2`, committed
unchanged so every NullSign change is its own diff.

## Plan

1. Identity and users' data (build A, 2.0.0 (53)).
2. NullSign's look: design system, typography, screens, tab bar (build B,
   2.0.0 (55)).
3. NullSign's app updates, self-update and source parsing (build C,
   2.0.0 (56)).
4. Apple TV signing, installing and pairing (build D, 2.0.0 (57)).

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
- NullSign comes with its own source, Null's Apps
  (`nulldev85/AppSource/main/apps.json`), added once on first launch. If a
  1.x library already has it (saved under its URL, lowercased) nothing is
  added; once removed, it isn't added again.
- Opening an IPA from Files: the file is copied into the app off the main
  thread (RyukSign copied it on the main thread, which freezes on large or
  iCloud files), then imported, with an alert naming any failure.
- CI builds RyukSign's project with Xcode 27.1, verifies the bundle ID, name,
  numeric build and extension IDs, and publishes as before. The build no
  longer downloads RyukSign's install certificate; the app fetches it itself.

Kept from RyukSign: its install manifest service (falls back to
`api.palera.in`) and install certificate pack are RyukSign-hosted. Its
curated repository list was used until build C.

Saved signing preferences reset to defaults: RyukSign stores them in a
different format.

## Build B: NullSign's look

- NullSign 1.5.2's design system is copied in unchanged
  (`Views/Common/NullSign`, `SourceDesign.swift`, rounded fonts, platform
  badges, version labels): charcoal canvas, NullSign blue `#0094FF`, cards
  and SF Rounded. As in NullSign 1.x the app is always dark and always
  NullSign blue, so Appearance has no light/dark or accent color choice.
- Colors: the app's accent color asset is NullSign blue, and RyukSign's
  system reds, oranges, greens, blues and the expiration colors use
  NullSign's danger, warning, success and accent instead.
- NullSign's app icon and in-app glyph replace RyukSign's. RyukSign's
  alternate icons (Feather and RyukSign artwork) and its donation card are
  removed, along with the alternate icons' artwork.
- Tab bar: Apps, Signer and Settings, with NullSign's symbols. RyukSign's
  Tweaks tab is hidden by default and can be shown in Settings > Tab Bar.
  The update count badge sits on Signer, where updates are listed.
- Signer: NullSign's layout (overview, signing identity card, search, All /
  Signed / Imported / Updates filter with counts, app cards with Install,
  Sign or Update) on RyukSign's library: selection with batch Install, Sign,
  Sign & Install and Delete, drag to reorder, the update picker and
  auto-update.
- Apps: NullSign's catalog layout (All Apps card, Favorites, Repositories,
  repository cards with icon, host and app count) with RyukSign's favorites,
  hide-from-All, sorting, selection and delete.
- Settings: NullSign's identity card and card sections (Signing, App, Files,
  Maintenance, About) over RyukSign's settings screens.
- Install: RyukSign's install card (the pulsing icon filled by a pie wedge
  as it installs, cancel, the queued-apps row) in NullSign's colors.
- Every other screen gets the charcoal page, grouped rows on NullSign's
  surface colour and rounded type: NimbleKit's `NBList` and `NBSection` carry
  the theme, and RyukSign's own lists and forms use `nullSignPage()`.
- User-facing text says NullSign where it named RyukSign. Settings keys, the
  backup file type and the RyukSign-hosted SSL option keep their names.

## Build C: updates, self-update and sources

- Source parsing: AltSourceKit's repository parser is NullSign 1.x's. One
  malformed app, version or news item no longer hides a whole source, icons
  under other common keys (`icon`, `image`, `logo`, snake case) are found,
  and versions read with their build, "2.0.0 (56)". RyukSign's fallback to an
  app's identifier when its name is blank is kept. RyukSign's fetcher stays
  (gzip, timeouts, logging) with NullSign's messages: a 404 explains a source
  that's still uploading, and a parsing failure names the field that broke.
- App updates keep RyukSign's checker (grouping copies of an app, picking a
  source, pins, skipped updates, auto-update) with NullSign's rule: when two
  releases share a version, the newer build is the update. Downloads now
  record the source's build with the version. Update labels, source app
  details and version history show builds, and Install Cleanup treats an
  older build of the same version as older.
- Self-update is NullSign's: releases come from NullSign's own app source
  (`nulldev85/AppSource`), compared by version and build. Updating
  downloads the release, signs it on this device with the certificate chosen
  in Settings > Updates and hands it to the install queue, which uses the
  installation method in Settings. RyukSign's remote signing server and its
  pairing-only path are gone. NullSign checks on launch and again when it
  comes back, at most every six hours. Updates, All Versions and the update
  sheet show builds; ignored versions are kept per build.
- From 2.0.0 (58), as in NullSign 1.x: while a newer NullSign is out, a
  "NullSign X Is Out" card sits at the top of the Signer with a one-tap
  Update (tap the card for what's new), and NullSign's own update counts in
  the Signer tab's badge (once, even if the library also lists a NullSign
  IPA). Opening the Signer checks at most every six hours, and Check for
  Updates checks NullSign along with the library. The launch prompt
  remains. Once the update installs, the card, badge and prompt stop
  offering it (NullSign normally restarts as the new version; if it keeps
  running, the installed release is remembered until it does), and the
  signed copy made for the update is removed from the Signer on the next
  launch.
- Add Source is NullSign's layout: a URL with Paste, and importing and
  copying source lists. The only featured source is NullSign's own, shown
  only after someone removes it so it can be added back. RyukSign's curated
  "Ryuk Repos" list and the third-party featured sources are gone.
- Premium is deleted: RyukSign's premium manager, key redemption, device
  identity vault, filters, auth headers and the premium-only settings.
  Hiding a source from All Apps moved to `SourceExclusions`.
- About is NullSign 1.x's: version and build, NullSign's own updates,
  Feather's credits (claration and contributors, Nyasami, llsc12) and the
  GPL v3 license with a link to NullSign's source.

## Build D: Apple TV

- IDeviceKit is NullSign's fork (`nulldev85/IDeviceKit` at `a8e66f5`):
  RyukSign's pinned `837cf1e` plus NullSign 1.x's Apple TV commits
  (persistent pairing transport over Wi-Fi, hostname and IPv6 discovery,
  six-digit PIN handshake, monotonic install progress) and idevice 0.1.66.
  Zsign stays at RyukSign's pin, which already contains NullSign 1.x's.
- Pairing: Settings > Apple TV (also in Installation) finds Apple TVs on the
  same Wi-Fi, pairs with the six-digit code the TV shows and keeps the
  pairing; Forget removes it, and Reset All forgets it too. No VPN, computer
  or pairing file is needed. Info.plist declares the remote pairing Bonjour
  services and the local network prompt.
- Installing: tvOS apps install on the paired Apple TV over Wi-Fi, whatever
  installation type iPhone apps use. NullSign checks for a paired, reachable
  Apple TV before packaging, then points the device connection back at the
  iPhone when it's done. The install card shows "On Apple TV" instead of Open.
- Signing: iPhone apps keep the certificate selected in Certificates. Apple TV
  apps use a certificate whose provisioning profile includes tvOS (the one
  last used for tvOS, else the selected one if it covers tvOS, else the first
  that does), in Sign, batch signing and auto-sign. Signing a tvOS app with a
  profile that lacks tvOS stops with an explanation, and certificates that
  cover tvOS carry a tvOS tag.
- Icons: NullSign 1.x's icon renderer reads Apple TV apps' layered icons from
  their asset catalogs, renders icons one at a time, and keeps RyukSign's
  icon cache.
- NullSign can install its own update with the Server installation type
  again (RyukSign refused), as NullSign 1.x did; build C's self-update needs it.
