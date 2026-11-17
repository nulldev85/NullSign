//
//  AppleTVLink.swift
//  NullSign
//

import Darwin
import Foundation
import IDevice
import IDeviceSwift

/// A short-lived connection of NullSign's own to the paired Apple TV, separate
/// from the one an install uses, for quick questions while an install runs.
enum AppleTVLink {
	/// Connects to the Apple TV NullSign is currently pointed at and runs
	/// `body` on a background thread. Returns `fallback` if connecting fails
	/// or nothing comes back within `timeout` seconds.
	static func run<T>(
		timeout: TimeInterval,
		fallback: T,
		_ body: @escaping (_ adapter: OpaquePointer, _ handshake: OpaquePointer) -> T
	) async -> T {
		let heartbeat = HeartbeatManager.shared
		let host = heartbeat.ipAddress
		let port = heartbeat.port_rsd
		let pairingPath = heartbeat.activePairingPath

		return await withCheckedContinuation { continuation in
			let once = Once()
			Thread.detachNewThread {
				let value = _connect(host: host, port: port, pairingPath: pairingPath).map { link -> T in
					defer {
						rsd_handshake_free(link.handshake)
						adapter_free(link.adapter)
					}
					return body(link.adapter, link.handshake)
				} ?? fallback
				if once.claim() { continuation.resume(returning: value) }
			}
			DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
				if once.claim() {
					FileLogger.log("Apple TV didn't answer in time", category: "install")
					continuation.resume(returning: fallback)
				}
			}
		}
	}

	private static func _connect(host: String, port: UInt16, pairingPath: String) -> (adapter: OpaquePointer, handshake: OpaquePointer)? {
		var pairing: OpaquePointer?
		guard ok(rp_pairing_file_read(pairingPath, &pairing), "read pairing"), let pairing else { return nil }
		defer { rp_pairing_file_free(pairing) }

		var hints = addrinfo()
		hints.ai_family = AF_UNSPEC
		hints.ai_socktype = SOCK_STREAM
		hints.ai_protocol = IPPROTO_TCP
		var info: UnsafeMutablePointer<addrinfo>?
		guard getaddrinfo(host, String(port), &hints, &info) == 0, let first = info, let address = first.pointee.ai_addr else {
			FileLogger.error("couldn't resolve Apple TV address", category: "install")
			return nil
		}
		defer { freeaddrinfo(info) }

		var adapter: OpaquePointer?
		var handshake: OpaquePointer?
		guard ok(tunnel_create_rppairing(UnsafePointer(address), first.pointee.ai_addrlen, "IdeviceKit", pairing, nil, nil, &adapter, &handshake), "connect"),
			  let adapter, let handshake else { return nil }
		return (adapter, handshake)
	}

	/// Logs and frees an idevice error. True when there wasn't one.
	static func ok(_ error: UnsafeMutablePointer<IdeviceFfiError>?, _ step: String) -> Bool {
		guard let error else { return true }
		let message = error.pointee.message.map { String(cString: $0) } ?? "code \(error.pointee.code)"
		FileLogger.error("Apple TV couldn't \(step): \(message)", category: "install")
		idevice_error_free(error)
		return false
	}

	final class Once: @unchecked Sendable {
		private let _lock = NSLock()
		private var _done = false

		func claim() -> Bool {
			_lock.lock()
			defer { _lock.unlock() }
			guard !_done else { return false }
			_done = true
			return true
		}
	}
}

// MARK: - Installed copy
extension AppleTVLink {
	/// What the Apple TV reports for an installed app.
	struct InstalledCopy: Equatable, CustomStringConvertible {
		var path: String?
		var version: String?
		var build: String?

		var description: String {
			"\(version ?? "?") (\(build ?? "?")) at \(path.map { ($0 as NSString).lastPathComponent } ?? "?") in \(path.map { (($0 as NSString).deletingLastPathComponent as NSString).lastPathComponent } ?? "?")"
		}
	}

	/// Asks the Apple TV what copy of `bundleID` it has installed. `nil` inside
	/// means it has none; an outer `nil` means it couldn't be asked.
	static func installedCopy(of bundleID: String, timeout: TimeInterval = 12) async -> InstalledCopy?? {
		await run(timeout: timeout, fallback: Optional<InstalledCopy?>.none) { adapter, handshake in
			var client: OpaquePointer?
			guard ok(installation_proxy_connect_rsd(adapter, handshake, &client), "open installer"), let client else { return .none }
			defer { installation_proxy_client_free(client) }

			var result: UnsafeMutableRawPointer?
			var count: Int = 0
			let error = bundleID.withCString { id -> UnsafeMutablePointer<IdeviceFfiError>? in
				let ids: [UnsafePointer<CChar>?] = [id]
				return ids.withUnsafeBufferPointer { buffer in
					installation_proxy_get_apps(client, nil, buffer.baseAddress, 1, &result, &count)
				}
			}
			guard ok(error, "look up \(bundleID)") else { return .none }
			guard let result, count > 0 else { return .some(nil) }

			let plists = result.assumingMemoryBound(to: plist_t?.self)
			defer { idevice_plist_array_free(plists, UInt(count)) }

			for plist in UnsafeBufferPointer(start: plists, count: count) {
				guard let plist else { continue }
				var xml: UnsafeMutablePointer<CChar>?
				var length: UInt32 = 0
				plist_to_xml(plist, &xml, &length)
				guard let xml else { continue }
				let data = Data(bytes: xml, count: Int(length))
				free(xml)
				guard let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
					  (info["CFBundleIdentifier"] as? String) == bundleID else { continue }
				return .some(InstalledCopy(
					path: info["Path"] as? String,
					version: info["CFBundleShortVersionString"] as? String,
					build: info["CFBundleVersion"] as? String
				))
			}
			return .some(nil)
		}
	}
}

// MARK: - Asking again
extension AppleTVLink {
	private final class _ProgressBox {
		let report: (Double) -> Void
		init(_ report: @escaping (Double) -> Void) { self.report = report }
	}

	private static let _progressCallback: @convention(c) (UInt64, UnsafeMutableRawPointer?) -> Void = { progress, context in
		guard let context else { return }
		Unmanaged<_ProgressBox>.fromOpaque(context).takeUnretainedValue().report(Double(progress) / 100)
	}

	/// Finds the package NullSign already uploaded (by its size) in the TV's
	/// staging folder and asks the TV to install it on a fresh connection.
	/// `true` once installed, `false` if the TV refused, `nil` if the package
	/// couldn't be found or the TV couldn't be reached.
	static func installStagedPackage(ofSize size: Int, timeout: TimeInterval = 600, progress: @escaping (Double) -> Void) async -> Bool? {
		await run(timeout: timeout, fallback: Optional<Bool>.none) { adapter, handshake in
			guard let path = _stagedPackage(ofSize: size, adapter: adapter, handshake: handshake) else {
				FileLogger.log("couldn't find the uploaded package on the Apple TV", category: "install")
				return nil
			}

			var client: OpaquePointer?
			guard ok(installation_proxy_connect_rsd(adapter, handshake, &client), "open installer"), let client else { return nil }
			defer { installation_proxy_client_free(client) }

			FileLogger.log("asking the Apple TV again to install \(path)", category: "install")
			let box = Unmanaged.passRetained(_ProgressBox(progress))
			defer { box.release() }
			let error = installation_proxy_install_with_callback(client, path, nil, _progressCallback, box.toOpaque())
			return ok(error, "install on the second request")
		}
	}

	private static func _stagedPackage(ofSize size: Int, adapter: OpaquePointer, handshake: OpaquePointer) -> String? {
		var afc: OpaquePointer?
		guard ok(afc_client_connect_rsd(adapter, handshake, &afc), "open file access"), let afc else { return nil }
		defer { afc_client_free(afc) }

		let folder = "/PublicStaging"
		var entries: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
		var count: Int = 0
		guard ok(afc_list_directory(afc, folder, &entries, &count), "list staging"), let entries else { return nil }

		var names: [String] = []
		for entry in UnsafeBufferPointer(start: entries, count: count) {
			guard let entry else { continue }
			let name = String(cString: entry)
			if name != ".", name != ".." { names.append(name) }
		}
		FileLogger.log("Apple TV staging has \(names.count) item(s)", category: "install")

		for name in names {
			let path = "\(folder)/\(name)"
			var info = AfcFileInfo()
			guard afc_get_file_info(afc, path, &info) == nil else { continue }
			let matches = Int(info.size) == size
			afc_file_info_free(&info)
			if matches { return path }
		}
		return nil
	}
}
