//
//  Storage+Certificate.swift
//  RyukSign
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
/// Apple TV apps are signed with a certificate whose provisioning profile
/// includes tvOS. iPhone apps keep the certificate selected in Certificates;
/// tvOS apps remember their own.
extension Storage {
	private static let _tvOSCertificateKey = "feather.selectedCert.tvOS"

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

	/// The index, newest first, of the certificate to sign an app for this
	/// platform with.
	func preferredCertificateIndex(for platform: AppPlatform) -> Int? {
		let selected = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		let certificates = getAllCertificates()

		guard platform == .tvOS else {
			return certificates.indices.contains(selected) ? selected : nil
		}

		if let uuid = UserDefaults.standard.string(forKey: Self._tvOSCertificateKey),
		   let index = certificates.firstIndex(where: { $0.uuid == uuid && certificate($0, supports: .tvOS) }) {
			return index
		}
		if certificates.indices.contains(selected), certificate(certificates[selected], supports: .tvOS) {
			return selected
		}
		return certificates.firstIndex { certificate($0, supports: .tvOS) }
	}

	/// Remembers the certificate chosen for tvOS apps.
	func rememberCertificate(_ cert: CertificatePair, for platform: AppPlatform) {
		guard platform == .tvOS, certificate(cert, supports: .tvOS), let uuid = cert.uuid else { return }
		UserDefaults.standard.set(uuid, forKey: Self._tvOSCertificateKey)
	}

	/// The certificate to sign an app with: the chosen one when its profile
	/// covers the app's platform, else that platform's preferred certificate.
	func signingCertificate(for app: AppInfoPresentable, chosen: CertificatePair?) -> CertificatePair? {
		guard app.platform == .tvOS else { return chosen }
		if let chosen, certificate(chosen, supports: .tvOS) { return chosen }
		return preferredCertificateIndex(for: .tvOS).flatMap(getCertificate(for:)) ?? chosen
	}
}
