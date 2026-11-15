import SwiftUI

/// A charcoal overview using the same palette as Settings and live app counts.
struct NullSignOverviewBanner: View {
	let title: String
	let value: String
	let detail: String
	let systemImage: String
	var iconColor: Color? = nil
	@ScaledMetric(relativeTo: .largeTitle) private var metricSize: CGFloat = 50

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text(title.uppercased())
				.font(.roundedUI(.caption, weight: .heavy))
				.tracking(0.7)
				.foregroundStyle(NullSignStyle.muted)

			HStack(alignment: .center, spacing: 18) {
				Image(systemName: systemImage)
					.font(.roundedUI(size: 42, weight: .bold))
					.foregroundStyle(iconColor ?? NullSignStyle.categoryColor(for: systemImage))
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 2) {
					Text(value)
						.font(.roundedUI(size: metricSize, weight: .heavy))
						.monospacedDigit()
						.lineLimit(1)
						.minimumScaleFactor(0.65)
					Text(detail)
						.font(.roundedUI(.subheadline, weight: .bold))
						.foregroundStyle(NullSignStyle.muted)
						.fixedSize(horizontal: false, vertical: true)
				}
				Spacer(minLength: 0)
			}
		}
		.foregroundStyle(.white)
		.padding(.horizontal, 28)
		.padding(.top, 14)
		.padding(.bottom, 70)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(NullSignStyle.canvas)
		.overlay(alignment: .bottom) {
			// Show only the card's top edge and its complete rounded corners.
			// No filled wave extends beyond the outline into the overview.
			RoundedRectangle(cornerRadius: NullSignStyle.cardRadius, style: .continuous)
				.strokeBorder(NullSignStyle.faint.opacity(0.35), lineWidth: 1)
				.frame(height: 60)
				.offset(y: 34)
				.clipped()
				.allowsHitTesting(false)
				.accessibilityHidden(true)
		}
		.accessibilityElement(children: .combine)
	}
}
