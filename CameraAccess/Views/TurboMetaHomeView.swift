/*
 * TurboMeta Home View
 * 精简后的主页 - 保留 Live AI，新增读书和聊天入口
 */

import SwiftUI

enum HomeCardType: String, CaseIterable, Identifiable {
    case liveAI
    case bookSummary
    case chatReply

    var id: String { rawValue }

    var visibilityKey: String {
        switch self {
        case .liveAI:
            return "home.card.liveAI.visible"
        case .bookSummary:
            return "home.card.bookSummary.visible"
        case .chatReply:
            return "home.card.chatReply.visible"
        }
    }

    var title: String {
        switch self {
        case .liveAI:
            return "cardsettings.liveai.title".localized
        case .bookSummary:
            return "cardsettings.booksummary.title".localized
        case .chatReply:
            return "cardsettings.chatreply.title".localized
        }
    }

    var description: String {
        switch self {
        case .liveAI:
            return "cardsettings.liveai.description".localized
        case .bookSummary:
            return "cardsettings.booksummary.description".localized
        case .chatReply:
            return "cardsettings.chatreply.description".localized
        }
    }

    var icon: String {
        switch self {
        case .liveAI:
            return "waveform.badge.mic"
        case .bookSummary:
            return "books.vertical.fill"
        case .chatReply:
            return "bubble.left.and.bubble.right.fill"
        }
    }

    var gradient: [Color] {
        switch self {
        case .liveAI:
            return [Color(hex: "355C7D"), Color(hex: "6C5B7B")]
        case .bookSummary:
            return [Color(hex: "7D6B5D"), Color(hex: "B08968")]
        case .chatReply:
            return [Color(hex: "426B69"), Color(hex: "6A9C89")]
        }
    }
}

struct TurboMetaHomeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel
    @StateObject private var liveAIManager = LiveAIManager.shared
    let apiKey: String

    @State private var showLiveAI = false
    @State private var showBookLibrary = false
    @State private var showChatReplyWorkspace = false
    @AppStorage("home.card.liveAI.visible") private var isLiveAIVisible = true
    @AppStorage("home.card.bookSummary.visible") private var isBookSummaryVisible = true
    @AppStorage("home.card.chatReply.visible") private var isChatReplyVisible = true

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        AppColors.warmCanvasTop,
                        AppColors.warmCanvasMiddle,
                        AppColors.warmCanvasBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        headerSection

                        VStack(spacing: AppSpacing.md) {
                            homeCardsSection
                        }

                        focusSection
                    }
                    .padding(AppSpacing.lg)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showLiveAI) {
                LiveAIView(streamViewModel: streamViewModel, apiKey: apiKey)
            }
            .fullScreenCover(isPresented: $showBookLibrary) {
                BookLibraryView()
            }
            .fullScreenCover(isPresented: $showChatReplyWorkspace) {
                ChatReplyWorkspaceView()
            }
        }
        .onAppear {
            liveAIManager.setStreamViewModel(streamViewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .liveAITriggered)) { _ in
            showLiveAI = true
        }
    }

    @ViewBuilder
    private var homeCardsSection: some View {
        if isLiveAIVisible {
            FeatureCardWide(
                title: HomeCardType.liveAI.title,
                subtitle: streamViewModel.hasActiveDevice ? "cardsettings.liveai.connected".localized : "cardsettings.liveai.disconnected".localized,
                icon: HomeCardType.liveAI.icon,
                gradient: HomeCardType.liveAI.gradient
            ) {
                showLiveAI = true
            }
        }

        let visibleSecondaryCards = secondaryCards.filter(\.isVisible)

        if visibleSecondaryCards.count == 2 {
            HStack(spacing: AppSpacing.md) {
                ForEach(visibleSecondaryCards) { card in
                    FeatureCard(
                        title: card.type.title,
                        subtitle: card.subtitle,
                        icon: card.type.icon,
                        gradient: card.type.gradient,
                        action: card.action
                    )
                }
            }
        } else if let card = visibleSecondaryCards.first {
            FeatureCardWide(
                title: card.type.title,
                subtitle: card.subtitle,
                icon: card.type.icon,
                gradient: card.type.gradient,
                action: card.action
            )
        }

        if !isLiveAIVisible && visibleSecondaryCards.isEmpty {
            HiddenCardsPlaceholderView()
        }
    }

    private var secondaryCards: [HomeCardConfig] {
        [
            HomeCardConfig(
                type: .bookSummary,
                subtitle: HomeCardType.bookSummary.description,
                isVisible: isBookSummaryVisible,
                action: { showBookLibrary = true }
            ),
            HomeCardConfig(
                type: .chatReply,
                subtitle: HomeCardType.chatReply.description,
                isVisible: isChatReplyVisible,
                action: { showChatReplyWorkspace = true }
            )
        ]
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("TurboMeta")
                .font(AppTypography.largeTitle)
                .foregroundColor(AppColors.textPrimary)

            Text("先保留 Live AI，再把读书和聊天这两个新功能接进来。")
                .font(AppTypography.callout)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, AppSpacing.md)
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("当前重点")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HomeInfoRow(icon: "checkmark.circle.fill", text: "保留现有 Live AI，不重开新 app")
                HomeInfoRow(icon: "text.viewfinder", text: "书页功能走 iPhone 自带 OCR")
                HomeInfoRow(icon: "sparkles", text: "OCR 后只走 Gemini text-to-text")
            }
            .padding(AppSpacing.md)
            .background(AppColors.subtleOverlay)
            .cornerRadius(AppCornerRadius.lg)
        }
    }
}

struct HomeCardConfig: Identifiable {
    let type: HomeCardType
    let subtitle: String
    let isVisible: Bool
    let action: () -> Void

    var id: HomeCardType { type }
}

struct HiddenCardsPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("cardsettings.hidden.placeholder.title".localized, systemImage: "eye.slash")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("cardsettings.hidden.placeholder.subtitle".localized)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(AppColors.subtleOverlay)
        .cornerRadius(AppCornerRadius.lg)
    }
}

struct HomeInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "426B69"))
            Text(text)
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.md) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct FeatureCardWide: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.title2)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(AppSpacing.lg)
            .background(
                LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}
