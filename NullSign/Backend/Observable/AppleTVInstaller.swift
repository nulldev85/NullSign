//
//  AppleTVInstaller.swift
//  NullSign
//

import Foundation
import IDevice
import IDeviceSwift

/// Installs apps on the paired Apple TV over NullSign's own connection.
///
/// An install request that doesn't say which app it is can sit in tvOS's
/// install queue at 0% until someone opens the app on the TV. So the
/// package request names the app's bundle ID, and if the TV still doesn't
/// start, the app is sent the way Xcode sends it: unpacked, as a developer
/// install, which replaces the queued request.
enum AppleTVInstaller {
	enum Method: CustomStringConvertible {
		/// The packaged .ipa, named by its bundle ID.
		case package(URL)
		/// The unpacked .app folder, as a developer install.
		case developer(URL)

		var description: String {
			switch self {
			case .package: "package"
			case .developer: "developer"
			}
		}
	}

	struct Failure: LocalizedError {
		let message: String
		var errorDescription: String? { message }
	}

	/// Uploads and installs. `onUpload` and `onProgress` get 0...1 values and
	/// `onInstalling` is called once the TV has the whole app.
	static func install(
		_ method: Method,
		bundleID: String,
		onUpload: @escaping @Sendable (Double) -> Void,
		onInstalling: @escaping @Sendable () -> Void,
		onProgress: @escaping @Sendable (Double) -> Void
	) async throws {
		let heartbeat = HeartbeatManager.shared
		let host = heartbeat.ipAddress
		let port = heartbeat.port_rsd
		let pairingPath = heartbeat.activePairingPath

		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			Thread.detachNewThread {
				do {
					try _install(method, bundleID: bundleID, host: host, port: port, pairingPath: pairingPath,
								 onUpload: onUpload, onInstalling: onInstalling, onProgress: onProgress)
					continuation.resume()
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	// MARK: - Steps

	private static func _install(
		_ method: Method,
		bundleID: String,
		host: String,
		port: UInt16,
		pairingPath: String,
		onUpload: @escaping @Sendable (Double) -> Void,
		onInstalling: @escaping @Sendable () -> Void,
		onProgress: @escaping @Sendable (Double) -> Void
	) throws {
		guard let link = AppleTVLink.connect(host: host, port: port, pairingPath: pairingPath) else {
			throw Failure(message: "Missing Pairing")
		}
		defer {
			rsd_handshake_free(link.handshake)
			adapter_free(link.adapter)
		}

		var afc: OpaquePointer?
		try _check(afc_client_connect_rsd(link.adapter, link.handshake, &afc))
		guard let afc else { throw Failure(message: "Cannot connect to AFC") }
		defer { afc_client_free(afc) }

		let staging = "/PublicStaging"
		_ = AppleTVLink.ok(afc_make_directory(afc, staging), "make staging folder")
		let token = UUID().uuidString

		let remotePath: String
		let options = plist_new_dict()
		defer { plist_free(options) }

		switch method {
		case .package(let url):
			remotePath = "\(staging)/\(token).ipa"
			let data = try Data(contentsOf: url, options: .mappedIfSafe)
			try _upload(data, to: remotePath, afc: afc) { onUpload(Double($0) / Double(max(data.count, 1))) }
			plist_dict_set_item(options, "CFBundleIdentifier", plist_new_string(bundleID))
		case .developer(let appURL):
			let folder = "\(staging)/\(token)"
			_ = AppleTVLink.ok(afc_make_directory(afc, folder), "make upload folder")
			remotePath = "\(folder)/\(appURL.lastPathComponent)"
			try _uploadFolder(appURL, to: remotePath, afc: afc, onUpload: onUpload)
			plist_dict_set_item(options, "PackageType", plist_new_string("Developer"))
			plist_dict_set_item(options, "CFBundleIdentifier", plist_new_string(bundleID))
		}

		onInstalling()
		FileLogger.log("asking the Apple TV to install \(bundleID) as a \(method) install", category: "install")

		var client: OpaquePointer?
		try _check(installation_proxy_connect_rsd(link.adapter, link.handshake, &client))
		guard let client else { throw Failure(message: "Cannot connect to the installer") }
		defer { installation_proxy_client_free(client) }

		let box = Unmanaged.passRetained(_ProgressBox(onProgress))
		defer { box.release() }
		switch method {
		case .package:
			try _check(installation_proxy_install_with_callback(client, remotePath, options, _progressCallback, box.toOpaque()))
		case .developer:
			try _check(installation_proxy_upgrade_with_callback(client, remotePath, options, _progressCallback, box.toOpaque()))
		}
		FileLogger.log("Apple TV finished the \(method) install of \(bundleID)", category: "install")
	}

	private static func _upload(_ data: Data, to remotePath: String, afc: OpaquePointer, progress: (Int) -> Void) throws {
		var handle: OpaquePointer?
		try _check(afc_file_open(afc, remotePath, AfcWrOnly, &handle))
		guard let handle else { throw Failure(message: "Error writing to AFC") }

		let chunk = 4 * 1024 * 1024
		var written = 0
		var failure: Error?
		data.withUnsafeBytes { raw in
			guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
			while written < data.count {
				let length = min(chunk, data.count - written)
				do {
					try _check(afc_file_write(handle, base.advanced(by: written), length))
				} catch {
					failure = error
					return
				}
				written += length
				progress(written)
			}
		}
		let closed = afc_file_close(handle)
		if let failure { _ = AppleTVLink.ok(closed, "close upload"); throw failure }
		try _check(closed)
		if data.isEmpty { progress(0) }
	}

	private static func _uploadFolder(_ local: URL, to remote: String, afc: OpaquePointer, onUpload: @escaping @Sendable (Double) -> Void) throws {
		guard let walker = FileManager.default.enumerator(atPath: local.path) else {
			throw Failure(message: "Couldn't read \(local.lastPathComponent)")
		}

		var folders: [String] = []
		var files: [(URL, String, Int)] = []
		while let relative = walker.nextObject() as? String {
			let attributes = walker.fileAttributes ?? [:]
			let type = (attributes[.type] as? FileAttributeType) ?? (attributes[.type] as? String).map(FileAttributeType.init(rawValue:))
			let target = "\(remote)/\(relative)"
			if type == .typeSymbolicLink {
				FileLogger.log("skipping link \(relative) for the Apple TV", category: "install")
			} else if type == .typeDirectory {
				folders.append(target)
			} else {
				let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
				files.append((local.appendingPathComponent(relative), target, size))
			}
		}

		_ = AppleTVLink.ok(afc_make_directory(afc, remote), "make app folder")
		for folder in folders {
			_ = AppleTVLink.ok(afc_make_directory(afc, folder), "make \(folder)")
		}

		let total = max(files.reduce(0) { $0 + $1.2 }, 1)
		var sent = 0
		FileLogger.log("uploading \(files.count) files to the Apple TV", category: "install")
		for (url, target, size) in files {
			let data = try Data(contentsOf: url, options: .mappedIfSafe)
			let before = sent
			try _upload(data, to: target, afc: afc) { onUpload(Double(before + $0) / Double(total)) }
			sent += size
		}
		onUpload(1)
	}

	// MARK: - Helpers

	private final class _ProgressBox {
		let report: (Double) -> Void
		init(_ report: @escaping (Double) -> Void) { self.report = report }
	}

	private static let _progressCallback: @convention(c) (UInt64, UnsafeMutableRawPointer?) -> Void = { progress, context in
		guard let context else { return }
		Unmanaged<_ProgressBox>.fromOpaque(context).takeUnretainedValue().report(Double(progress) / 100)
	}

	private static func _check(_ error: UnsafeMutablePointer<IdeviceFfiError>?) throws {
		guard let error else { return }
		let message = error.pointee.message.map { String(cString: $0) } ?? "code \(error.pointee.code)"
		idevice_error_free(error)
		throw Failure(message: message)
	}
}
