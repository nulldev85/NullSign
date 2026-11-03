//
//  AppUpdatePipeline.swift
//  Feather
//

import CoreData
import Foundation

/// The steps an update goes through: download the new release, add it to the
/// library, sign it. NullSign's own update and library app updates share them.
enum AppUpdatePipeline {
	/// Downloads a package to a file of its own, which the caller removes.
	static func download(_ url: URL) async throws -> URL {
		let (temporary, response) = try await URLSession.shared.download(from: url)
		if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
			try? FileManager.default.removeItem(at: temporary)
			throw URLError(.badServerResponse)
		}
		let package = FileManager.default.temporaryDirectory
			.appendingPathComponent("NullSignUpdate-\(UUID().uuidString).ipa")
		try FileManager.default.moveItem(at: temporary, to: package)
		return package
	}

	/// Adds a downloaded package to the library as an imported app, linked to
	/// the source it came from.
	@MainActor
	static func importPackage(_ package: URL, provenance: SourceAppProvenance) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			FR.handlePackageFile(package, sourceProvenance: provenance) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	@MainActor
	static func sign(_ app: AppInfoPresentable, using options: Options, certificate: CertificatePair) async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			FR.signPackageFile(app, using: options, icon: nil, certificate: certificate) { error in
				if let error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}

	/// The library row a step just added: the newest with the identifier,
	/// made since the step began.
	@MainActor
	static func newest<T: NSManagedObject>(identifier: String?, since start: Date) -> T? {
		let request = NSFetchRequest<T>(entityName: String(describing: T.self))
		if let identifier {
			request.predicate = NSPredicate(format: "identifier == %@ AND date >= %@", identifier, start as NSDate)
		} else {
			request.predicate = NSPredicate(format: "date >= %@", start as NSDate)
		}
		request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
		request.fetchLimit = 1
		return try? Storage.shared.context.fetch(request).first
	}
}

enum AppUpdateError: LocalizedError {
	case notImported
	case notSigned
	case noCertificate

	var errorDescription: String? {
		switch self {
		case .notImported: return .localized("The update downloaded but couldn't be added to your Library.")
		case .notSigned: return .localized("The update was signed but couldn't be found in your Library.")
		case .noCertificate: return .localized("Add a certificate first. Updates are signed with a certificate from your Library.")
		}
	}
}
