import SwiftUI

struct AppIconView: View {
	@Binding var currentIcon: String?

	var body: some View {
		ScrollView {
			VStack(spacing: 22) {
				VStack(spacing: 12) {
					FRAppIconView(size: 88)
						.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
					Text("NullSign")
						.font(.title3.weight(.semibold))
					Text("NullSign currently ships with one official icon.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity)

				if currentIcon != nil {
					NullSignSettingsCard {
						Button {
							UIApplication.shared.setAlternateIconName(nil) { _ in
								currentIcon = UIApplication.shared.alternateIconName
							}
						} label: {
							NullSignSettingsRow(
								title: "Restore NullSign Icon",
								detail: "Remove an icon left by an older build",
								systemImage: "app",
								showsChevron: false
							)
						}
						.buttonStyle(.plain)
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 20)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle("App Icon")
		.onAppear {
			currentIcon = UIApplication.shared.alternateIconName
		}
	}
}
