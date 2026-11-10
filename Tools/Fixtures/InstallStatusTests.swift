import Foundation
import IDeviceSwift

extension String { static func localized(_ string: String) -> String { string } }

@main struct InstallStatusTests {
	static func main() {
		let model = InstallerStatusViewModel()
		let failure = NSError(domain: "NullSign.Test", code: 7)
		for status in [InstallerStatusViewModel.InstallerStatus.none, .ready, .sendingManifest, .sendingPayload, .installing] {
			model.status = status
			precondition(!model.installSucceeded && model.installFailure == nil)
			precondition(model.statusLabel != "Completed")
		}
		model.status = .completed(.failure(failure))
		precondition(!model.installSucceeded && (model.installFailure as NSError?) === failure)
		precondition(model.statusLabel == "Error" && model.statusImage == "exclamationmark.triangle.fill")
		model.status = .broken(failure)
		precondition(!model.installSucceeded && model.installFailure != nil)
		model.status = .completed(.success(()))
		precondition(model.installSucceeded && model.installFailure == nil)
		precondition(model.statusLabel == "Completed" && model.statusImage == "app.badge.checkmark")
		print("PASS installer acceptance/intermediate/failure states never display success; actual success does")
	}
}
