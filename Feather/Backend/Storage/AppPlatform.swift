import Foundation
import SwiftUI

enum AppPlatform: String {
	case iOS
	case tvOS
}

extension AppInfoPresentable {
	var platform: AppPlatform {
		guard let appURL = Storage.shared.getAppDirectory(for: self),
		      let info = NSDictionary(contentsOf: appURL.appendingPathComponent("Info.plist")) else {
			return .iOS
		}

		let supported = info["CFBundleSupportedPlatforms"] as? [String] ?? []
		let families = info["UIDeviceFamily"] as? [Int] ?? []
		return supported.contains(where: { $0.localizedCaseInsensitiveContains("AppleTV") }) || families.contains(3)
			? .tvOS
			: .iOS
	}
}

struct PlatformBadge: View {
	let platform: AppPlatform

	var body: some View {
		if platform == .tvOS {
			Text("tvOS")
				.font(.system(size: 9, weight: .bold, design: .rounded))
				.foregroundStyle(.black.opacity(0.78))
				.padding(.horizontal, 6)
				.frame(height: 17)
				.background(NullSignStyle.peach)
				.clipShape(Capsule())
				.accessibilityLabel("Apple TV app")
		}
	}
}
