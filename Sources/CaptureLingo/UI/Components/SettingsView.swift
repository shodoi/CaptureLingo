import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var selectedLanguage: String = "ja"
    @State private var isSaved: Bool = false
    @FocusState private var isAPIKeyFieldFocused: Bool

    // Supported target languages
    private let supportedLanguages: [(code: String, label: String)] = [
        ("ja", "日本語 (ja)"),
        ("en", "English (en)"),
        ("zh-CN", "简体中文 (zh-CN)"),
        ("zh-TW", "繁體中文 (zh-TW)"),
        ("ko", "한국어 (ko)"),
        ("fr", "Français (fr)"),
        ("de", "Deutsch (de)"),
        ("es", "Español (es)"),
        ("it", "Italiano (it)"),
        ("pt", "Português (pt)"),
        ("ru", "Русский (ru)"),
        ("ar", "العربية (ar)"),
        ("hi", "हिन्दी (hi)"),
        ("th", "ไทย (th)"),
        ("vi", "Tiếng Việt (vi)"),
        ("id", "Bahasa Indonesia (id)"),
        ("ms", "Bahasa Melayu (ms)"),
        ("nl", "Nederlands (nl)"),
        ("pl", "Polski (pl)"),
        ("sv", "Svenska (sv)"),
        ("tr", "Türkçe (tr)"),
        ("uk", "Українська (uk)"),
    ]

    var body: some View {
        Form {
            Section(header: Text("Google Cloud API Key")) {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isAPIKeyFieldFocused)

                Text("Cloud Translation API と Cloud Vision API を有効にしてください")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Target Language")) {
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(supportedLanguages, id: \.code) { lang in
                        Text(lang.label).tag(lang.code)
                    }
                }
            }

            Section {
                HStack {
                    if isSaved {
                        Label("Saved!", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }

                    Spacer()

                    Button("Save") {
                        saveSettings()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(apiKey.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 420, height: 280)
        .onAppear {
            apiKey = TranslationService.shared.storedAPIKey()
            selectedLanguage = loadTargetLanguage()
            DispatchQueue.main.async {
                isAPIKeyFieldFocused = true
            }
        }
    }

    // MARK: - Actions

    private func saveSettings() {
        TranslationService.shared.setAPIKey(apiKey)
        saveTargetLanguage(selectedLanguage)
        isSaved = true
        WindowManager.shared.startCaptureAfterSettingsSave()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSaved = false
        }
    }

    private func loadTargetLanguage() -> String {
        (UserDefaults.standard.string(forKey: "TargetLanguage") ?? "ja")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveTargetLanguage(_ code: String) {
        UserDefaults.standard.set(code, forKey: "TargetLanguage")
    }
}
