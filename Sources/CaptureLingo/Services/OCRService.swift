import Vision
import Cocoa
import CoreImage

class OCRService {
    static let shared = OCRService()
    private let ciContext = CIContext(options: nil)
    
    func recognizeText(from image: CGImage, completion: @escaping (Result<OCRTextResult, Error>) -> Void) {
        Task.detached(priority: .userInitiated) {
            do {
                // Primary OCR path: Google Cloud Vision API.
                if TranslationService.shared.hasAPIKey {
                    var cloudInputs: [CGImage] = [image]
                    if let enhancedCloudImage = self.makeCloudRetryImage(from: image) {
                        cloudInputs.append(enhancedCloudImage)
                    }

                    var cloudLastError: Error?
                    for (index, input) in cloudInputs.enumerated() {
                        do {
                            let cloudResult = try await self.performCloudVisionOCR(image: input)
                            let trimmed = cloudResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
                            print("Cloud Vision OCR pass \(index + 1): \(trimmed.count) chars")
                            if self.isUsableOCRText(cloudResult.text) {
                                if let locale = cloudResult.locale, !locale.isEmpty {
                                    print("Cloud Vision detected locale: \(locale)")
                                }
                                completion(.success(OCRTextResult(text: cloudResult.text, detectedLanguage: cloudResult.locale)))
                                return
                            }
                        } catch {
                            cloudLastError = error
                            print("Cloud Vision OCR pass \(index + 1) failed: \(error)")
                        }
                    }

                    if let cloudLastError {
                        print("Cloud Vision OCR fallback to local Vision: \(cloudLastError)")
                    }
                }

                // Fallback OCR path: local Apple Vision.
                print("OCRService: Local fallback started")
                let localResult = try self.performBestLocalFallbackOCR(from: image)
                completion(.success(localResult))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func performCloudVisionOCR(image: CGImage) async throws -> CloudVisionOCRResult {
        let apiKey = TranslationService.shared.storedAPIKey()
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OCRService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Google Cloud API key not set"])
        }

        guard let imageData = encodeImageData(image) else {
            throw NSError(domain: "OCRService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image for Cloud Vision"])
        }

        var components = URLComponents(string: "https://vision.googleapis.com/v1/images:annotate")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw NSError(domain: "OCRService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Cloud Vision API URL"])
        }

        let languageHints = ["ja", "zh-TW", "zh-CN", "en", "ko", "fr", "de", "es", "it", "pt", "ru"]
        let requestBody: [String: Any] = [
            "requests": [
                [
                    "image": ["content": imageData.base64EncodedString()],
                    "features": [["type": "TEXT_DETECTION"]],
                    "imageContext": ["languageHints": languageHints]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OCRService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Cloud Vision response"])
        }

        guard httpResponse.statusCode == 200 else {
            let message = extractCloudVisionErrorMessage(from: data)
            throw NSError(domain: "OCRService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Cloud Vision API Error: \(message)"])
        }

        let result = try JSONDecoder().decode(CloudVisionBatchResponse.self, from: data)
        guard let firstResponse = result.responses?.first else {
            throw NSError(domain: "OCRService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Cloud Vision returned empty response"])
        }

        if let error = firstResponse.error?.message, !error.isEmpty {
            throw NSError(domain: "OCRService", code: firstResponse.error?.code ?? 500, userInfo: [NSLocalizedDescriptionKey: "Cloud Vision Error: \(error)"])
        }

        let text = firstResponse.fullTextAnnotation?.text
            ?? firstResponse.textAnnotations?.first?.description
            ?? ""
        let locale = firstResponse.textAnnotations?.first?.locale

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw NSError(domain: "OCRService", code: 502, userInfo: [NSLocalizedDescriptionKey: "Cloud Vision returned empty OCR text"])
        }

        return CloudVisionOCRResult(text: normalizedText, locale: locale)
    }

    private func encodeImageData(_ image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        if let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 1.0])
    }

    private func extractCloudVisionErrorMessage(from data: Data) -> String {
        if let errorEnvelope = try? JSONDecoder().decode(CloudVisionTopLevelErrorResponse.self, from: data),
           let message = errorEnvelope.error?.message,
           !message.isEmpty {
            return message
        }
        if let batch = try? JSONDecoder().decode(CloudVisionBatchResponse.self, from: data),
           let firstMessage = batch.responses?.first?.error?.message,
           !firstMessage.isEmpty {
            return firstMessage
        }
        return String(data: data, encoding: .utf8) ?? "Unknown Error"
    }

    private func performLocalFallbackOCR(image: CGImage) throws -> OCRTextResult {
        // Pass 0: Automatic language detection OCR.
        let autoText = try performOCR(
            image: image,
            recognitionLanguages: [],
            usesLanguageCorrection: true
        )
        if isUsableOCRText(autoText) {
            return OCRTextResult(text: autoText, detectedLanguage: guessLanguageCode(from: autoText))
        }

        // Pass 1: Japanese-priority OCR for Japanese UI/text.
        let japaneseText = try performOCR(
            image: image,
            recognitionLanguages: ["ja-JP"],
            usesLanguageCorrection: false
        )
        if containsJapanese(japaneseText) {
            return OCRTextResult(text: japaneseText, detectedLanguage: "ja")
        }

        // Pass 2: Traditional Chinese (Taiwan/HK) OCR fallback.
        let traditionalChineseText = try performOCR(
            image: image,
            recognitionLanguages: ["zh-Hant"],
            usesLanguageCorrection: false
        )
        if containsChinese(traditionalChineseText) {
            return OCRTextResult(text: traditionalChineseText, detectedLanguage: "zh-TW")
        }

        // Pass 3: Simplified Chinese fallback.
        let simplifiedChineseText = try performOCR(
            image: image,
            recognitionLanguages: ["zh-Hans"],
            usesLanguageCorrection: false
        )
        if containsChinese(simplifiedChineseText) {
            return OCRTextResult(text: simplifiedChineseText, detectedLanguage: "zh-CN")
        }

        // Pass 4: English-priority OCR fallback.
        let englishText = try performOCR(
            image: image,
            recognitionLanguages: ["en-US"],
            usesLanguageCorrection: true
        )
        if !englishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return OCRTextResult(text: englishText, detectedLanguage: "en")
        }

        // Pass 5: Mixed fallback.
        let mixedText = try performOCR(
            image: image,
            recognitionLanguages: ["en-US", "ja-JP", "zh-Hant", "zh-Hans", "ko-KR", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "ru-RU"],
            usesLanguageCorrection: true
        )
        return OCRTextResult(text: mixedText, detectedLanguage: guessLanguageCode(from: mixedText))
    }

    private func performBestLocalFallbackOCR(from image: CGImage) throws -> OCRTextResult {
        let variants = makeLocalOCRVariants(from: image)
        var lastResult = OCRTextResult(text: "", detectedLanguage: nil)
        var lastError: Error?

        for (index, variant) in variants.enumerated() {
            do {
                let result = try performLocalFallbackOCR(image: variant)
                lastResult = result

                let charCount = result.text.trimmingCharacters(in: .whitespacesAndNewlines).count
                print("Local Vision OCR pass \(index + 1): \(charCount) chars")
                if isUsableOCRText(result.text) {
                    return result
                }
            } catch {
                lastError = error
                print("Local Vision OCR pass \(index + 1) failed: \(error)")
            }
        }

        if let lastError {
            throw lastError
        }
        return lastResult
    }

    private func performOCR(
        image: CGImage,
        recognitionLanguages: [String],
        usesLanguageCorrection: Bool
    ) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = usesLanguageCorrection
        request.minimumTextHeight = 0.0

        let supportedLanguages = try request.supportedRecognitionLanguages()
        let filteredLanguages = recognitionLanguages.filter { supportedLanguages.contains($0) }
        if !filteredLanguages.isEmpty {
            request.recognitionLanguages = filteredLanguages
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []

        let preferJapanese = filteredLanguages.first == "ja-JP"
        let preferChinese = filteredLanguages.first == "zh-Hant"
        let recognizedText = observations.compactMap { observation -> String? in
            let candidates = observation.topCandidates(3)
            if preferJapanese, let japaneseCandidate = candidates.first(where: { containsJapanese($0.string) }) {
                return japaneseCandidate.string
            }
            if preferChinese, let chineseCandidate = candidates.first(where: { containsChinese($0.string) }) {
                return chineseCandidate.string
            }
            return candidates.first?.string
        }.joined(separator: "\n")

        return recognizedText
    }

    private func makeScaledImage(image: CGImage, scale: CGFloat) -> CGImage? {
        guard scale > 1 else { return image }

        let width = max(1, Int(CGFloat(image.width) * scale))
        let height = max(1, Int(CGFloat(image.height) * scale))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return context.makeImage()
    }

    private func makeCloudRetryImage(from image: CGImage) -> CGImage? {
        guard let scaled = makeScaledImage(image: image, scale: 2.0) else {
            return nil
        }
        return makeEnhancedImage(image: scaled) ?? scaled
    }

    private func makeLocalOCRVariants(from image: CGImage) -> [CGImage] {
        var variants: [CGImage] = [image]

        if let scaled = makeScaledImage(image: image, scale: 2.0) {
            variants.append(scaled)
        }
        if let scaledEnhanced = makeCloudRetryImage(from: image) {
            variants.append(scaledEnhanced)
            if let inverted = makeInvertedImage(image: scaledEnhanced) {
                variants.append(inverted)
            }
        }
        if let enhanced = makeEnhancedImage(image: image) {
            variants.append(enhanced)
            if let inverted = makeInvertedImage(image: enhanced) {
                variants.append(inverted)
            }
        }

        return variants
    }

    private func makeEnhancedImage(image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)

        guard let colorControls = CIFilter(name: "CIColorControls") else {
            return nil
        }
        colorControls.setValue(input, forKey: kCIInputImageKey)
        colorControls.setValue(0.0, forKey: kCIInputSaturationKey)
        colorControls.setValue(1.9, forKey: kCIInputContrastKey)
        colorControls.setValue(0.05, forKey: kCIInputBrightnessKey)
        guard var output = colorControls.outputImage else {
            return nil
        }

        if let sharpen = CIFilter(name: "CISharpenLuminance") {
            sharpen.setValue(output, forKey: kCIInputImageKey)
            sharpen.setValue(0.7, forKey: kCIInputSharpnessKey)
            if let sharpened = sharpen.outputImage {
                output = sharpened
            }
        }

        return ciContext.createCGImage(output, from: output.extent)
    }

    private func makeInvertedImage(image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let invert = CIFilter(name: "CIColorInvert") else {
            return nil
        }
        invert.setValue(input, forKey: kCIInputImageKey)
        guard let output = invert.outputImage else {
            return nil
        }
        return ciContext.createCGImage(output, from: output.extent)
    }

    private func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0x3040...0x30FF).contains(value)   // Hiragana + Katakana
                || (0x4E00...0x9FFF).contains(value)   // CJK Unified Ideographs
                || value == 0x3005                      // 々
        }
    }

    private func containsChinese(_ text: String) -> Bool {
        let hasCJK = text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
        let hasKana = text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value)
        }
        return hasCJK && !hasKana
    }

    private func isUsableOCRText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return false
        }
        return !isLikelyNoiseText(trimmed)
    }

    private func isLikelyNoiseText(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        guard !scalars.isEmpty else { return true }

        let total = Double(scalars.count)
        let alphaNum = Double(scalars.filter { CharacterSet.alphanumerics.contains($0) }.count)
        let punctuation = Double(scalars.filter { CharacterSet.punctuationCharacters.contains($0) }.count)
        let symbol = Double(scalars.filter { CharacterSet.symbols.contains($0) }.count)
        let cjk = Double(scalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count)
        let kana = Double(scalars.filter { (0x3040...0x30FF).contains($0.value) }.count)

        let nonWordRatio = (punctuation + symbol) / total
        let languageSignalRatio = (alphaNum + cjk + kana) / total

        // Typical OCR garbage has too many symbols and too little language signal.
        if nonWordRatio > 0.35 && languageSignalRatio < 0.65 {
            return true
        }

        return false
    }

    private func guessLanguageCode(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if containsJapanese(trimmed) {
            return "ja"
        }

        if containsChinese(trimmed) {
            return "zh"
        }

        let hasLatin = trimmed.unicodeScalars.contains { CharacterSet.letters.contains($0) && $0.isASCII }
        if hasLatin {
            return "en"
        }

        return nil
    }
}

struct OCRTextResult {
    let text: String
    let detectedLanguage: String?
}

private struct CloudVisionOCRResult {
    let text: String
    let locale: String?
}

private struct CloudVisionBatchResponse: Codable {
    let responses: [CloudVisionResponse]?
}

private struct CloudVisionResponse: Codable {
    let fullTextAnnotation: CloudVisionFullTextAnnotation?
    let textAnnotations: [CloudVisionTextAnnotation]?
    let error: CloudVisionError?
}

private struct CloudVisionFullTextAnnotation: Codable {
    let text: String?
}

private struct CloudVisionTextAnnotation: Codable {
    let locale: String?
    let description: String?
}

private struct CloudVisionError: Codable {
    let code: Int?
    let message: String?
}

private struct CloudVisionTopLevelErrorResponse: Codable {
    let error: CloudVisionError?
}
