//
//  IPAHandler.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import Foundation
import Zip

final class AppFileHandler: NSObject, @unchecked Sendable {
	// Bound decompression work and keep the ZIP library on one worker.
	private static let _extractionQueue = DispatchQueue(label: "com.elmat.NullSign.extract", qos: .utility)
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private let _uniqueWorkDir: URL
	var uniqueWorkDirPayload: URL?

	private var _ipa: URL
	private let _install: Bool
	private let _download: Download?
	private let _sourceProvenance: SourceAppProvenance?
	private var _savedImport = false
	
	init(
		file ipa: URL,
		install: Bool = false,
		download: Download? = nil,
		sourceProvenance: SourceAppProvenance? = nil
	) {
		self._ipa = ipa
		self._install = install
		self._download = download
		self._sourceProvenance = sourceProvenance ?? download?.sourceProvenance
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherImport_\(_uuid)", isDirectory: true)
		
		super.init()
	}
	
	func copy() async throws {
		try _fileManager.createDirectoryIfNeeded(at: _uniqueWorkDir)
		
		// IPA/TIPA files are ZIP archives. A private .zip copy avoids mutating
		// Zip's process-wide custom-extension Set from concurrent imports.
		let destinationURL = _uniqueWorkDir.appendingPathComponent("Archive.zip")

		try _fileManager.removeFileIfNeeded(at: destinationURL)
		
		try ArchiveFileAccess.copy(from: _ipa, to: destinationURL)
		_ipa = destinationURL
	}
	
	func extract() async throws {
		let download = self._download
		
		try await withCheckedThrowingContinuation { continuation in
			Self._extractionQueue.async {
				do {
					var lastPercent = -1
					try Zip.unzipFile(
						self._ipa,
						destination: self._uniqueWorkDir,
						overwrite: true,
						password: nil,
						progress: { progress in
							guard progress.isFinite else { return }
							let progress = min(max(progress, 0), 1)
							let percent = Int(progress * 100)
							guard percent > lastPercent else { return }
							lastPercent = percent
							if let download = download {
								DispatchQueue.main.async {
									download.unpackageProgress = progress
									
									#if !targetEnvironment(macCatalyst)
									if #available(iOS 26.0, *) {
										BackgroundTaskManager.shared.updateProgress(for: download.id, progress: download.overallProgress)
									}
									#endif
								}
							}
						}
					)
					
					self.uniqueWorkDirPayload = self._uniqueWorkDir.appendingPathComponent("Payload")
					continuation.resume()
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
	
	func move() async throws {
		guard let payloadURL = uniqueWorkDirPayload else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		let destinationURL = try await _directory()
		
		guard _fileManager.fileExists(atPath: payloadURL.path) else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		try _fileManager.moveItem(at: payloadURL, to: destinationURL)
		
		try? _fileManager.removeItem(at: _uniqueWorkDir)
	}
	
	func addToDatabase() async throws {
		let app = try await _directory()
		
		guard let appUrl = _fileManager.getPath(in: app, for: "app") else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		// Read the IPA's flat bundle metadata directly. Host Bundle layout
		// detection can interpret a Resources folder as a different bundle type.
		let metadata = try ImportedBundleMetadata(at: appUrl)
		
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			Storage.shared.addImported(
				uuid: _uuid,
				source: _sourceProvenance?.sourceRepositoryURL,
				appName: metadata.name,
				appIdentifier: metadata.identifier,
				appVersion: metadata.version,
				appIcon: metadata.iconFileName
			) { error in
				if let error { continuation.resume(throwing: error) }
				else { continuation.resume() }
			}
		}
		_savedImport = true
		
		if let sourceProvenance = _sourceProvenance {
			Storage.shared.addSourceMetadata(
				for: _uuid,
				kind: .imported,
				provenance: sourceProvenance
			)
		}
	}
	
	private func _directory() async throws -> URL {
		// Documents/Feather/Unsigned/\(UUID)
		_fileManager.unsigned(_uuid)
	}
	
	func clean() async throws {
		try _fileManager.removeFileIfNeeded(at: _uniqueWorkDir)
		if !_savedImport {
			try _fileManager.removeFileIfNeeded(at: _fileManager.unsigned(_uuid))
		}
	}
}

private struct ImportedBundleMetadata {
	private let info: [String: Any]
	let identifier: String

	init(at appURL: URL) throws {
		guard let data = try? Data(contentsOf: appURL.appendingPathComponent("Info.plist")),
			  let info = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any],
			  let identifier = info["CFBundleIdentifier"] as? String, !identifier.isEmpty else {
			throw ImportedFileHandlerError.invalidMetadata
		}
		self.info = info
		self.identifier = identifier
	}

	var name: String {
		["CFBundleDisplayName", "CFBundleName", "CFBundleExecutable"]
			.compactMap { info[$0] as? String }.first { !$0.isEmpty } ?? identifier
	}

	var version: String {
		info["CFBundleShortVersionString"] as? String ?? info["CFBundleVersion"] as? String ?? ""
	}

	var iconFileName: String? {
		for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
			if let icons = info[key] as? [String: Any],
			   let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
			   let files = primary["CFBundleIconFiles"] as? [String], let name = files.last {
				return name
			}
		}
		for key in ["CFBundleIconFiles", "CFBundleIconFiles~iphone", "CFBundleIconFiles~ipad"] {
			if let files = info[key] as? [String], let name = files.last { return name }
		}
		return info["CFBundleIconFile"] as? String
	}
}

private enum ImportedFileHandlerError: LocalizedError {
	case payloadNotFound
	case invalidMetadata

	var errorDescription: String? {
		switch self {
		case .payloadNotFound:
			"This archive does not contain an app in its Payload folder. Choose the original IPA or TIPA file."
		case .invalidMetadata:
			"The app's Info.plist is missing or invalid. Choose an IPA with a valid bundle identifier."
		}
	}
}
