//
//  Storage+Certificate.swift
//  Feather
//
//  Created by samara on 16.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator
import ZsignSwift

// MARK: - Class extension: certificate
extension Storage {
	func certificate(_ cert: CertificatePair, supports platform: AppPlatform) -> Bool {
		guard let profile = getProvisionFileDecoded(for: cert) else { return false }
		let platforms = profile.Platform.map { $0.lowercased() }
		switch platform {
		case .iOS:
			return platforms.contains { $0.contains("ios") || $0.contains("iphone") }
		case .tvOS:
			return platforms.contains { $0.contains("tvos") || $0.contains("appletv") }
		}
	}

	func preferredCertificateIndex(for platform: AppPlatform) -> Int? {
		let certificates = getAllCertificates()
		let defaults = UserDefaults.standard
		let key = "feather.selectedCert.\(platform.rawValue)"

		if let uuid = defaults.string(forKey: key),
		   let index = certificates.firstIndex(where: { $0.uuid == uuid && certificate($0, supports: platform) }) {
			return index
		}

		if platform == .iOS {
			let legacyIndex = defaults.integer(forKey: "feather.selectedCert")
			if certificates.indices.contains(legacyIndex), certificate(certificates[legacyIndex], supports: platform) {
				return legacyIndex
			}
		}

		return certificates.firstIndex { certificate($0, supports: platform) }
	}

	func rememberCertificate(_ cert: CertificatePair, for platform: AppPlatform) {
		guard certificate(cert, supports: platform), let uuid = cert.uuid else { return }
		UserDefaults.standard.set(uuid, forKey: "feather.selectedCert.\(platform.rawValue)")
	}

	/// Certificate imports finish on a background task, so the insert is
	/// moved onto the main context's own queue.
	func addCertificate(
		uuid: String,
		password: String? = nil,
		nickname: String? = nil,
		ppq: Bool = false,
		expiration: Date,
		isDefault: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		context.perform {
			let generator = UIImpactFeedbackGenerator(style: .light)

			let new = CertificatePair(context: self.context)
			new.uuid = uuid
			new.date = Date()
			new.password = password
			new.ppQCheck = ppq
			new.expiration = expiration
			new.nickname = nickname
			new.isDefault = isDefault
			self.saveContextNow()
			generator.impactOccurred()
			completion(nil)
		}
	}

	/// Must be called on the main queue.
	func deleteCertificate(for cert: CertificatePair) {
		guard cert.managedObjectContext === context, !cert.isDeleted else { return }

		let directory = getUuidDirectory(for: cert)
		context.delete(cert)
		saveContextNow()
		FileManager.default.removeItemsInBackground(directory.map { [$0] } ?? [])
	}
	
	func getCertificate(for index: Int) -> CertificatePair? {
		let fetchRequest: NSFetchRequest<CertificatePair> = CertificatePair.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]

		guard
			let results = try? context.fetch(fetchRequest),
			index >= 0 && index < results.count
		else {
			return nil
		}
		
		return results[index]
	}
	
	func revokagedCertificate(for cert: CertificatePair) {
		guard !cert.revoked else { return }
		
		Zsign.checkRevokage(
			provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
			p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
			p12Password: cert.password ?? ""
		) { (status, _, _) in
			if status == 1 {
				DispatchQueue.main.async {
					// The check is slow; the certificate may have been deleted meanwhile.
					guard cert.managedObjectContext === self.context, !cert.isDeleted else { return }
					cert.revoked = true
					self.saveContextNow()
				}
			}
		}
	}
	
	enum FileRequest: String {
		case certificate = "p12"
		case provision = "mobileprovision"
	}
	
	func getFile(_ type: FileRequest, from cert: CertificatePair) -> URL? {
		guard let url = getUuidDirectory(for: cert) else {
			return nil
		}
		
		return FileManager.default.getPath(in: url, for: type.rawValue)
	}
	
	func getProvisionFileDecoded(for cert: CertificatePair) -> Certificate? {
		guard let url = getFile(.provision, from: cert) else {
			return nil
		}
		
		let read = CertificateReader(url)
		return read.decoded
	}
	
	func getUuidDirectory(for cert: CertificatePair) -> URL? {
		guard let uuid = cert.uuid else {
			return nil
		}
		
		return FileManager.default.certificates(uuid)
	}
	
	func getAllCertificates() -> [CertificatePair] {
		let fetchRequest: NSFetchRequest<CertificatePair> = CertificatePair.fetchRequest()
		fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)]
		return (try? context.fetch(fetchRequest)) ?? []
	}
}
