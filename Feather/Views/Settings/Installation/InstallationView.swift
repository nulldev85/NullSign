import SwiftUI

struct InstallationView: View {
	@AppStorage("Feather.installationMethod") private var _installationMethod = 0
	@State private var _showMethodChangedAlert = false

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				NullSignSettingsIntro(
					systemImage: _installationMethod == 0 ? "network" : "cable.connector",
					title: _installationMethod == 0 ? "Local Server" : "Device Tunnel",
					detail: _installationMethod == 0
						? "Installs through a temporary local web service on this iPhone."
						: "Installs directly through a pairing file and local VPN connection.",
					status: _installationMethod == 0 ? "Recommended" : "Advanced",
					statusColor: _installationMethod == 0 ? NullSignStyle.cyan : NullSignStyle.peach
				)

				NullSignSettingsSection(
					"Delivery Route",
					detail: "The route is used only after an app has signed and passed verification."
				) {
					Picker("Installation method", selection: $_installationMethod) {
						Text("Server").tag(0)
						Text("Device").tag(1)
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
		.alert("Device Tunnel", isPresented: $_showMethodChangedAlert) {
			Button("Use Server Instead", role: .destructive) {
				_installationMethod = 0
			}
			Button("Continue", role: .cancel) { }
		} message: {
			Text("This method needs a pairing file and an active loopback VPN. Use it when the server method is unavailable or unreliable.")
		}
		.animation(.easeInOut(duration: 0.2), value: _installationMethod)
	}
}
