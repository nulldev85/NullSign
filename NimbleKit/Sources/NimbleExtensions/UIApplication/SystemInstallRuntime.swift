import Foundation
import ObjectiveC

/// Private Launch Services queries are optional. Missing selectors return no
/// observation; they must never be interpreted as a completed installation.
public enum SystemInstallRuntime {
	public static let installationDidFinish = Notification.Name("NullSign.SystemInstallationDidFinish")
	public struct Observation: Sendable {
		public let progress: ProgressSnapshot?
		public let state: AppState?
		public let hasPublishedProgress: Bool
		public let membership: Bool?
	}

	public static func observation(for identifier: String, includeAppState: Bool) -> Observation {
		let current = progress(for: identifier)
		return Observation(progress: current, state: includeAppState ? appState(for: identifier) : nil,
			hasPublishedProgress: current != nil, membership: nil)
	}

	/// One session per installation attempt. Launch Services can remove the
	/// progress from its lookup before the next poll sees the terminal update.
	public actor ProgressSession {
		private let identifier: String
		private var activeProgress: Progress?

		public init(identifier: String) { self.identifier = identifier }

		public func observation(includeAppState: Bool, deliveryStarted: Bool) -> Observation {
			let published = SystemInstallRuntime.workspace().flatMap {
				SystemInstallRuntime.progressObject(workspace: $0, identifier: identifier, synchronous: true)
			}
			let checkMembership = published == nil && deliveryStarted && includeAppState
			return observe(published, state: includeAppState ? SystemInstallRuntime.appState(for: identifier) : nil,
				deliveryStarted: deliveryStarted, membership: checkMembership ? SystemInstallRuntime.workspaceContainsApp(identifier) : nil)
		}

		func observe(_ published: Progress?, state: AppState?, deliveryStarted: Bool, membership: Bool? = nil) -> Observation {
			if deliveryStarted, let published, published.totalUnitCount > 0 {
				activeProgress = published
			}
			return Observation(progress: (activeProgress ?? published).map(ProgressSnapshot.init),
				state: state, hasPublishedProgress: published != nil, membership: membership)
		}
	}

	public static func observeInstallation(for identifier: String, version: String?) -> InstallationObserver? {
		guard let workspace = workspace() else { return nil }
		return observeInstallation(workspace: workspace, identifier: identifier, version: version)
	}

	static func observeInstallation(workspace: NSObject, identifier: String, version: String?) -> InstallationObserver? {
		guard workspace.responds(to: NSSelectorFromString("addObserver:")),
			workspace.responds(to: NSSelectorFromString("removeObserver:")) else { return nil }
		return InstallationObserver(workspace: workspace, identifier: identifier, version: version)
	}

	public final class InstallationObserver: NSObject, @unchecked Sendable {
		private let workspace: NSObject
		private let identifier: String
		private let version: String?
		private let lock = NSLock()
		private var active = true
		private var armed = false
		private var installed = false
		private var callbacks = 0
		private var lastEvent = "none"
		public var diagnosticState: String {
			lock.lock(); defer { lock.unlock() }
			return "active=\(active) armed=\(armed) installed=\(installed) callbacks=\(callbacks) event=\(lastEvent)"
		}

		fileprivate init(workspace: NSObject, identifier: String, version: String?) {
			self.workspace = workspace
			self.identifier = identifier
			self.version = version
			super.init()
			if let protocolType = objc_getProtocol("LSApplicationWorkspaceObserverProtocol") {
				class_addProtocol(type(of: self), protocolType)
			}
			registration("addObserver:")
		}

		public func arm() { lock.lock(); armed = true; lock.unlock() }
		public var didInstall: Bool {
			lock.lock(); defer { lock.unlock() }
			return installed
		}

		@objc public func applicationsDidInstall(_ applications: NSArray) {
			lock.lock(); callbacks += 1; lock.unlock()
			for case let app as NSObject in applications {
				let bundle = SystemInstallRuntime.object(app, "applicationIdentifier") as? String ?? SystemInstallRuntime.object(app, "bundleIdentifier") as? String
				guard bundle == identifier else { continue }
				if SystemInstallRuntime.boolean(app, "isPlaceholder") == true {
					lock.lock(); lastEvent = "matching-placeholder"; lock.unlock(); continue
				}
				if let actual = SystemInstallRuntime.object(app, "shortVersionString") as? String, let version, actual != version {
					lock.lock(); lastEvent = "version-mismatch:\(actual)"; lock.unlock(); continue
				}
				lock.lock()
				lastEvent = "matching-install"
				let notify = active && armed && !installed
				if notify { installed = true }
				lock.unlock()
				if notify { NotificationCenter.default.post(name: SystemInstallRuntime.installationDidFinish, object: self) }
			}
		}

		public func stop() {
			lock.lock()
			let remove = active
			active = false
			lock.unlock()
			if remove { registration("removeObserver:") }
		}

		private func registration(_ name: String) {
			let selector = NSSelectorFromString(name)
			guard let implementation = workspace.method(for: selector) else { return }
			typealias Register = @convention(c) (AnyObject, Selector, AnyObject) -> Void
			unsafeBitCast(implementation, to: Register.self)(workspace, selector, self)
		}
	}

	public struct ProgressSnapshot: Sendable {
		public let fractionCompleted: Double
		public let isFinished: Bool
		public let isCancelled: Bool
		public let totalUnitCount: Int64
		public let completedUnitCount: Int64
		public let isPaused: Bool

		init(_ value: Progress) {
			fractionCompleted = value.fractionCompleted
			isFinished = value.isFinished
			isCancelled = value.isCancelled
			totalUnitCount = value.totalUnitCount
			completedUnitCount = value.completedUnitCount
			isPaused = value.isPaused
		}
	}

	public struct AppSnapshot: Sendable {
		public let bundlePath: String
		public let version: String?
		public let build: String?
		public let registeredAt: TimeInterval?
	}

	public struct AppState: Sendable {
		public let isAvailable: Bool
		public let app: AppSnapshot?
		public let diagnosticState: String
		init(isAvailable: Bool, app: AppSnapshot?, diagnosticState: String = "unknown") {
			self.isAvailable = isAvailable
			self.app = app
			self.diagnosticState = diagnosticState
		}
	}

	public static func progress(for identifier: String, makeSynchronous: Bool = false) -> ProgressSnapshot? {
		guard let workspace = workspace() else { return nil }
		return progress(workspace: workspace, identifier: identifier, synchronous: makeSynchronous)
	}

	private static func workspace() -> NSObject? {
		let selector = NSSelectorFromString("defaultWorkspace")
		guard let type = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
			class_getClassMethod(type, selector) != nil,
			let workspace = type.perform(selector)?.takeUnretainedValue() as? NSObject else { return nil }
		return workspace
	}

	static func progress(workspace: NSObject, identifier: String, synchronous: Bool) -> ProgressSnapshot? {
		progressObject(workspace: workspace, identifier: identifier, synchronous: synchronous).map(ProgressSnapshot.init)
	}

	private static func progressObject(workspace: NSObject, identifier: String, synchronous: Bool) -> Progress? {
		let selector = NSSelectorFromString("installProgressForBundleID:makeSynchronous:")
		guard workspace.responds(to: selector), let implementation = workspace.method(for: selector) else { return nil }
		// perform(_:with:with:) boxes its arguments as objects. The second
		// argument here is an Objective-C BOOL, so call the correctly typed IMP.
		typealias Query = @convention(c) (AnyObject, Selector, NSString, Bool) -> Unmanaged<AnyObject>?
		let query = unsafeBitCast(implementation, to: Query.self)
		return query(workspace, selector, identifier as NSString, synchronous)?.takeUnretainedValue() as? Progress
	}

	public static func appState(for identifier: String) -> AppState {
		let selector = NSSelectorFromString("applicationProxyForIdentifier:")
		guard let type = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
			class_getClassMethod(type, selector) != nil,
			let proxy = type.perform(selector, with: identifier)?.takeUnretainedValue() as? NSObject else {
			// A fresh bundle may have no proxy yet. Only an explicit negative
			// membership query can prove absence; missing APIs stay unknown.
			if let workspace = workspace(), applicationIsInstalled(workspace: workspace, identifier: identifier) == false {
				return AppState(isAvailable: true, app: nil, diagnosticState: "workspace-confirms-absent")
			}
			return AppState(isAvailable: false, app: nil, diagnosticState: "proxy-unavailable-or-membership-unknown")
		}
		return appState(proxy: proxy)
	}

	static func applicationIsInstalled(workspace: NSObject, identifier: String) -> Bool? {
		let selector = NSSelectorFromString("applicationIsInstalled:")
		guard workspace.responds(to: selector), let implementation = workspace.method(for: selector) else { return nil }
		typealias Query = @convention(c) (AnyObject, Selector, NSString) -> Bool
		return unsafeBitCast(implementation, to: Query.self)(workspace, selector, identifier as NSString)
	}

	public static func workspaceContainsApp(_ identifier: String) -> Bool? {
		workspace().flatMap { applicationIsInstalled(workspace: $0, identifier: identifier) }
	}

	static func appState(proxy: NSObject) -> AppState {
		guard let installed = boolean(proxy, "isInstalled") else { return AppState(isAvailable: false, app: nil, diagnosticState: "missing-installed-selector") }
		if !installed { return AppState(isAvailable: true, app: nil, diagnosticState: "not-installed") }
		guard let placeholder = boolean(proxy, "isPlaceholder") else { return AppState(isAvailable: false, app: nil, diagnosticState: "missing-placeholder-selector") }
		if placeholder { return AppState(isAvailable: true, app: nil, diagnosticState: "placeholder") }
		guard let url = object(proxy, "bundleURL") as? URL, url.isFileURL else { return AppState(isAvailable: false, app: nil, diagnosticState: "missing-bundle-url") }
		let app = AppSnapshot(bundlePath: url.standardizedFileURL.path,
			version: object(proxy, "shortVersionString") as? String,
			build: object(proxy, "bundleVersion") as? String,
			registeredAt: (object(proxy, "registeredDate") as? Date)?.timeIntervalSince1970)
		return AppState(isAvailable: true, app: app, diagnosticState: "installed")
	}

	private static func object(_ instance: NSObject, _ name: String) -> AnyObject? {
		let selector = NSSelectorFromString(name)
		guard instance.responds(to: selector) else { return nil }
		return instance.perform(selector)?.takeUnretainedValue()
	}

	private static func boolean(_ instance: NSObject, _ name: String) -> Bool? {
		let selector = NSSelectorFromString(name)
		guard instance.responds(to: selector), let implementation = instance.method(for: selector) else { return nil }
		typealias Getter = @convention(c) (AnyObject, Selector) -> Bool
		return unsafeBitCast(implementation, to: Getter.self)(instance, selector)
	}
}
