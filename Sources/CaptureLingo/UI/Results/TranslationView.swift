import SwiftUI

struct TranslationView: View {
    private let maxPreviewWidth: CGFloat = 680
    private let maxPreviewHeight: CGFloat = 200

    let originalImage: NSImage
    let recognizedText: String
    let detectedLanguageHint: String?
    let imageDisplaySize: NSSize
    @State private var translation: String = "Translating..."
    @State private var errorMessage: String?
    @State private var detectedLanguageLabel: String?
    @State private var isTranslating: Bool = false
    @State private var translationTask: Task<Void, Never>?
    @State private var copyFeedback: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row: close dot + language badge
            HStack(alignment: .center) {
                Button {
                    WindowManager.shared.closeResultPanel()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.97, green: 0.32, blue: 0.31))
                            .frame(width: 14, height: 14)
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .buttonStyle(.plain)
                .help("Close")

                Spacer()

                if let detectedLanguageLabel {
                    Text(detectedLanguageLabel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Translation text
            GroupBox {
                HStack(alignment: .top, spacing: 0) {
                    Text(errorMessage ?? translation)
                        .font(.body)
                        .foregroundColor(errorMessage != nil ? .red : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Button {
                        copyTranslationToClipboard()
                    } label: {
                        Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                            .foregroundColor(copyFeedback ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy")
                }
                .padding(4)
            }

            // Source image preview (capped height, never upscaled)
            GroupBox {
                let size = previewSize
                Image(nsImage: originalImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: size.width, maxHeight: size.height)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Action buttons
            HStack {
                Spacer()

                if isTranslating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button("Capture Again") {
                    cancelTranslation()
                    WindowManager.shared.closeResultPanel()
                    WindowManager.shared.showCaptureOverlay()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Close") {
                    cancelTranslation()
                    WindowManager.shared.closeResultPanel()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(minWidth: 480, idealWidth: 560)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .onAppear {
            startTranslation()
            WindowManager.shared.resizeResultPanelToFitContent()
        }
        .onDisappear {
            cancelTranslation()
        }
    }

    // MARK: - Helpers

    private var previewSize: CGSize {
        let sw = max(1, imageDisplaySize.width)
        let sh = max(1, imageDisplaySize.height)
        var w = sw
        var h = sh
        if w > maxPreviewWidth { let r = maxPreviewWidth / w; w = maxPreviewWidth; h *= r }
        if h > maxPreviewHeight { let r = maxPreviewHeight / h; h = maxPreviewHeight; w *= r }
        return CGSize(width: w, height: h)
    }

    private func startTranslation() {
        guard translationTask == nil else { return }
        isTranslating = true
        translationTask = Task {
            do {
                let output = try await TranslationService.shared.generateTranslationOutput(for: recognizedText)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    translation = output.translatedText
                    detectedLanguageLabel = formatLanguageLabel(
                        output.detectedSourceLanguage ?? detectedLanguageHint
                    )
                    isTranslating = false
                    translationTask = nil
                    WindowManager.shared.resizeResultPanelToFitContent()
                }
            } catch is CancellationError {
                await MainActor.run {
                    isTranslating = false
                    translationTask = nil
                    WindowManager.shared.resizeResultPanelToFitContent()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    errorMessage = "Translation failed: \(error.localizedDescription)"
                    detectedLanguageLabel = formatLanguageLabel(detectedLanguageHint)
                    isTranslating = false
                    translationTask = nil
                    WindowManager.shared.resizeResultPanelToFitContent()
                }
            }
        }
    }

    private func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        isTranslating = false
    }

    private func copyTranslationToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(translation, forType: .string)
        copyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copyFeedback = false }
    }

    private func formatLanguageLabel(_ languageCode: String?) -> String? {
        guard let languageCode else { return nil }
        let normalized = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        guard !normalized.isEmpty else { return nil }

        if normalized == "zh-tw" || normalized == "zh-hant-tw" {
            return "Language: 繁体中文（台湾）"
        }
        if let exact = Locale.current.localizedString(forIdentifier: normalized), !exact.isEmpty {
            return "Language: \(exact)"
        }
        let base = normalized.split(separator: "-").first.map(String.init) ?? normalized
        if let name = Locale.current.localizedString(forLanguageCode: base), !name.isEmpty {
            return "Language: \(name)"
        }
        return "Language: \(normalized)"
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
