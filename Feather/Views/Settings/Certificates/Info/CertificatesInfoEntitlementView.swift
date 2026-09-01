import SwiftUI

struct CertificatesInfoEntitlementView: View {
	let entitlements: [String: AnyCodable]

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 10) {
				ForEach(entitlements.keys.sorted(), id: \.self) { key in
					if let value = entitlements[key]?.value {
						CertificatesInfoEntitlementCellView(key: key, value: value)
							.padding(14)
							.frame(maxWidth: .infinity, alignment: .leading)
							.background(NullSignStyle.panel)
							.overlay {
								RoundedRectangle(cornerRadius: 14, style: .continuous)
									.stroke(NullSignStyle.hairline, lineWidth: 1)
							}
							.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
					}
				}
			}
			.padding(.horizontal, 16)
			.padding(.top, 12)
			.padding(.bottom, 28)
		}
		.background(Color.black.ignoresSafeArea())
		.navigationTitle("Entitlements")
	}
}
