//
//  CertificateFileHandler.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import Foundation
import OSLog

final class CertificateFileHandler: NSObject {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	
	private let _key: URL
	private let _provision: URL
	private let _keyPassword: String?
	private let _certNickname: String?
	private let _isDefault: Bool
	
	private var _certPair: Certificate?
	
	init(
		key: URL,
		provision: URL,
		password: String? = nil,
		nickname: String? = nil,
		isDefault: Bool = false
	) {
		self._key = key
		self._provision = provision
		self._keyPassword = password
		self._certNickname = nickname
		self._isDefault = isDefault
		
		super.init()
	}
	
	func copy() async throws {
		let keyAccess = _key.startAccessingSecurityScopedResource()
		let profileAccess = _provision.startAccessingSecurityScopedResource()
		defer {
			if keyAccess { _key.stopAccessingSecurityScopedResource() }
			if profileAccess { _provision.stopAccessingSecurityScopedResource() }
		}
		try FR.validateCertificate(for: _key, with: _keyPassword ?? "", using: _provision)
		guard let profile = CertificateReader(_provision).decoded else {
			throw CertificateFileHandlerError.certNotValid
		}
		_certPair = profile
		
		let destinationURL = try await _directory()

		do {
			try _fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
			try _fileManager.copyItem(at: _key, to: destinationURL.appendingPathComponent(_key.lastPathComponent))
			try _fileManager.copyItem(at: _provision, to: destinationURL.appendingPathComponent(_provision.lastPathComponent))
		} catch {
			try? _fileManager.removeItem(at: destinationURL)
			throw error
		}
	}
	
	func addToDatabase() async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			Storage.shared.addCertificate(
				uuid: _uuid,
				password: _keyPassword,
				nickname: _certNickname,
				ppq: _certPair?.PPQCheck ?? false,
				expiration: _certPair?.ExpirationDate ?? Date(),
				isDefault: _isDefault
			) { error in
				if let error { continuation.resume(throwing: error) }
				else { continuation.resume() }
			}
		}
	}

	func clean() async throws {
		try _fileManager.removeFileIfNeeded(at: _fileManager.certificates(_uuid))
	}
	
	private func _directory() async throws -> URL {
		// Documents/Feather/Certificates/\(UUID)
		_fileManager.certificates(_uuid)
	}
}

private enum CertificateFileHandlerError: LocalizedError {
	case certNotValid

	var errorDescription: String? {
		"The provisioning profile is missing required signing details. Download the original .mobileprovision file and try again."
	}
}
