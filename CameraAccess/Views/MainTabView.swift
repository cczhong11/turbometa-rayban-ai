/*
 * Main Tab View
 * 主 Tab 导航视图
 */

import SwiftUI

struct MainTabView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel

    @State private var selectedTab = 0

    // Read API Key from secure storage
    private var apiKey: String {
        APIKeyManager.shared.getAPIKey() ?? ""
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TurboMetaHomeView(streamViewModel: streamViewModel, wearablesViewModel: wearablesViewModel, apiKey: apiKey)
                .tabItem {
                    Label("tab.home".localized, systemImage: "house.fill")
                }
                .tag(0)

            BookLibraryView()
                .tabItem {
                    Label("读书", systemImage: "books.vertical.fill")
                }
                .tag(1)

            ChatReplyWorkspaceView()
                .tabItem {
                    Label("聊天", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(2)

            SettingsView(streamViewModel: streamViewModel, apiKey: apiKey)
                .tabItem {
                    Label("tab.settings".localized, systemImage: "person.fill")
                }
                .tag(3)
        }
        .accentColor(AppColors.primary)
    }
}
