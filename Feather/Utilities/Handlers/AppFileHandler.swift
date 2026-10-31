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
		let access = _ipa.startAccessingSecurityScopedResource()
		let source = _ipa
		defer { if access { source.stopAccessingSecurityScopedResource() } }
		try _fileManager.createDirectoryIfNeeded(at: _uniqueWorkDir)
		
		// IPA/TIPA files are ZIP archives. A private .zip copy avoids mutating
		// Zip's process-wide custom-extension Set from concurrent imports.
		let destinationURL = _uniqueWorkDir.appendingPathComponent("Archive.zip")

		try _fileManager.removeFileIfNeeded(at: destinationURL)
		
		try _fileManager.copyItem(at: _ipa, to: destinationURL)
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
		
		let bundle = Bundle(url: appUrl)
		
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			Storage.shared.addImported(
				uuid: _uuid,
				source: _sourceProvenance?.sourceRepositoryURL,
				appName: bundle?.name,
				appIdentifier: bundle?.bundleIdentifier,
				appVersion: bundle?.version,
				appIcon: bundle?.iconFileName
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

private enum ImportedFileHandlerError: LocalizedError {
	case payloadNotFound

	var errorDescription: String? {
		"This archive does not contain an app in its Payload folder. Choose the original IPA or TIPA file."
	}
}
