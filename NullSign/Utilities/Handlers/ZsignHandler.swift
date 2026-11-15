//
//  ZsignHandler.swift
//  NullSign
//
//  Created by samara on 17.04.2025.
//

import Foundation
import Zsign
import UIKit

final class ZsignHandler {
	var hadError: Error?
	
	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
	}
	
	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty else {
			return
		}
		
		SigningLog.shared.info(.localized("Removing injected dylibs"))

		let bundle = Bundle(url: _appUrl)
		let execPath = _appUrl.appendingPathComponent(bundle?.exec ?? "").relativePath

		if !Zsign.removeDylibs(appExecutable: execPath, using: _options.disInjectionFiles) {
			throw SigningFileHandlerError.disinjectFailed
		}
	}
	
	func sign() async throws {
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}

		StdoutCapture.shared.start { SigningLog.shared.info($0) }
		defer { StdoutCapture.shared.stop() }

		let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
			p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
			p12Password: cert.password ?? "",
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			// Zsign's flag is inverted: true embeds the profile.
			removeProvision: _embedsProvisioningProfile,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
	}

	/// The profile goes inside the app unless Remove Provisioning is on. Apple
	/// TV apps always carry it: an Apple TV has no profile installed until an
	/// app brings one, and without it tvOS refuses the app.
	private var _embedsProvisioningProfile: Bool {
		guard _options.removeProvisioning else { return true }
		let info = NSDictionary(contentsOf: _appUrl.appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
		return TVIconSelection.isTVApp(info)
	}
	
	func adhocSign() async throws {
		StdoutCapture.shared.start { SigningLog.shared.info($0) }
		defer { StdoutCapture.shared.stop() }

		let _ = Zsign.sign(
			appPath: _appUrl.relativePath,
			entitlementsPath: _options.appEntitlementsFile?.path ?? "",
			adhoc: true,
			removeProvision: !_options.removeProvisioning,
			completion: { success in
				if !success {
					self.hadError = SigningFileHandlerError.signFailed
				}
			}
		)
	}
}
