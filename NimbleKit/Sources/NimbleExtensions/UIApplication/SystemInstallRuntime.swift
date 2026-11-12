import Foundation
import ObjectiveC

/// Private Launch Services queries are optional. Missing selectors return no
/// observation; they must never be interpreted as a completed installation.
public enum SystemInstallRuntime {
	public struct ProgressSnapshot: Sendable {
		public let fractionCompleted: Double
		public let isFinished: Bool
		public let isCancelled: Bool
		public let totalUnitCount: Int64
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
		let selector = NSSelectorFromString("installProgressForBundleID:makeSynchronous:")
		guard workspace.responds(to: selector), let implementation = workspace.method(for: selector) else { return nil }
		// perform(_:with:with:) boxes its arguments as objects. The second
		// argument here is an Objective-C BOOL, so call the correctly typed IMP.
		typealias Query = @convention(c) (AnyObject, Selector, NSString, Bool) -> Unmanaged<AnyObject>?
		let query = unsafeBitCast(implementation, to: Query.self)
		guard let value = query(workspace, selector, identifier as NSString, synchronous)?.takeUnretainedValue() as? Progress else { return nil }
		return ProgressSnapshot(fractionCompleted: value.fractionCompleted,
			isFinished: value.isFinished, isCancelled: value.isCancelled, totalUnitCount: value.totalUnitCount)
	}

	public static func appState(for identifier: String) -> AppState {
		let selector = NSSelectorFromString("applicationProxyForIdentifier:")
		guard let type = NSClassFromString("LSApplicationProxy") as? NSObject.Type,
			class_getClassMethod(type, selector) != nil,
			let proxy = type.perform(selector, with: identifier)?.takeUnretainedValue() as? NSObject else {
			// A fresh bundle may have no proxy yet. Only an explicit negative
			// membership query can prove absence; missing APIs stay unknown.
			if let workspace = workspace(), applicationIsInstalled(workspace: workspace, identifier: identifier) == false {
				return AppState(isAvailable: true, app: nil)
			}
			return AppState(isAvailable: false, app: nil)
		}
		return appState(proxy: proxy)
	}

	static func applicationIsInstalled(workspace: NSObject, identifier: String) -> Bool? {
		let selector = NSSelectorFromString("applicationIsInstalled:")
		guard workspace.responds(to: selector), let implementation = workspace.method(for: selector) else { return nil }
		typealias Query = @convention(c) (AnyObject, Selector, NSString) -> Bool
		return unsafeBitCast(implementation, to: Query.self)(workspace, selector, identifier as NSString)
	}

	static func appState(proxy: NSObject) -> AppState {
		guard let installed = boolean(proxy, "isInstalled") else { return AppState(isAvailable: false, app: nil) }
		if !installed { return AppState(isAvailable: true, app: nil) }
		guard let placeholder = boolean(proxy, "isPlaceholder") else { return AppState(isAvailable: false, app: nil) }
		if placeholder { return AppState(isAvailable: true, app: nil) }
		guard let url = object(proxy, "bundleURL") as? URL, url.isFileURL else { return AppState(isAvailable: false, app: nil) }
		let app = AppSnapshot(bundlePath: url.standardizedFileURL.path,
			version: object(proxy, "shortVersionString") as? String,
			build: object(proxy, "bundleVersion") as? String,
			registeredAt: (object(proxy, "registeredDate") as? Date)?.timeIntervalSince1970)
		return AppState(isAvailable: true, app: app)
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
