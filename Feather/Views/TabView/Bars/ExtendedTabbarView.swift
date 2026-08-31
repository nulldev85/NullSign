import SwiftUI

@available(iOS 18, *)
struct ExtendedTabbarView: View {
	@State private var selectedTab: TabEnum = .signer

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				Tab(tab.title, systemImage: tab.icon, value: tab) {
					TabEnum.view(for: tab)
				}
			}
		}
		.tint(.cyan)
	}
}
