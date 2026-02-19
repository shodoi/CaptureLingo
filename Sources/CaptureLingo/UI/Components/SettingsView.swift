import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var isSaved: Bool = false
    @FocusState private var isAPIKeyFieldFocused: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Google Cloud APIs")) {
                HStack(spacing: 8) {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 300)
                        .focused($isAPIKeyFieldFocused)

                    Button("Paste") {
                        pasteAPIKeyFromClipboard()
                    }
                    .keyboardShortcut("v", modifiers: [.command])
                    .help("Paste API key from clipboard (⌘V)")
                }
                
                Button("Save API Key") {
                    TranslationService.shared.setAPIKey(apiKey)
                    isSaved = true
                    WindowManager.shared.startCaptureAfterSettingsSave()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isSaved = false
                    }
                }
                .disabled(apiKey.isEmpty)
                
                if isSaved {
                    Text("Saved!")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Text("Enable Cloud Translation API + Cloud Vision API for this key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
        .onAppear {
            apiKey = TranslationService.shared.storedAPIKey()
            DispatchQueue.main.async {
                isAPIKeyFieldFocused = true
            }
        }
    }

    private func pasteAPIKeyFromClipboard() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else {
            return
        }
        apiKey = value
        isAPIKeyFieldFocused = true
    }
}
