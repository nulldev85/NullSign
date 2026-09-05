import SwiftUI

struct InstallationView: View {
	@AppStorage("Feather.installationMethod") private var _installationMethod = 0
	@State private var _showMethodChangedAlert = false

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
					Picker("Installation method", selection: $_installationMethod) {
						Text("iPhone").tag(0)
						Text("Apple TV / Tunnel").tag(1)
					}
					.pickerStyle(.segmented)
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
		.background(Color.black.ignoresSafeArea())
		.navigationTitle("Installation")
		.onChange(of: _installationMethod) { newValue in
			guard newValue == 1 else { return }
			_showMethodChangedAlert = true
		}
		.alert("Apple TV & Device", isPresented: $_showMethodChangedAlert) {
			Button("Use iPhone Instead", role: .destructive) {
				_installationMethod = 0
			}
			Button("Continue", role: .cancel) { }
		} message: {
			Text("Apple TV pairing works over Wi-Fi without a VPN or imported pairing file. The pairing file and loopback VPN are only for installing directly on this iPhone.")
		}
		.animation(.easeInOut(duration: 0.2), value: _installationMethod)
	}
}
