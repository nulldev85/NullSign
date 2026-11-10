import Foundation

public final class InstallerStatusViewModel {
	public enum InstallerStatus {
		case none, ready, sendingManifest, sendingPayload, installing
		case completed(Result<Void, Error>)
		case broken(Error)
	}
	public var status: InstallerStatus = .none
	public init() {}
}
