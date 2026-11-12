//
//  FR.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import Foundation.NSURL
import UIKit.UIImage
import Zsign
import NimbleJSON
import AltSourceKit
import IDeviceSwift
import CoreData

enum FR {
	static let serverPackURL = "https://backloop.dev/public/pack.json"
	static let serverCertificateURL = URL(string: "https://backloop.dev/public/backloop.dev-cert.crt")!

	static func handlePackageFile(
		_ ipa: URL,
		download: Download? = nil,
		sourceProvenance: SourceAppProvenance? = nil,
		completion: @escaping (Error?) -> Void
	) {
		Task.detached {
			do {
				try await AppImportOperation.run(file: ipa, download: download, sourceProvenance: sourceProvenance)
				await MainActor.run {
					completion(nil)
				}
			} catch {
				ReliabilityCenter.shared.record(.preflight, "Import failed: \(error.localizedDescription)")
				await MainActor.run {
					completion(error)
				}
			}
		}
	}
	
	static func signPackageFile(
		_ app: AppInfoPresentable,
		using options: Options,
		icon: UIImage?,
		certificate: CertificatePair?,
		completion: @escaping (Error?) -> Void
	) {
		Task.detached {
			let handler = SigningHandler(app: app, options: options)
			handler.appCertificate = certificate
			handler.appIcon = icon
			
			do {
				try await handler.copy()
				try await handler.modify()
				try? await handler.clean()
				await MainActor.run {
					completion(nil)
				}
			} catch {
				ReliabilityCenter.shared.record(.verifying, "Signing stopped: \(error.localizedDescription)")
				try? await handler.clean()
				await MainActor.run {
					completion(error)
				}
			}
		}
	}

	/// Unlike the legacy completion-only API, this returns the row created by
	/// this operation, even when another app finishes signing at the same time.
	@MainActor
	static func signedPackageFile(
		_ app: AppInfoPresentable,
		using options: Options,
		icon: UIImage?,
		certificate: CertificatePair?,
		onStageChange: @escaping @MainActor (AppSigningStage) -> Void
	) async throws -> Signed {
		let uuid = try await Task.detached {
			let handler = SigningHandler(app: app, options: options)
			handler.appCertificate = certificate
			handler.appIcon = icon
			handler.onStageChange = { stage in
				Task { @MainActor in onStageChange(stage) }
			}
			do {
				try await handler.copy()
				try await handler.modify()
				try? await handler.clean()
				return handler.signedAppUUID
			} catch {
				ReliabilityCenter.shared.record(.verifying, "Signing stopped: \(error.localizedDescription)")
				try? await handler.clean()
				throw error
			}
		}.value
		let request = NSFetchRequest<Signed>(entityName: "Signed")
		request.predicate = NSPredicate(format: "uuid == %@", uuid)
		request.fetchLimit = 1
		guard let signed = try Storage.shared.context.fetch(request).first else {
			throw SigningFileHandlerError.appNotFound
		}
		return signed
	}
	
	static func handleCertificateFiles(
		p12URL: URL,
		provisionURL: URL,
		p12Password: String,
		certificateName: String = "",
		isDefault: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		Task.detached {
			let handler = CertificateFileHandler(
				key: p12URL,
				provision: provisionURL,
				password: p12Password,
				nickname: certificateName.isEmpty ? nil : certificateName,
				isDefault: isDefault
			)
			
			do {
				try await handler.copy()
				try await handler.addToDatabase()
				await MainActor.run {
					completion(nil)
				}
			} catch {
				try? await handler.clean()
				await MainActor.run {
					completion(error)
				}
			}
		}
	}
	
	static func validateCertificate(
		for key: URL,
		with password: String,
		using provision: URL
	) throws {
		if let message = certificate_import_error(key.path, password, provision.path) {
			throw NSError(domain: "NullSign.CertificateImport", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
		}
	}
	
	static func movePairing(_ url: URL) {
		let fileManager = FileManager.default
		let dest = URL.documentsDirectory.appendingPathComponent("pairingFile.plist")
		
		try? fileManager.removeFileIfNeeded(at: dest)
		
		try? fileManager.copyItem(at: url, to: dest)
		
		HeartbeatManager.shared.start(true)
	}
	
	static func downloadSSLCertificates(
		from urlString: String,
		completion: @escaping (Bool) -> Void
	) {
		let generator = UINotificationFeedbackGenerator()
		generator.prepare()
		
		NBFetchService().fetch(from: urlString) { (result: Result<ServerView.ServerPackModel, Error>) in
			switch result {
			case .success(let pack):
				do {
					let certificateChain = [pack.cert, pack.ca]
						.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
						.filter { !$0.isEmpty }
						.reduce(into: [String]()) { chain, certificate in
							if !chain.contains(certificate) { chain.append(certificate) }
						}
						.joined(separator: "\n") + "\n"
					try FileManager.forceWrite(content: pack.key, to: "server.pem")
					try FileManager.forceWrite(content: certificateChain, to: "server.crt")
					try FileManager.forceWrite(content: pack.info.domains.commonName, to: "commonName.txt")
					generator.notificationOccurred(.success)
					completion(true)
				} catch {
					completion(false)
				}
			case .failure(_):
				completion(false)
			}
		}
	}

	static func refreshSSLCertificates() async -> Bool {
		await withCheckedContinuation { continuation in
			downloadSSLCertificates(from: serverPackURL) { success in
				continuation.resume(returning: success)
			}
		}
	}
	
	static func handleSource(
		_ urlString: String,
		competion: @escaping () -> Void,
		failure: @escaping () -> Void = {}
	) {
		let normalizedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let url = URL(string: normalizedURL), url.scheme != nil else {
			DispatchQueue.main.async {
				UIAlertController.showAlertWithOk(
					title: .localized("Error"),
					message: .localized("Enter a valid repository URL.")
				)
				failure()
			}
			return
		}
		
		NBFetchService().fetch<ASRepository>(from: url) { (result: Result<ASRepository, Error>) in
			switch result {
			case .success(let data):
				let id = data.id ?? url.absoluteString

				DispatchQueue.main.async {
					guard !Storage.shared.sourceExists(id) else {
						competion()
						return
					}

					Storage.shared.addSource(url, repository: data, id: id) { error in
						if let error {
							UIAlertController.showAlertWithOk(
								title: .localized("Error"),
								message: error.localizedDescription
							)
							failure()
							return
						}
						competion()
					}
				}
			case .failure(let error):
				DispatchQueue.main.async {
					UIAlertController.showAlertWithOk(title: .localized("Error"), message: error.localizedDescription)
					failure()
				}
			}
		}
	}
	
	static func exportCertificateAndOpenUrl(using template: String) {
		// Helper that performs the export for a given certificate
		func performExport(for certificate: CertificatePair) {
			guard
				let certificateKeyFile = Storage.shared.getFile(.certificate, from: certificate),
				let certificateKeyFileData = try? Data(contentsOf: certificateKeyFile)
			else {
				return
			}
			
			let base64encodedCert = certificateKeyFileData.base64EncodedString()
			
			var allowedQueryParamAndKey = NSCharacterSet.urlQueryAllowed
			allowedQueryParamAndKey.remove(charactersIn: ";/?:@&=+$, ")
			
			guard let encodedCert = base64encodedCert.addingPercentEncoding(withAllowedCharacters: allowedQueryParamAndKey) else {
				return
			}
			
			let urlStr = template
				.replacingOccurrences(of: "$(BASE64_CERT)", with: encodedCert)
				.replacingOccurrences(of: "$(PASSWORD)", with: certificate.password ?? "")
			
			guard let callbackUrl = URL(string: urlStr) else {
				return
			}
			
			UIApplication.shared.open(callbackUrl)
		}
		
		let certificates = Storage.shared.getAllCertificates()
		guard !certificates.isEmpty else { return }
		
		DispatchQueue.main.async {
			var selectionActions: [UIAlertAction] = []
			
			for cert in certificates {
				var title: String
				let decoded = Storage.shared.getProvisionFileDecoded(for: cert)
				
				title = cert.nickname ?? decoded?.Name ?? .localized("Unknown")
				
				if let getTaskAllow = decoded?.Entitlements?["get-task-allow"]?.value as? Bool, getTaskAllow == true {
					title = "🐞 \(title)"
				}
				
				let selectAction = UIAlertAction(title: title, style: .default) { _ in
					performExport(for: cert)
				}
				selectionActions.append(selectAction)
			}
			
			UIAlertController.showAlertWithCancel(
				title: .localized("Export Certificate"),
				message: .localized("Do you want to export your certificate to an external app? That app will be able to sign apps using your certificate."),
				style: .alert,
				actions: selectionActions
			)
		}
	}
}
