//
//  Storage+Certificate.swift
//  NullSign
//
//  Created by samara on 16.04.2025.
//

import CoreData
import UIKit.UIImpactFeedbackGenerator
import Zsign

// MARK: - Class extension: certificate
extension Storage {
	func addCertificate(
		uuid: String,
		password: String? = nil,
		nickname: String? = nil,
		ppq: Bool = false,
		expiration: Date,
		isDefault: Bool = false,
		completion: @escaping (Error?) -> Void
	) {
		let generator = UIImpactFeedbackGenerator(style: .light)
		
		let new = CertificatePair(context: context)
		new.uuid = uuid
		new.date = Date()
		new.password = password
		new.ppQCheck = ppq
		new.expiration = expiration
		new.nickname = nickname
		new.isDefault = isDefault
		Storage.shared.revokagedCertificate(for: new)
		saveContext()
		generator.impactOccurred()
		completion(nil)
	}
	
	func deleteCertificate(for cert: CertificatePair) {
		if let url = getUuidDirectory(for: cert) {
			try? FileManager.default.removeItem(at: url)
		}
		context.delete(cert)
		saveContext()
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
					cert.revoked = true
					self.saveContext()
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

// MARK: - Platforms (NullSign)
/// iPhone apps are signed with a certificate whose provisioning profile
/// covers iOS, and Apple TV apps with one that covers tvOS. The certificate
/// selected in Certificates is used whenever it fits the app; otherwise
/// NullSign uses the one last used for that platform, else the first that fits.
extension Storage {
	private static func _certificateKey(for platform: AppPlatform) -> String {
		"feather.selectedCert.\(platform.rawValue)"
	}

	/// A certificate's profile never changes, so its platforms are read once.
	private static let _platformCache = NSCache<NSString, NSArray>()

	private func _platforms(of cert: CertificatePair) -> [String]? {
		if let uuid = cert.uuid, let cached = Self._platformCache.object(forKey: uuid as NSString) as? [String] {
			return cached
		}
		guard let profile = getProvisionFileDecoded(for: cert) else { return nil }
		let platforms = profile.Platform.map { $0.lowercased() }
		if let uuid = cert.uuid {
			Self._platformCache.setObject(platforms as NSArray, forKey: uuid as NSString)
		}
		return platforms
	}

	func certificate(_ cert: CertificatePair, supports platform: AppPlatform) -> Bool {
		guard let platforms = _platforms(of: cert) else {
			// An unreadable profile is never assumed to cover Apple TV.
			return platform == .iOS
		}
		switch platform {
		case .iOS:
			// Profiles that name no platform predate the field and are iOS.
			return platforms.isEmpty || platforms.contains { $0.contains("ios") || $0.contains("iphone") }
		case .tvOS:
			return platforms.contains { $0.contains("tvos") || $0.contains("appletv") }
		}
	}

	/// The index, newest first, of the certificate to sign an app for this
	/// platform with.
	func preferredCertificateIndex(for platform: AppPlatform) -> Int? {
		let selected = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		let certificates = getAllCertificates()

		if certificates.indices.contains(selected), certificate(certificates[selected], supports: platform) {
			return selected
		}
		if let uuid = UserDefaults.standard.string(forKey: Self._certificateKey(for: platform)),
		   let index = certificates.firstIndex(where: { $0.uuid == uuid && certificate($0, supports: platform) }) {
			return index
		}
		if let index = certificates.firstIndex(where: { certificate($0, supports: platform) }) {
			return index
		}
		// No certificate fits an iPhone app: fall back to the selected one so
		// signing can still say what's wrong.
		return platform == .iOS && certificates.indices.contains(selected) ? selected : nil
	}

	/// Remembers the certificate chosen for apps of this platform.
	func rememberCertificate(_ cert: CertificatePair, for platform: AppPlatform) {
		guard certificate(cert, supports: platform), let uuid = cert.uuid else { return }
		UserDefaults.standard.set(uuid, forKey: Self._certificateKey(for: platform))
	}

	/// The certificate to sign an app with: the chosen one when its profile
	/// covers the app's platform, else that platform's preferred certificate.
	func signingCertificate(for app: AppInfoPresentable, chosen: CertificatePair?) -> CertificatePair? {
		let platform = app.platform
		if let chosen, certificate(chosen, supports: platform) { return chosen }
		return preferredCertificateIndex(for: platform).flatMap(getCertificate(for:)) ?? chosen
	}

	/// Carries NullSign 1.x's choices into 2.0, once. 1.x remembered the
	/// iPhone certificate on its own, apart from the selected one, which could
	/// be left on an Apple TV certificate.
	func migrateNullSign1CertificateChoice() {
		let key = "nullsign.didMigrate1xCertificateChoice"
		guard !UserDefaults.standard.bool(forKey: key) else { return }
		UserDefaults.standard.set(true, forKey: key)

		let certificates = getAllCertificates()
		guard
			let uuid = UserDefaults.standard.string(forKey: Self._certificateKey(for: .iOS)),
			let index = certificates.firstIndex(where: { $0.uuid == uuid && certificate($0, supports: .iOS) })
		else {
			return
		}
		UserDefaults.standard.set(index, forKey: "feather.selectedCert")
	}
}
