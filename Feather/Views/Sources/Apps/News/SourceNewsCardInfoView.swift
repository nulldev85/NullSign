import SwiftUI
import AltSourceKit
import NukeUI
import NimbleViews

struct SourceNewsCardInfoView: View {
	let new: ASRepository.News

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 18) {
					_headerImage

					VStack(alignment: .leading, spacing: 10) {
						if let date = new.date?.date {
							Text(date.formatted(date: .long, time: .omitted))
								.font(.caption.weight(.medium))
								.foregroundStyle(NullSignStyle.accent)
						}

						Text(new.title)
							.font(.title2.weight(.bold))
							.fixedSize(horizontal: false, vertical: true)

						if !new.caption.isEmpty {
							Text(new.caption)
								.font(.body)
								.foregroundStyle(.secondary)
								.fixedSize(horizontal: false, vertical: true)
						}
					}

					if let url = new.url {
						Button { UIApplication.shared.open(url) } label: {
							Label(.localized("Open Link"), systemImage: "arrow.up.right")
								.font(.subheadline.weight(.semibold))
								.foregroundStyle(.black)
								.frame(maxWidth: .infinity)
								.frame(height: 42)
								.background(NullSignStyle.accent)
								.clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
						}
						.buttonStyle(.plain)
					}
				}
				.padding(16)
			}
			.background(Color.black)
			.toolbar { NBToolbarButton(role: .close) }
		}
		.tint(NullSignStyle.accent)
	}

	@ViewBuilder
	private var _headerImage: some View {
		if let url = new.imageURL {
			LazyImage(url: url) { state in
				if let image = state.image {
					image.resizable().aspectRatio(contentMode: .fill)
				} else {
					_placeholder
				}
			}
			.frame(height: 210)
			.frame(maxWidth: .infinity)
			.clipped()
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		} else {
			_placeholder
				.frame(height: 150)
				.frame(maxWidth: .infinity)
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		}
	}

	private var _placeholder: some View {
		ZStack {
			NullSignStyle.panel
			Image(systemName: "newspaper")
				.font(.largeTitle)
				.foregroundStyle(NullSignStyle.accent)
		}
	}
}
