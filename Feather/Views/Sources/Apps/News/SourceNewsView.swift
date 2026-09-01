import SwiftUI
import AltSourceKit

struct SourceNewsView: View {
	@State private var _selectedNews: ASRepository.News?
	@Namespace private var _namespace

	let news: [ASRepository.News]?

	var body: some View {
		if let news, !news.isEmpty {
			VStack(alignment: .leading, spacing: 9) {
				SourceSectionLabel(title: .localized("Updates"), count: news.count)
					.padding(.horizontal, 16)

				ScrollView(.horizontal, showsIndicators: false) {
					LazyHStack(spacing: 10) {
						ForEach(news.reversed(), id: \.id) { item in
							Button {
								_selectedNews = item
							} label: {
								SourceNewsCardView(new: item)
									.compatMatchedTransitionSource(id: item.id, ns: _namespace)
							}
							.buttonStyle(.plain)
						}
					}
					.padding(.horizontal, 16)
				}
			}
			.padding(.top, 8)
			.frame(height: 174, alignment: .top)
			.fullScreenCover(item: $_selectedNews) { item in
				SourceNewsCardInfoView(new: item)
					.compatNavigationTransition(id: item.id, ns: _namespace)
			}
		}
	}
}
