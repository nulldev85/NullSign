import SwiftUI

/// A blue overview above the charcoal dashboard, using live library/catalog counts.
struct NullSignOverviewBanner: View {
	let title: String
	let value: String
	let detail: String
	let systemImage: String
	var iconColor: Color = NullSignStyle.yellow
	@ScaledMetric(relativeTo: .largeTitle) private var metricSize: CGFloat = 50

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			Text(title.uppercased())
				.font(.roundedUI(.caption, weight: .heavy))
				.tracking(0.7)
				.foregroundStyle(Color.white)

			HStack(alignment: .center, spacing: 18) {
				Image(systemName: systemImage)
					.font(.roundedUI(size: 42, weight: .bold))
					.foregroundStyle(iconColor)
					.accessibilityHidden(true)
				VStack(alignment: .leading, spacing: 2) {
					Text(value)
						.font(.roundedUI(size: metricSize, weight: .heavy))
						.monospacedDigit()
						.lineLimit(1)
						.minimumScaleFactor(0.65)
					Text(detail)
						.font(.roundedUI(.subheadline, weight: .bold))
						.foregroundStyle(Color.white)
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
		.background(NullSignStyle.sky)
		.overlay(alignment: .bottom) {
			ZStack(alignment: .bottom) {
				NullSignOverviewWave(crest: 0.18)
					.fill(NullSignStyle.accent)
					.frame(height: 52)
				NullSignOverviewWave(crest: 0.55)
					.fill(NullSignStyle.teal.opacity(0.85))
					.frame(height: 38)
				RoundedRectangle(cornerRadius: 32, style: .continuous)
					.fill(NullSignStyle.ink)
					.frame(height: 60)
					.offset(y: 34)
			}
			.frame(height: 60)
			.clipped()
			.allowsHitTesting(false)
			.accessibilityHidden(true)
		}
		.accessibilityElement(children: .combine)
	}
}

private struct NullSignOverviewWave: Shape {
	var crest: CGFloat

	func path(in rect: CGRect) -> Path {
		var path = Path()
		path.move(to: CGPoint(x: 0, y: rect.height * 0.55))
		path.addQuadCurve(
			to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.48),
			control: CGPoint(x: rect.width * 0.22, y: rect.height * crest)
		)
		path.addQuadCurve(
			to: CGPoint(x: rect.width, y: rect.height * 0.3),
			control: CGPoint(x: rect.width * 0.75, y: rect.height)
		)
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
		path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
		path.closeSubpath()
		return path
	}
}
