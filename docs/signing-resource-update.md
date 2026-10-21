# NullSign 1.4.0 (29)

This update keeps the current redesign and ports the unreadable-resource fix
from [Zsign 1.1.3](https://github.com/zhlynn/zsign/releases/tag/v1.1.3), upstream
commit `9299685bab7ef99827e06e5dfda93af747386590` / PR #413.

The app still uses the Swift-compatible `khcrysalis/Zsign-Package` submodule at
`6ffe703df73ef9069adacdbb19d571f11a69a801`. This is a targeted backport, not a
claim that the entire package has become the upstream 1.1.3 CLI. Certificate
handling, tweak injection and Swift/Objective-C adapters stay on that fork.

## Signing behavior

An empty resource still receives the correct empty-file hash. When mapping a
file fails, the signer attempts a real read; if that also fails, signing stops
instead of writing an empty-file seal. Both normal and cached resource paths
propagate hashing failure. The iOS handler now checks the native success return,
including failures that do not produce a callback error, and preserves detailed
errors for display. A successful retry clears any previous error.

The checked-in patch and its resulting source hashes are applied by
`python3 Tools/prepare-zsign.py`. It accepts only the pinned base source or the
complete reviewed patched source, and refuses unknown edits. CI, `make iphoneos`
and the shared Xcode scheme prepare the dependency before compiling. Developers
using their own build scheme should run that command before building. The
submodule's two modified source files are intentional; the patch is tracked by
the parent repository rather than by a new dependency fork.

## Signer list layout

The tab root measures the dock and gives each navigation stack an explicit
viewport ending above it. This keeps UIKit-backed List rows inside the visible
area rather than drawing below a flexible sibling. The measured dock height
also follows larger accessibility text, and the full list viewport returns
when the keyboard hides the dock. No device-specific bottom padding or
file-selection behavior changes.

## Validation

`python3 Tools/test-zsign-resources.py` compiles the production C++ signing core
and tests missing resources, broken links, empty and nonempty resources,
ordinary/nested/Unicode filenames, readable links, exact SHA-1/SHA-256 resource
seals, ad-hoc Mach-O signing, and propagation of nested bundle failures. Fixtures
are synthetic; no certificate or private app data is required. CI installs and
selects Homebrew OpenSSL 3 for this native test because the pinned Zsign source
uses ASN.1 structure fields that OpenSSL 4 makes opaque.

`python3 Tools/test-zsign-handler.py` compiles the actual Swift app handler and
its production `Bundle.exec` extension with a controlled engine boundary on
macOS. It covers native failures with and without callback errors, existing
non-strict callback errors, and successful retries for both certificate and
ad-hoc signing.

The GitHub workflow runs both before the existing Release build and IPA checks.
Local Ubuntu validation passed all seven native regressions. Against an isolated
copy of the original dependency, the four failure cases reproduced the bug and
the three valid-signing/hash cases still passed. Fresh patch application,
repeated application, rejection of unknown source edits, the shared scheme XML,
workflow lint, and the existing typography/icon/palette checks were also verified.
Apple SDK compilation and on-device list scrolling/selection remain pending
until that build and device verification complete. Do not infer a build result
from dispatch or poll its status.
