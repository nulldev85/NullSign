import Foundation

@main struct InstallObservationTests {
	static func identity(_ path: String, version: String = "2.0", build: String = "2", date: Double = 1) -> InstalledAppIdentity {
		InstalledAppIdentity(bundlePath: path, version: version, build: build, registeredAt: date)
	}

	static func sample(_ tracker: inout InstallCompletionTracker, at time: Double = 0,
		fraction: Double? = nil, finished: Bool = false, cancelled: Bool = false,
		units: Int64 = 100, app: InstalledAppIdentity? = nil, deliveryStarted: Bool = true) -> InstallCompletionTracker.Update {
		tracker.observe(at: time, fraction: fraction, finished: finished, cancelled: cancelled, totalUnits: units, installed: app, deliveryStarted: deliveryStarted)
	}

	static func main() {
		var tracker = InstallCompletionTracker(baseline: nil, expectedVersion: "2.0")
		precondition(!sample(&tracker).completed)
		precondition(sample(&tracker, app: identity("/new/App.app")).completed,
			"Fast installation with no observable Progress must complete from the new installed record")
		print("PASS fast/no-progress fresh installation uses the actual new installed record")

		tracker = InstallCompletionTracker(baseline: nil, expectedVersion: "2.0", baselineKnown: false)
		precondition(!sample(&tracker, app: identity("/existing/App.app")).completed,
			"An unavailable baseline must not be treated as proof the app was absent")
		_ = sample(&tracker, fraction: 0)
		precondition(sample(&tracker, finished: true).completed)
		print("PASS unavailable initial app lookup requires genuine finished progress, never assumed fresh installation")

		let old = identity("/old/App.app")
		tracker = InstallCompletionTracker(baseline: old, expectedVersion: "2.0")
		precondition(!sample(&tracker, at: 120, app: old).completed,
			"Already-installed same-version apps are not success for a new attempt")
		precondition(sample(&tracker, app: identity("/replacement/App.app")).completed)
		tracker = InstallCompletionTracker(baseline: old, expectedVersion: "2.0")
		precondition(sample(&tracker, app: identity("/old/App.app", date: 2)).completed)
		print("PASS existing app is insufficient; same-version replacement or new registration completes")

		tracker = InstallCompletionTracker(baseline: old, expectedVersion: "3.0")
		precondition(!sample(&tracker, app: identity("/replacement/App.app", version: "2.0")).completed)
		precondition(sample(&tracker, app: identity("/replacement/App.app", version: "3.0")).completed)
		print("PASS available installed version must match the requested version")

		tracker = InstallCompletionTracker(baseline: nil, expectedVersion: nil)
		precondition(!sample(&tracker, fraction: 1, finished: true, deliveryStarted: false).completed)
		precondition(!sample(&tracker, app: identity("/new/App.app"), deliveryStarted: false).completed)
		precondition(!sample(&tracker, fraction: 1, finished: true).completed, "A stale already-finished Progress is not this attempt")
		precondition(!sample(&tracker, fraction: 0, finished: true, units: 0).completed)
		_ = sample(&tracker, fraction: 0)
		precondition(sample(&tracker, fraction: 0.6, finished: true).completed)
		tracker = InstallCompletionTracker(baseline: nil, expectedVersion: nil)
		precondition(!sample(&tracker, fraction: 1, finished: true, cancelled: true).completed)
		print("PASS delivery and active-to-finished progress required; stale/empty/cancelled progress never completes")

		tracker = InstallCompletionTracker(baseline: old, expectedVersion: "2.0")
		precondition(!sample(&tracker, fraction: 0.4, app: old).completed)
		precondition(!sample(&tracker, at: 1, app: old).completed,
			"A vanished Progress object alone could also mean cancellation or failure")
		precondition(sample(&tracker, at: 2, app: identity("/installed/App.app")).completed)
		print("PASS disappearing Progress never manufactures success")

		tracker = InstallCompletionTracker(baseline: old, expectedVersion: "2.0")
		precondition(sample(&tracker, fraction: 0.4, app: old).progress == 0.4)
		let stalled = sample(&tracker, at: 16, fraction: 0.4, app: old)
		precondition(!stalled.completed && stalled.progress == nil)
		let unresolved = sample(&tracker, at: 31, fraction: 0.4, app: old)
		precondition(!unresolved.completed && unresolved.progress == nil)
		precondition(sample(&tracker, at: 32, app: identity("/installed/App.app")).completed)
		print("PASS stale percentage becomes indeterminate without timer-based success; later installation still completes")

		tracker = InstallCompletionTracker(baseline: nil, expectedVersion: nil)
		for fraction in [Double.nan, .infinity, -.infinity] {
			let update = sample(&tracker, fraction: fraction)
			precondition(!update.completed && update.progress == nil)
		}
		precondition(sample(&tracker, fraction: -2).progress == 0)
		precondition(sample(&tracker, fraction: 5).progress == 0.99)
		print("PASS nonfinite and out-of-range progress cannot show false completion")
		tracker = InstallCompletionTracker(baseline: old, expectedVersion: "2.0", baselineKnown: false)
		precondition(!tracker.observe(at: 1, fraction: nil, finished: false, cancelled: false, totalUnits: 0, installed: old, deliveryStarted: false, installEvent: true).completed)
		precondition(tracker.observe(at: 2, fraction: nil, finished: false, cancelled: false, totalUnits: 0, installed: old, installEvent: true).completed)
		print("PASS matching installed event confirms same-version reinstall with unavailable progress and unchanged cached proxy")
	}
}
