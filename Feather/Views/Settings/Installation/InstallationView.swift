import SwiftUI

struct InstallationView: View {
	@AppStorage("Feather.installationMethod") private var _installationMethod = 0

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				NullSignSettingsIntro(
					systemImage: _installationMethod == 0 ? "iphone" : "appletv.fill",
					title: _installationMethod == 0 ? "Install on iPhone" : "Apple TV & Device",
					detail: _installationMethod == 0
						? "Installs through a temporary local web service on this iPhone."
						: "Pairs with Apple TV over Wi-Fi, or uses the advanced tunnel for this iPhone.",
					status: _installationMethod == 0 ? "Recommended" : "Advanced",
					statusColor: _installationMethod == 0 ? NullSignStyle.accent : NullSignStyle.warning
				)

				NullSignSettingsSection(
					"Delivery Route",
					detail: "The route is used only after an app has signed and passed verification."
				) {
					NullSignSegmentedControl(
						options: [0, 1], selection: $_installationMethod,
						title: { $0 == 0 ? "iPhone" : "Apple TV / Tunnel" }
					)
				}

				if _installationMethod == 0 {
					ServerView()
				} else {
					TunnelView()
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 28)
		}
		.nullSignPage()
		.nullSignNavigationTitle("Installation")
		.animation(.easeInOut(duration: 0.2), value: _installationMethod)
	}
}
