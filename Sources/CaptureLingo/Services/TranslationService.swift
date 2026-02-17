import Foundation

class TranslationService {
    static let shared = TranslationService()

    private let apiKeyUserDefaultsKey = "GoogleTranslateAPIKey"
    private let legacyAPIKeyUserDefaultsKey = "GeminiAPIKey"
    private let targetLanguageUserDefaultsKey = "TargetLanguage"

    private var apiKey: String {
        let key = UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey)
            ?? UserDefaults.standard.string(forKey: legacyAPIKeyUserDefaultsKey)
            ?? ""
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var defaultTargetLanguage: String {
        let configured = UserDefaults.standard.string(forKey: targetLanguageUserDefaultsKey)
            ?? "ja"
        return configured.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    func storedAPIKey() -> String {
        apiKey
    }

    func setAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: apiKeyUserDefaultsKey)
    }

    func generateTranslation(for text: String, targetLanguage: String? = nil) async throws -> String {
        let output = try await generateTranslationOutput(for: text, targetLanguage: targetLanguage)
        return output.translatedText
    }

    func generateTranslationOutput(for text: String, targetLanguage: String? = nil) async throws -> TranslationOutput {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "TranslationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Google Translate API key not set"])
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw NSError(domain: "TranslationService", code: 422, userInfo: [NSLocalizedDescriptionKey: "No text detected in selected area"])
        }

        let target = (targetLanguage ?? defaultTargetLanguage).lowercased()
        if target.hasPrefix("ja"), shouldKeepOriginalTextAsJapanese(trimmedText) {
            return TranslationOutput(translatedText: trimmedText, detectedSourceLanguage: "ja")
        }

        var components = URLComponents(string: "https://translation.googleapis.com/language/translate/v2")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else {
            throw NSError(domain: "TranslationService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Google Translate API URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "q": trimmedText,
            "target": target,
            "format": "text"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TranslationService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Google Translate API response"])
        }

        guard httpResponse.statusCode == 200 else {
            let apiError = extractAPIErrorMessage(from: data)
            throw NSError(domain: "TranslationService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google Translate API Error: \(apiError)"])
        }

        let result = try JSONDecoder().decode(GoogleTranslateResponse.self, from: data)
        let translationEntry = result.data?.translations?.first
        let translated = translationEntry?.translatedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalized = decodeCommonHTMLEntities(in: translated)
        let detectedSourceLanguage = translationEntry?.detectedSourceLanguage?.lowercased()

        if normalized.isEmpty {
            throw NSError(domain: "TranslationService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Empty response from Google Translate API"])
        }

        // If source and target are effectively the same, return original OCR text as-is.
        if let detectedSourceLanguage, detectedSourceLanguage.hasPrefix(target) {
            return TranslationOutput(
                translatedText: trimmedText,
                detectedSourceLanguage: detectedSourceLanguage
            )
        }

        return TranslationOutput(
            translatedText: normalized,
            detectedSourceLanguage: detectedSourceLanguage
        )
    }

    private func extractAPIErrorMessage(from data: Data) -> String {
        if let apiError = try? JSONDecoder().decode(GoogleTranslateErrorEnvelope.self, from: data),
           let message = apiError.error?.message,
           !message.isEmpty {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown Error"
    }

    private func decodeCommonHTMLEntities(in text: String) -> String {
        text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func shouldKeepOriginalTextAsJapanese(_ text: String) -> Bool {
        let latinSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        if text.unicodeScalars.contains(where: { latinSet.contains($0) }) {
            return false
        }

        // Treat as Japanese only when kana is present to avoid skipping Chinese text.
        let hasKana = text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value)
        }
        if hasKana {
            return true
        }

        return false
    }
}

struct TranslationOutput {
    let translatedText: String
    let detectedSourceLanguage: String?
}

struct GoogleTranslateResponse: Codable {
    let data: GoogleTranslateData?
}

struct GoogleTranslateData: Codable {
    let translations: [GoogleTranslation]?
}

struct GoogleTranslation: Codable {
    let translatedText: String?
    let detectedSourceLanguage: String?
}

struct GoogleTranslateErrorEnvelope: Codable {
    let error: GoogleTranslateErrorDetail?
}

struct GoogleTranslateErrorDetail: Codable {
    let code: Int?
    let message: String?
}
