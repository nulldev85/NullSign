//
//  UIApplication+open.swift
//  Feather
//
//  Created by samara on 21.04.2025.
//

import UIKit.UIApplication

extension UIApplication {
	public typealias InstallProgressSnapshot = SystemInstallRuntime.ProgressSnapshot

	/// Opens an app with an identifier
	/// - Parameter identifier: Application identifier
	static public func openApp(with identifier: String) {
		let classNameBase64 = "TFNBcHBsaWNhdGlvbldvcmtzcGFjZQ==" 			// LSApplicationWorkspace
		let defaultSelectorBase64 = "ZGVmYXVsdFdvcmtzcGFjZQ=="     			// defaultWorkspace
		let openSelectorBase64 = "b3BlbkFwcGxpY2F0aW9uV2l0aEJ1bmRsZUlEOg==" // openApplicationWithBundleID:
		
		guard
			let classNameData = Data(base64Encoded: classNameBase64),
			let defaultSelectorData = Data(base64Encoded: defaultSelectorBase64),
			let openSelectorData = Data(base64Encoded: openSelectorBase64),
			let className = String(data: classNameData, encoding: .utf8),
			let defaultSelector = String(data: defaultSelectorData, encoding: .utf8),
			let openSelector = String(data: openSelectorData, encoding: .utf8)
		else {
			return
		}
		
		guard
			let workspaceClass = NSClassFromString(className) as? NSObject.Type,
			let workspace = workspaceClass.perform(NSSelectorFromString(defaultSelector))?.takeUnretainedValue()
		else {
			return
		}
		
		_ = workspace.perform(NSSelectorFromString(openSelector), with: identifier)
	}
	
	/// Returns install progress for a bundle identifier (0.0 – 1.0)
	/// - Parameters:
	///   - identifier: Bundle identifier
	///   - synchronous: Whether the call should block
	/// - Returns: Progress value if available
	static public func installProgress(
		for identifier: String,
		makeSynchronous synchronous: Bool = true
	) -> Double? {
		installProgressSnapshot(
			for: identifier,
			makeSynchronous: synchronous
		)?.fractionCompleted
	}

	/// Returns both the fraction and the terminal state reported by iOS. The
	/// system can finish an install before its fraction reaches exactly 1.0.
	static public func installProgressSnapshot(
		for identifier: String,
		makeSynchronous synchronous: Bool = true
	) -> InstallProgressSnapshot? {

		SystemInstallRuntime.progress(for: identifier, makeSynchronous: synchronous)
	}
}
