//
//  Server+TLS.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import NIOSSL
import NIOTLS
import Vapor
import SystemConfiguration.CaptiveNetwork

// MARK: - Class extension: TLS/Setup
extension ServerInstaller {
	// MARK: Setup
	static let env: Environment = {
		var env = try! Environment.detect()
		try! LoggingSystem.bootstrap(from: &env)
		return env
	}()
	
	func setupApp(port: Int) throws -> Application {
		let app = Application(Self.env)
		app.threadPool = .init(numberOfThreads: 1)
		
		if getServerMethod() != 1 {
			if let tls = try tls() {
				app.http.server.configuration.tlsConfiguration = tls
			}
		}
		
		app.http.server.configuration.hostname = sni()
		app.http.server.configuration.tcpNoDelay = true
		app.http.server.configuration.address = .hostname("0.0.0.0", port: port)
		app.http.server.configuration.port = port
		app.routes.defaultMaxBodySize = "128mb"
		app.routes.caseInsensitive = false
		
		return app
	}
	
	// MARK: Files/IP
	func sni() -> String {
		let localhost = "127.0.0.1"
		
		if getServerMethod() == 1 {
			return !self.getIPFix()
				? (Self.getLocalAddress() ?? localhost)
				: localhost
		} else {
			return certificateHostname() ?? localhost
		}
	}

	/// Returns a concrete hostname covered by the downloaded certificate.
	/// A wildcard is a certificate pattern, not a valid address to navigate to.
	func certificateHostname() -> String? {
		guard let commonName = readCommonName(), !commonName.isEmpty else {
			return nil
		}

		if commonName.hasPrefix("*.") {
			return "nullsign." + String(commonName.dropFirst(2))
		}

		return commonName
	}
	
	func tls() throws -> TLSConfiguration? {
		guard
			let crt = Self.getUrl("server", ext: "crt"),
			let pem = Self.getUrl("server", ext: "pem")
		else {
			return nil
		}
		
		return try TLSConfiguration.makeServerConfiguration(
			certificateChain: NIOSSLCertificate.fromPEMFile(crt.path).map {
				NIOSSLCertificateSource.certificate($0)
			},
			privateKey: .privateKey(
				try NIOSSLPrivateKey(file: pem.path, format: .pem)
			)
		)
	}
	
	func readCommonName() -> String? {
		guard let url = Self.getUrl("commonName", ext: "txt") else {
			return nil
		}
		
		return try? String(contentsOf: url, encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}

extension ServerInstaller {
	static func getUrl(_ name: String, ext: String) -> URL? {
		let fileManager = FileManager.default
		
		let documentsURL = URL.documentsDirectory.appendingPathComponent("\(name).\(ext)")
		let bundlesURL = Bundle.main.url(forResource: name, withExtension: ext)
		
		if fileManager.fileExists(atPath: documentsURL.path) {
			return documentsURL
		}
		
		if let bundlesURL, fileManager.fileExists(atPath: bundlesURL.path) {
			return bundlesURL
		}
		
		return nil
	}
	
	/// The phone's own Wi-Fi address, which the install page and the download
	/// it starts are served from. Only Wi-Fi counts: the cellular interface's
	/// address (often a carrier's shared 100.64.x.x) and a VPN's tunnel are not
	/// reachable from this same phone, and Safari hangs on them until it gives
	/// up with "the server stopped responding". Without a Wi-Fi address the
	/// caller falls back to 127.0.0.1.
	static func getLocalAddress() -> String? {
		var ifaddr: UnsafeMutablePointer<ifaddrs>?
		guard getifaddrs(&ifaddr) == 0 else { return nil }
		defer { freeifaddrs(ifaddr) }

		var ptr = ifaddr
		while let interface = ptr?.pointee {
			ptr = interface.ifa_next
			guard
				let address = interface.ifa_addr,
				address.pointee.sa_family == UInt8(AF_INET),
				String(cString: interface.ifa_name) == "en0"
			else {
				continue
			}

			var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
			guard getnameinfo(address, socklen_t(address.pointee.sa_len),
			                  &hostname, socklen_t(hostname.count),
			                  nil, socklen_t(0), NI_NUMERICHOST) == 0 else {
				continue
			}

			let ip = String(cString: hostname)
			// A self-assigned address means Wi-Fi never really connected.
			if ip.hasPrefix("169.254.") { continue }
			return ip
		}

		return nil
	}
}
