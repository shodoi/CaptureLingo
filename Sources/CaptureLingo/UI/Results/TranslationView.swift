import SwiftUI

struct TranslationView: View {
    let originalImage: NSImage
    let recognizedText: String
    let detectedLanguageHint: String?
    let imageDisplaySize: NSSize
    @State private var translation: String = "Translating..."
    @State private var errorMessage: String?
    @State private var detectedLanguageLabel: String?
    @State private var isTranslating: Bool = false
    @State private var translationTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    WindowManager.shared.closeResultPanel()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.97, green: 0.32, blue: 0.31))
                            .frame(width: 14, height: 14)
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }

            Image(nsImage: originalImage)
                .resizable()
                .interpolation(.high)
                .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
            
            Divider()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let detectedLanguageLabel {
                    Text(detectedLanguageLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(translation)
                    .font(.system(size: 16))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack {
                Spacer()
                if isTranslating {
                    Button("Stop") {
                        cancelTranslation()
                    }
                }
                Button("Capture Again") {
                    cancelTranslation()
                    WindowManager.shared.closeResultPanel()
                    WindowManager.shared.showCaptureOverlay()
                }
                Button("Copy") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(translation, forType: .string)
                }
            }
        }
        .padding()
        .frame(minWidth: max(320, imageDisplaySize.width), alignment: .leading)
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

    private func formatLanguageLabel(_ languageCode: String?) -> String? {
        guard let languageCode else { return nil }
        let normalized = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        guard !normalized.isEmpty else { return nil }

        // Prefer explicit naming for Traditional Chinese (Taiwan).
        if normalized == "zh-tw" || normalized == "zh-hant-tw" {
            return "Language: 繁体中文（台湾）"
        }

        if let exact = Locale.current.localizedString(forIdentifier: normalized), !exact.isEmpty {
            return "Language: \(exact)"
        }

        let baseCode = normalized.split(separator: "-").first.map(String.init) ?? normalized
        if let base = Locale.current.localizedString(forLanguageCode: baseCode), !base.isEmpty {
            return "Language: \(base)"
        }

        return "Language: \(normalized)"
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
