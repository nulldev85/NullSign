import Foundation

/// Milestones come from the signing handler; they are not a simulated timer.
enum AppSigningStage: String {
	case preparing = "Preparing App"
	case modifying = "Applying Settings"
	case signing = "Signing"
	case verifying = "Verifying"

	var progress: Double {
		switch self {
		case .preparing: return 0.03
		case .modifying: return 0.08
		case .signing: return 0.14
		case .verifying: return 0.28
		}
	}
}
