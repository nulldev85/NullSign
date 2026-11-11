# Immediate Install crash investigation — 1.5.1 (41)

The user and testers report NullSign closing immediately after tapping Install
for an app imported manually or from a repository, before progress is visible.
Both routes present `InstallPreviewView`, whose `onAppear` synchronously starts
`BackgroundAudioManager` before any signing result or installer handoff.

That manager connected an `AVAudioSourceNode` to a hardware-backed engine with
`format: nil` and started it without checking the output format. Apple's
[output-node documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine/outputnode)
states that an unavailable output can raise an exception. Swift's `do/catch`
does not catch Objective-C exceptions. This is a concrete unsafe startup path
consistent with the timing, but no device crash backtrace has yet confirmed it
as the reported crash's cause. A crash-report excerpt was requested to confirm
the failing native call. Do not describe the physical-device crash as proven
resolved from code inspection or CI alone.

The candidate repair removes the custom audio-engine graph and real-time render
callback. Background playback uses a muted, looping `AVAudioPlayer` initialized
from a known one-second mono PCM WAV generated in memory. The existing iPhone
playback session category/mixing options and background capability are retained.
Start/stop run on the main queue, repeated starts reuse active playback, stop
releases the player, and normal session/player failures are logged without
preventing the installation screen from opening. This also covers the shared
background-audio helper used by downloads on older iOS versions.

The Install action, signing options, certificates, shared progress, package
verification, system confirmation, browser recovery and app data are unchanged.
No changes are made to the Core Data/signing paths on the basis of speculation.

`Tools/test-background-audio.py` compiles the production WAV/player factory and
manager with Apple's actual AVFoundation on the macOS runner. It verifies the
RIFF/PCM structure and every silent sample, actual decoder format/duration,
muting/looping, and repeated start/stop without a process abort. A headless Mac
may reject playback normally; the test does not claim to reproduce an iPhone
audio route or its AVAudioSession. The ordinary physical Release app build still
compiles the iOS session path, and all earlier regression checks remain required.
Local Windows checks are not execution of these Apple APIs.
