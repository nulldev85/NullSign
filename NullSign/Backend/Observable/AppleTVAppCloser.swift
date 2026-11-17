//
//  AppleTVAppCloser.swift
//  NullSign
//

import Darwin
import Foundation
import IDevice
import IDeviceSwift

/// tvOS won't swap in a new copy of an app while the old one is still open
/// or sitting suspended in the background, so the install just sits at
/// "Installing". Closing the app first, the way you would from the Apple TV's
/// app switcher, lets the install go through.
enum AppleTVAppCloser {
	/// The service that closes apps only exists on an Apple TV that has
	/// Apple's developer tools mounted (Xcode does this). Once a TV says it
	/// doesn't have it, NullSign stops asking until it's next launched.
	private static let _state = _State()
	static var mayBeAvailable: Bool { !_state.isUnavailable }

	/// Closes every running copy of `bundleID` (and its extensions) on the
	/// Apple TV NullSign is currently pointed at. When `cycleIfIdle` is set and
	/// nothing is running, the app is opened in the background and closed
	/// right away, which is what un-sticks a stalled install by hand.
	/// Best effort: gives up quietly after `timeout` seconds.
	@discardableResult
	static func close(_ bundleID: String, cycleIfIdle: Bool = false, timeout: TimeInterval = 12) async -> Int {
		await AppleTVLink.run(timeout: timeout, fallback: 0) { adapter, handshake in
			_close(bundleID, adapter: adapter, handshake: handshake, cycleIfIdle: cycleIfIdle)
		}
	}

	private final class _State: @unchecked Sendable {
		private let _lock = NSLock()
		private var _unavailable = false

		var isUnavailable: Bool {
			_lock.lock()
			defer { _lock.unlock() }
			return _unavailable
		}

		func markUnavailable() {
			_lock.lock()
			_unavailable = true
			_lock.unlock()
		}
	}

	private static func _close(_ bundleID: String, adapter: OpaquePointer, handshake: OpaquePointer, cycleIfIdle: Bool) -> Int {
		var service: OpaquePointer?
		if let error = app_service_connect_rsd(adapter, handshake, &service) {
			if (error.pointee.message.map { String(cString: $0) } ?? "").contains("ServiceNotFound") {
				_state.markUnavailable()
				FileLogger.log("Apple TV can't close apps without developer tools mounted. It offers: \(_serviceNames(handshake))", category: "install")
				idevice_error_free(error)
			} else {
				_ = AppleTVLink.ok(error, "open app service")
			}
			return 0
		}
		guard let service else { return 0 }
		defer { app_service_free(service) }

		guard let appPath = _installedPath(of: bundleID, service: service) else {
			// Not installed yet, so there's nothing to close.
			return 0
		}

		var closed = _killProcesses(under: appPath, service: service)
		if closed == 0, cycleIfIdle {
			var response: UnsafeMutablePointer<LaunchResponseC>?
			let argv: [UnsafePointer<CChar>?] = [nil]
			let launched = argv.withUnsafeBufferPointer { argvBuffer in
				bundleID.withCString { id in
					AppleTVLink.ok(app_service_launch_app(service, id, argvBuffer.baseAddress, 0, 1, 1, nil, &response), "open in background")
				}
			}
			if launched, let response {
				let pid = response.pointee.pid
				app_service_free_launch_response(response)
				if _kill(pid, service: service) { closed = 1 }
			}
		}
		FileLogger.log("closed \(closed) running copies of \(bundleID) on Apple TV", category: "install")
		return closed
	}

	/// The services the Apple TV offers, for the log.
	private static func _serviceNames(_ handshake: OpaquePointer) -> String {
		var list: UnsafeMutablePointer<CRsdServiceArray>?
		guard rsd_get_services(handshake, &list) == nil, let list else { return "?" }
		defer { rsd_free_services(list) }
		let services = UnsafeBufferPointer(start: list.pointee.services, count: Int(list.pointee.count))
		return services.compactMap { $0.name.map { String(cString: $0) } }.sorted().joined(separator: ", ")
	}

	private static func _installedPath(of bundleID: String, service: OpaquePointer) -> String? {
		var apps: UnsafeMutablePointer<AppListEntryC>?
		var count: UInt = 0
		guard AppleTVLink.ok(app_service_list_apps(service, 0, 1, 1, 0, 0, &apps, &count), "list apps"), let apps else { return nil }
		defer { app_service_free_app_list(apps, count) }

		for entry in UnsafeBufferPointer(start: apps, count: Int(count)) {
			guard let id = entry.bundle_identifier, String(cString: id) == bundleID, let path = entry.path else { continue }
			return _normalized(String(cString: path))
		}
		return nil
	}

	private static func _killProcesses(under appPath: String, service: OpaquePointer) -> Int {
		var processes: UnsafeMutablePointer<ProcessTokenC>?
		var count: UInt = 0
		guard AppleTVLink.ok(app_service_list_processes(service, &processes, &count), "list processes"), let processes else { return 0 }
		let prefix = appPath.hasSuffix("/") ? appPath : appPath + "/"
		let pids = UnsafeBufferPointer(start: processes, count: Int(count)).compactMap { process -> UInt32? in
			guard let url = process.executable_url else { return nil }
			return _normalized(String(cString: url)).hasPrefix(prefix) ? process.pid : nil
		}
		app_service_free_process_list(processes, count)
		return pids.filter { _kill($0, service: service) }.count
	}

	private static func _kill(_ pid: UInt32, service: OpaquePointer) -> Bool {
		var response: UnsafeMutablePointer<SignalResponseC>?
		guard AppleTVLink.ok(app_service_send_signal(service, pid, UInt32(SIGKILL), &response), "close \(pid)") else { return false }
		if let response { app_service_free_signal_response(response) }
		return true
	}

	/// Executable URLs come back as `file:///private/var/...` while app paths
	/// may be plain `/var/...`, so both are brought to one form.
	private static func _normalized(_ path: String) -> String {
		var path = path
		if path.hasPrefix("file://") {
			path = URL(string: path)?.path ?? String(path.dropFirst("file://".count))
		}
		if path.hasPrefix("/private/") { path = String(path.dropFirst("/private".count)) }
		return path
	}
}
