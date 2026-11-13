# Install progress and visible import failures — 1.5.2 (45)

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
