import SwiftUI
import AltSourceKit
import NukeUI

struct SourceNewsCardView: View {
	let new: ASRepository.News

	var body: some View {
		HStack(spacing: 0) {
			_newsImage
			VStack(alignment: .leading, spacing: 6) {
				Text(new.title)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(.primary)
					.lineLimit(3)
					.multilineTextAlignment(.leading)
				Spacer(minLength: 0)
				if let date = new.date?.date {
					Text(date.formatted(date: .abbreviated, time: .omitted))
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}
			.padding(11)
			.frame(width: 128, alignment: .leading)
		}
		.frame(width: 230, height: 112)
		.background(NullSignStyle.panel)
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.stroke(NullSignStyle.hairline, lineWidth: 1)
		}
	}

	@ViewBuilder
	private var _newsImage: some View {
		if let url = new.imageURL {
			LazyImage(url: url) { state in
				if let image = state.image {
					image.resizable().aspectRatio(contentMode: .fill)
				} else {
					_placeholder
				}
			}
			.frame(width: 102, height: 112)
			.clipped()
		} else {
			_placeholder.frame(width: 102, height: 112)
		}
	}

	private var _placeholder: some View {
		ZStack {
			NullSignStyle.raisedPanel
			Image(systemName: "newspaper")
				.font(.title3)
				.foregroundStyle(NullSignStyle.accent)
		}
	}
}

