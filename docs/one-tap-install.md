# One-tap installation — NullSign 1.5.0 (40)

After importing an IPA from Files, a URL or a repository, press **Install** in
the Library. Imported apps use the saved platform-compatible certificate and
signing options; already signed apps go straight to packaging. The same card
and progress bar remain visible through preparation, signing, verification,
packaging, manifest delivery, payload delivery and installation. App Actions →
Sign still provides customization and signing without installing.

The installer receives the exact signed row created by that operation, fetched
by the signing handler's UUID. It does not select the newest app globally or
use the legacy post-sign notification. Identifier/name mappings and PPQ defaults
match the customization screen. The delete-after-sign preference applies only
after a verified signed copy is available; signing errors and cancelled handoffs
preserve the original.

The normal iPhone route opens the `itms-services` URL directly instead of
automatically presenting Safari and its additional **Open** handoff. iOS still
owns its **Install** confirmation; this change does not bypass it. URL acceptance
does not count as installation success. If iOS rejects the URL or has not fetched
the manifest after 15 seconds, **Continue in Browser** exposes the previous
browser route as recovery without signing or packaging again. This recovery is
deliberate because direct URL opens have previously been silently rejected.
The existing Wi-Fi payload route, retired-certificate migration, Apple TV
installation proxy and self-update handoff remain in use.

Signing progress uses actual handler milestones, followed by the existing
measured packaging and native installation progress. The signing portion reserves
30% of the bar so packaging does not restart it at zero. No timer simulates work
or marks installation complete. Errors stay in the card with **Retry**; a
packaging/install retry reuses an already prepared signed copy. Dismissing the
card cancels the handoff, including after a currently executing native signing
call eventually finishes.

`Tools/test-one-tap-install.py` compiles the production preparation and URL/progress
helpers against a controlled signing/storage boundary on the macOS build runner.
It checks imported/signed apps, exact result identity, certificate failures and
platform choice, signing options, deletion, cancellation, nested URL encoding and
progress continuity. It also compiles the production status presentation extension
against the installer boundary, checking that failure and URL acceptance never
display success. The existing native signing/import tests and physical
Release IPA build remain mandatory. Windows source/configuration checks are not
an iOS execution test; actual system confirmation and device behavior need the
manual IPA test.

Primary API references:

- [UIApplication.open(_:options:completionHandler:)](https://developer.apple.com/documentation/uikit/uiapplication/open(_:options:completionhandler:))
- [Apple wireless in-house installation and manifests](https://support.apple.com/guide/deployment/distribute-proprietary-in-house-apps-depce7cefc4d/web)
