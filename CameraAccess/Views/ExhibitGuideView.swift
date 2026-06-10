/*
 * Exhibit Guide View
 * 自动拍照 -> OCR -> Gemini 图文讲解 -> TTS
 */

import SwiftUI

struct ExhibitGuideView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var tts = TTSService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var resultText: String?
    @State private var ocrText: String?
    @State private var errorMessage: String?
    @State private var capturedImage: UIImage?
    @State private var statusText = "准备中..."
    @State private var showImagePicker = false

    private let ocrService = ImageOCRService()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xl) {
                        previewSection
                        statusSection
                        actionSection
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding()
                }
            }
            .navigationTitle("exhibitguide.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        closeView()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            await runGuideFlow()
        }
        .sheet(isPresented: $showImagePicker) {
            MediaPickerView(mode: .image) { url, _ in
                capturedImage = UIImage(contentsOfFile: url.path)
                Task {
                    await runGuideFlow(with: capturedImage)
                }
            }
        }
    }

    private var previewSection: some View {
        ZStack {
            if let photo = capturedImage {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(AppCornerRadius.lg)
            } else if let frame = streamViewModel.currentVideoFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(AppCornerRadius.lg)
            } else {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                    .fill(Color.gray.opacity(0.25))
                    .overlay {
                        VStack(spacing: AppSpacing.md) {
                            if !streamViewModel.hasActiveDevice {
                                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                Text("quickvision.glasses.notconnected".localized)
                                    .font(AppTypography.headline)
                                    .foregroundColor(.white)
                            } else {
                                ProgressView()
                                    .scaleEffect(1.4)
                                    .tint(.white)
                                Text(statusText)
                                    .font(AppTypography.body)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
            }

            if isProcessing, capturedImage != nil {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                    .fill(Color.black.opacity(0.55))
                    .overlay {
                        VStack(spacing: AppSpacing.md) {
                            ProgressView()
                                .scaleEffect(1.8)
                                .tint(.white)
                            Text(statusText)
                                .font(AppTypography.headline)
                                .foregroundColor(.white)
                        }
                    }
            }
        }
        .frame(maxHeight: 350)
    }

    private var statusSection: some View {
        VStack(spacing: AppSpacing.md) {
            if let resultText {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("exhibitguide.result".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            tts.speak(resultText)
                        } label: {
                            Image(systemName: tts.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .foregroundColor(.white)
                                .padding(AppSpacing.sm)
                                .background(Color.white.opacity(0.18))
                                .cornerRadius(AppCornerRadius.sm)
                        }
                    }

                    Text(resultText)
                        .font(AppTypography.body)
                        .foregroundColor(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(AppCornerRadius.md)
                }
            }

            if let ocrText, !ocrText.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("exhibitguide.ocr".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(ocrText)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(AppCornerRadius.md)
                }
            }

            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(AppTypography.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(AppCornerRadius.md)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: AppSpacing.md) {
            Button {
                Task {
                    await runGuideFlow()
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if isProcessing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "building.columns.fill")
                    }
                    Text(isProcessing ? "exhibitguide.processing".localized : "exhibitguide.retry".localized)
                }
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(
                    LinearGradient(
                        colors: isProcessing ? [Color.gray, Color.gray.opacity(0.7)] : [Color(hex: "6B705C"), Color(hex: "A98467")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppCornerRadius.lg)
            }
            .disabled(isProcessing)

            Button {
                showImagePicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("exhibitguide.pick.photo".localized)
                }
                .font(AppTypography.subheadline)
                .foregroundColor(.white)
                .padding(.vertical, AppSpacing.md)
                .padding(.horizontal, AppSpacing.xl)
                .background(Color.white.opacity(0.14))
                .cornerRadius(AppCornerRadius.md)
            }
            .disabled(isProcessing)

            if tts.isSpeaking {
                Button {
                    tts.stop()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("quickvision.stop.speaking".localized)
                    }
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, AppSpacing.md)
                    .padding(.horizontal, AppSpacing.xl)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(AppCornerRadius.md)
                }
            }
        }
    }

    private func runGuideFlow(with providedImage: UIImage? = nil) async {
        guard !isProcessing else { return }

        isProcessing = true
        resultText = nil
        ocrText = nil
        errorMessage = nil
        capturedImage = nil

        do {
            guard let googleAPIKey = APIKeyManager.shared.getGoogleAPIKey(), !googleAPIKey.isEmpty else {
                throw GeminiExhibitGuideError.missingGeminiKey
            }

            let photo: UIImage
            if let providedImage {
                statusText = "exhibitguide.status.preparing.photo".localized
                photo = providedImage
            } else {
                guard streamViewModel.hasActiveDevice else {
                    throw QuickVisionError.noDevice
                }

                statusText = "exhibitguide.status.capturing".localized
                tts.speak(statusText)
                photo = try await capturePhoto()
            }
            capturedImage = photo

            statusText = "exhibitguide.status.ocr".localized
            let recognized = try await ocrService.recognizeText(from: photo)
            ocrText = recognized.fullText

            statusText = "exhibitguide.status.explaining".localized
            tts.prepareAudioSession()

            let guide = try await GeminiExhibitGuideService(apiKey: googleAPIKey).generateGuide(
                image: photo,
                ocrText: recognized.fullText,
                responseLanguage: LanguageManager.staticIsChinese ? "中文" : "English"
            )

            resultText = guide
            QuickVisionStorage.shared.saveRecord(
                QuickVisionRecord(
                    mode: .docent,
                    prompt: recognized.fullText,
                    result: guide,
                    thumbnail: photo
                )
            )
            tts.speak(guide)
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? error.localizedDescription
            tts.speak(errorMessage ?? "处理失败")
        } catch {
            errorMessage = error.localizedDescription
            tts.speak("处理失败")
        }

        isProcessing = false
    }

    private func capturePhoto() async throws -> UIImage {
        if streamViewModel.streamingStatus != .streaming {
            await streamViewModel.handleStartStreaming()

            var streamWait = 0
            while streamViewModel.streamingStatus != .streaming && streamWait < 50 {
                try await Task.sleep(nanoseconds: 100_000_000)
                streamWait += 1
            }

            if streamViewModel.streamingStatus != .streaming {
                throw QuickVisionError.streamNotReady
            }
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        streamViewModel.dismissPhotoPreview()
        streamViewModel.capturePhoto()

        var photoWait = 0
        while streamViewModel.capturedPhoto == nil && photoWait < 30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            photoWait += 1
        }

        let photo = streamViewModel.capturedPhoto ?? streamViewModel.currentVideoFrame
        await streamViewModel.stopSession()

        guard let photo else {
            throw QuickVisionError.frameTimeout
        }

        return photo
    }

    private func closeView() {
        tts.stop()
        Task {
            await streamViewModel.stopSession()
        }
        dismiss()
    }
}
