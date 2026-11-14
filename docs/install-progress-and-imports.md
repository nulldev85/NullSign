# Install progress and library reliability — 1.5.2 (52)

## Builds 51–52: iPhone Duo

A tester reported NullSign not filling iPhone Duo's inner display and asked
for its navigation on the right.

Full screen. Apple's iPhone Duo tech talk: apps built with the iOS 27.1 SDK
(Xcode 27.1) extend to the edges of the inner display; older SDKs get a
familiar-size window. NullSign was built by `macos-latest` with Xcode 26.6 and
the iOS 26.5 SDK. CI now runs on GitHub's `xcode-27` image (macOS 27) with
Xcode 27.1 pinned.

Navigation (build 52). The HIG ("Designing for iPhone Duo", Vertical controls)
places toolbars, navigation controls and the tab bar together in one column on
the side: on the closed outer display (the right, aligned with the camera) and
on the inner display in landscape, along an app's outer edge in Split View; the
inner display in portrait keeps horizontal bars. A custom bar cannot join that
column, and the HIG says not to override the placement. NullSign's custom dock
is replaced by the system `TabView` on every device, keeping the Signer badge
and tap-again-to-root. Build 51's size-class rail is withdrawn: it placed the
rail on the inner display in portrait and missed the outer display.

Toolbar items. The system leaves text-only items in a horizontal bar and uses
symbols on the side. `toolbarVerticalEdge` (iOS 27.1) is published to each tab
as `nullSignVerticalBars`; Library's Select and Check for Updates show a symbol
and title only when bars are vertical, keeping their text elsewhere. Import,
Add Source and Source Options carry titles as well as symbols for overflow.

Also: action sheets without an anchor are centered when UIKit presents them as
popovers in a regular-width window, Reset chooses alert or sheet by width
class instead of device idiom, and the source news header no longer reads
`UIScreen.main`, which Apple says is ambiguous on a two-display device.

Device verification on iPhone Duo is pending.

## Build 50

The user confirmed build 49 on the phone. Build 50 adds two requested changes.

PPQ protection is removed: the Signing Defaults toggle, the suffix editor, the
per-sign toggle and the code that appended the suffix to bundle identifiers.
Saved options decode without the removed keys, so other settings are kept, and
anyone who had it on now signs under the app's own identifier. The certificate
screens still show whether a certificate reports a PPQ check.

Users could not add the AIOStreams source
(`github.com/wizaarddlabs/aiostreams-ios/releases/latest/download/altstore.json`).
Its current file follows GitHub's redirects and decodes under the AltSourceKit
model on inspection, so no decoder change was made. The source publishes a
release about hourly, and `releases/latest` can briefly point at a release
whose `altstore.json` is not uploaded yet; GitHub then answers 404 with an HTML
page, which NullSign reported as invalid JSON. Source fetches now report a
non-2xx HTTP status instead. Adding the source on a phone is still unverified.

## Build 49

A device trace showed progress advancing through 62, 76 and 92 units of 100.
One second later the system lookup returned no job. The observer received no
callbacks and the proxy continued reporting the app absent through the final
sample 47 seconds later.

Each install now retains its active Foundation progress object and checks it
after the system removes the lookup entry. A finished or cancelled object can
therefore still reach the card. For fresh installs, a separate membership lookup
before handoff and after the active job disappears can confirm a newly installed
target. An unchanged or unknown membership cannot confirm a reinstall.

The native regressions exercise a late finish, cancellation, a clean retry
and missing or unchanged membership. Device verification is pending.

## Build 48

Delete now acts directly from the row menu, swipe action, or bulk confirmation.
The library retains the selection and reports a failed save so the user can retry.
Imported iPhone and iPad apps can supply their own primary icon as a PNG. The
loader checks the package's declared files and retains the system renderer for
catalog icons and styled appearances. Existing library copies use the same lookup.

Builds 47 and 48 capture the same install signals. The exported trace informed build 49.

## Build46 still stalls at97 percent

The user reports that the simplified card still stops at97%. Completion is NOT
fixed. Build47 is a diagnostic capture, not another claimed completion repair.
It retains build46's exact completion decisions and simple presentation.

The existing Settings → Diagnostics → Export Diagnostic Log now captures
attempt identifiers, target/expected version, delivery phase, raw fraction,
completed/total units, finished/cancelled/paused flags, app-lookup availability
and reason, record-change/version/build information, observer availability,
arming/callback/filter results and the signal that actually confirms completion.
Records are emitted on changed state or every15seconds while unchanged, under
the existing bounded log. No certificate secrets or bundle-container paths are
added. Timestamp formatting is serialized with the log writer.

Need one reproduction with this build and its exported log before choosing the
next behavioral correction. No percentage threshold, delay or successful payload
transfer substitutes for actual installation completion. Native build/execution
and device diagnostic capture remain pending.

## Final presentation requested by the user

The user rejected the extra waiting message, Close action, bouncing fallback
and automatic dismissal. Build46 restores the original presentation: a
determinate progress bar, the normal Installing label, then Completed with a
full bar and checkmark on confirmed success. The card retains the original
Open/Done action. It does not require Close or disappear automatically. Missing
measurements retain the last measured progress rather than starting a bouncing
animation. Completion still comes from the underlying installation signals;
elapsed time or finishing payload transfer cannot fabricate success.

The completion-event, off-UI-thread observation and packaging responsiveness
work remain underneath. This supersedes the build44/45 presentation described
below. Native/device confirmation remains pending; no success is claimed merely
from changing the UI.

## Device feedback on build44

The user supplied a screenshot showing Facebook installed while the new
indeterminate "Waiting for iOS" card remained. Build44 did not resolve this on
that phone. The user also reports the whole process still takes longer; its
dominant duration has not yet been measured.

Build45 registers a workspace installation observer before handoff, arms it when
the payload is requested, and accepts only a matching installed callback (not
placeholders or another bundle/version). This event can complete a same-version
reinstall even with unavailable progress and an unchanged cached proxy. Observer
removal is idempotent on retry, dismissal, error and success. Notification delivery
reaches the UI independently of background status queries. Native fixture tests
cover registration, callback filtering, arming and teardown; actual device callback
delivery remains pending testing.

Confirmed success shows completion briefly then dismisses the card. Combine's
published status is handled from the received value, not the old property during
willSet. If iOS supplies no confirmation, Close only dismisses an indeterminate
post-transfer card; it does not manufacture success or100 percent.

Repeated queries now run off the UI thread, with app-record checks every third
one-second sample. Packaging uses user-initiated priority and coalesces callbacks
to at most101 percentage milestones instead of queuing a UI task for every ZIP
callback. Saved compression, signing, certificate, ElleKit and verification settings
are retained. Staging and packaging durations are recorded for real-device timing.
No measured whole-process speedup is claimed before testing.

Primary callback declaration: [workspace install observer](https://github.com/mineek/MuffinStore/blob/main/CoreServices.h).

Users report that installation succeeds while NullSign's bar remains near
40/60 percent. They also report that selecting some IPAs using Import from Files
briefly flashes, leaves NullSign running and never adds the selected app.

## Installation observation

The old iPhone observation loop started only after the payload stream's success
callback. It also required a positive fraction before recognizing completion.
A fast/cached installation can finish before this loop begins; a missing progress
object then becomes zero forever. The private Objective-C progress method was
also called through perform(_:with:with:), even though its second parameter is
a BOOL rather than an object.

Observation now captures the installed app's baseline before opening the system
installer and starts immediately. The bridge checks selector availability and
calls the progress method with a correctly typed BOOL argument. It reads real
Foundation Progress finished/cancelled/unit-count state and queries an installed,
non-placeholder app record. A new/replaced bundle path, version/build or
registration relative to the baseline can confirm installation even if the
progress object was never observed. An available version must match the target.
An app already installed before this attempt does not count as success. An
unavailable initial app lookup is kept distinct from a confirmed absent app;
it disables record-change completion rather than assuming a fresh installation.
When no proxy exists, an explicit negative workspace membership query can establish
that the app was absent. A missing membership selector remains unknown.

Completion is gated on iOS requesting the payload. Finished progress must follow
an observed active object; an already-finished cached object is not this attempt.
An empty finished 0/0 object, cancelled progress, elapsed time, URL acceptance
and disappearance of progress alone cannot mark success. Missing or unchanged
progress switches to an indeterminate indicator; after 15 seconds without new
measurements it stops displaying a stale percentage. The card keeps observing
and can still show actual completion. It asks users to keep NullSign open when
iOS cannot provide a percentage. No timer completes the install or fabricates
100 percent. The Apple TV proxy and self-update handoff retain their paths.

HTTP manifest/range re-requests cannot move the server's status backwards from
installing to transfer, or replace a terminal failure/success. Retry still resets
the state through the existing resetProgress method.

## Imports

Import failures were returned by FR but consumed with only haptic feedback.
The download row was removed on both success and failure, and background progress
was set to 100 percent even for failure. The Files picker also did not explicitly
clear its SwiftUI presentation flag when selection/cancellation completed.

The actual import operation now supplies readable file-read, unpacking or
library-addition context while preserving the underlying error. Failures remain
in the shared download header until dismissed, including multiple-file and source
imports; a failure stops the background task as failure. Successful imports still
leave the header only after their database callback. Failed rows do not keep the
background audio helper running. The picker explicitly ends its presentation.
Download progress is capped below 100 until the database callback succeeds, so
finishing extraction cannot prematurely complete a failed background import.

The importer copies files under balanced security-scope access and a real
NSFileCoordinator read on Apple platforms, allowing providers to coordinate file
availability. Shared Open in NullSign imports use the same visible result and no
longer acquire an unbalanced extra scope. Original archives and saved options are
preserved; failed staging/library directories are cleaned by the import operation.

The particular failing IPAs have not been supplied and their rejection reason is
not confirmed. This fixes the silent error path and coordinates file access; it
does not claim that every unsupported/corrupt archive can now be imported. If a
test IPA still fails, its retained error row provides the next diagnostic.

## Verification

Mandatory macOS regressions exercise the production completion tracker and
Objective-C bridge in both -Onone and -O: fresh installs with no progress,
same-version replacement, unchanged pre-existing apps, target-version mismatch,
empty/finished/cancelled progress, vanished/stale progress, later completion,
nonfinite fractions, real BOOL argument dispatch, missing selectors and placeholder
records, and the real observable download model's committed-import gate. The
bridge boundary uses controlled NSObject providers with actual Apple
Foundation/Objective-C; it is not execution of private iPhone Launch Services.

The existing status tests now compile the actual pinned IDeviceKitten status
model rather than a replacement model, including terminal/late-request checks.
The real pinned Zip import suite now executes the production import operation:
33 valid concurrent IPA/TIPA fixtures, four isolated corrupt/missing-app/invalid
metadata/database failures, byte-preserving coordinated copy, unreadable input,
error-stage propagation and cleanup/original-file preservation.

All existing native signing/certificate/ElleKit/IPA gates, the 45-minute bound,
manual draft-only delivery and main-only public publication remain mandatory.
Windows has no Swift or Apple SDK: these new native checks, the app build and
affected-device behavior remain pending the manual candidate build and testing.

References: [Apple document picker callback](https://developer.apple.com/documentation/uikit/uidocumentpickerdelegate/documentpicker(_:didpickdocumentsat:)),
[coordinated access](https://developer.apple.com/documentation/uikit/providing-access-to-directories),
[security scopes](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource()),
[Progress.isFinished](https://developer.apple.com/documentation/foundation/progress/isfinished),
[Launch Services proxy declarations](https://github.com/theos/headers/blob/master/MobileCoreServices/LSApplicationProxy.h).
[Workspace runtime declarations](https://github.com/nst/iOS-Runtime-Headers/blob/master/Frameworks/CoreServices.framework/LSApplicationWorkspace.h).
