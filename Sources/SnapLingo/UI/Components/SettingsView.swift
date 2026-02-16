import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var isSaved: Bool = false
    @FocusState private var isAPIKeyFieldFocused: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Google Cloud APIs")) {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
                    .focused($isAPIKeyFieldFocused)
                
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
}
