import Foundation

/// A changed, installed bundle is evidence of this attempt. Merely finding an
/// app that was already installed before the prompt is never completion.
struct InstalledAppIdentity: Equatable, Sendable {
	let bundlePath: String
	let version: String?
	let build: String?
	let registeredAt: TimeInterval?
}

struct InstallCompletionTracker {
	struct Update {
		let completed: Bool
		let progress: Double?
	}

	let baseline: InstalledAppIdentity?
	let baselineKnown: Bool
	let expectedVersion: String?
	private var lastFraction: Double?
	private var lastChange: TimeInterval = 0
	private var sawActiveProgress = false

	init(baseline: InstalledAppIdentity?, expectedVersion: String?, baselineKnown: Bool = true) {
		self.baseline = baseline
		self.baselineKnown = baselineKnown
		self.expectedVersion = expectedVersion
	}

	mutating func observe(
		at elapsed: TimeInterval, fraction: Double?, finished: Bool,
		cancelled: Bool, totalUnits: Int64, installed: InstalledAppIdentity?, deliveryStarted: Bool = true, installEvent: Bool = false
	) -> Update {
		guard deliveryStarted else { return Update(completed: false, progress: nil) }
		if installEvent { return Update(completed: true, progress: 1) }
		let versionMatches = expectedVersion == nil || installed?.version == nil
			|| installed?.version == expectedVersion
		if baselineKnown, let installed, installed != baseline, versionMatches {
			return Update(completed: true, progress: 1)
		}
		// An empty 0/0 Progress can be "finished" before installation starts.
		if !finished, !cancelled, totalUnits > 0, let fraction, fraction.isFinite {
			sawActiveProgress = true
		}
		if finished, !cancelled, totalUnits > 0, sawActiveProgress {
			return Update(completed: true, progress: 1)
		}
		let measured = fraction.flatMap { $0.isFinite ? min(0.99, max(0, $0)) : nil }
		if let measured, !cancelled, measured != lastFraction {
			lastFraction = measured
			lastChange = elapsed
		}
		let stale = elapsed - lastChange >= 15
		return Update(
			completed: false,
			progress: cancelled || stale ? nil : measured
		)
	}
}
