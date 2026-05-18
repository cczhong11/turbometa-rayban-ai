/*
 * TurboMeta Home View
 * 精简后的主页 - 保留 Live AI，新增读书和聊天入口
 */

import SwiftUI

struct TurboMetaHomeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel
    @StateObject private var liveAIManager = LiveAIManager.shared
    let apiKey: String

    @State private var showLiveAI = false
    @State private var showBookLibrary = false
    @State private var showChatReplyWorkspace = false

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "F3EEE7"),
                        Color(hex: "EEF5F1"),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        headerSection

                        VStack(spacing: AppSpacing.md) {
                            FeatureCardWide(
                                title: "Live AI",
                                subtitle: streamViewModel.hasActiveDevice ? "保留现有眼镜实时对话能力" : "保留入口，未连接眼镜时会提示",
                                icon: "waveform.badge.mic",
                                gradient: [Color(hex: "355C7D"), Color(hex: "6C5B7B")]
                            ) {
                                showLiveAI = true
                            }

                            HStack(spacing: AppSpacing.md) {
                                FeatureCard(
                                    title: "书页总结",
                                    subtitle: "iPhone OCR + Gemini",
                                    icon: "books.vertical.fill",
                                    gradient: [Color(hex: "7D6B5D"), Color(hex: "B08968")]
                                ) {
                                    showBookLibrary = true
                                }

                                FeatureCard(
                                    title: "聊天回复",
                                    subtitle: "截图分析和建议",
                                    icon: "bubble.left.and.bubble.right.fill",
                                    gradient: [Color(hex: "426B69"), Color(hex: "6A9C89")]
                                ) {
                                    showChatReplyWorkspace = true
                                }
                            }
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
            .background(Color.white.opacity(0.95))
            .cornerRadius(AppCornerRadius.lg)
        }
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
