import Cocoa
import SwiftUI

class WindowManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = WindowManager()
    
    var overlayWindows: [OverlayWindow] = []
    var resultPanel: NSPanel?
    var settingsWindow: NSWindow?
    private var isCaptureCursorPushed = false
    
    private override init() {
        super.init()
    }

    private func applyCaptureCursor() {
        if !isCaptureCursorPushed {
            NSCursor.crosshair.push()
            isCaptureCursorPushed = true
        }
        NSCursor.crosshair.set()
    }

    func showCaptureOverlay() {
        print("WindowManager: showCaptureOverlay called")
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        resultPanel?.orderOut(nil)
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            print("WindowManager: No screens available for overlay")
            return
        }

        for screen in screens {
            print("WindowManager: Creating overlay for screen frame: \(screen.frame)")
            let overlay = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            overlayWindows.append(overlay)
        }

        applyCaptureCursor()
        if let firstOverlay = overlayWindows.first {
            firstOverlay.makeMain()
            firstOverlay.makeKeyAndOrderFront(nil)
        }
        overlayWindows.dropFirst().forEach { $0.orderFront(nil) }

        // Menu tracking can reset the cursor to arrow right after the overlay appears.
        // Re-apply briefly to make the crosshair transition deterministic.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self, !self.overlayWindows.isEmpty else { return }
            self.applyCaptureCursor()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, !self.overlayWindows.isEmpty else { return }
            self.applyCaptureCursor()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, !self.overlayWindows.isEmpty else { return }
            self.applyCaptureCursor()
        }
        print("WindowManager: Overlay ordered front")
    }
    
    func hideCaptureOverlay() {
        print("WindowManager: hideCaptureOverlay called")
        overlayWindows.forEach { $0.close() }
        overlayWindows.removeAll()
        if isCaptureCursorPushed {
            NSCursor.pop()
            isCaptureCursorPushed = false
        }
        NSCursor.arrow.set()
    }
    
    func capture(rect: CGRect) {
        print("WindowManager: Capturing rect: \(rect)")
        guard rect.width >= 2, rect.height >= 2 else {
            hideCaptureOverlay()
            return
        }

        // Hide overlay first, then capture the active Space directly.
        overlayWindows.forEach { $0.orderOut(nil) }
        let captureRect = rect.integral
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let image = ScreenCaptureService.shared.capture(rect: captureRect) else {
                print("WindowManager: Failed to capture image")
                self?.hideCaptureOverlay()
                return
            }
            print("WindowManager: Captured image size: \(image.width)x\(image.height)")

            self?.hideCaptureOverlay()
            self?.processCapturedImage(image, displaySize: rect.size)
        }
    }
    
    func processCapturedImage(_ image: CGImage, displaySize: CGSize) {
        // Start OCR
        print("WindowManager: Starting OCR")
        OCRService.shared.recognizeText(from: image) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocrResult):
                    print("OCR Success: \(ocrResult.text)")
                    self?.showResultPanel(
                        image: image,
                        text: ocrResult.text,
                        detectedLanguageHint: ocrResult.detectedLanguage,
                        displaySize: displaySize
                    )
                case .failure(let error):
                    print("OCR Failed: \(error)")
                    self?.showResultPanel(
                        image: image,
                        text: "",
                        detectedLanguageHint: nil,
                        displaySize: displaySize
                    )
                }
            }
        }
    }
    
    func showResultPanel(
        image: CGImage,
        text: String,
        detectedLanguageHint: String?,
        displaySize: CGSize
    ) {
        NSApp.setActivationPolicy(.accessory)
        if resultPanel == nil {
            let panel = ResultPanel(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = true
            panel.center()
            self.resultPanel = panel
        }
        
        let pointSize = NSSize(width: max(1, displaySize.width), height: max(1, displaySize.height))
        let nsImage = NSImage(cgImage: image, size: pointSize)
        let contentView = NSHostingController(
            rootView: TranslationView(
                originalImage: nsImage,
                recognizedText: text,
                detectedLanguageHint: detectedLanguageHint,
                imageDisplaySize: pointSize
            )
        )
        resultPanel?.contentViewController = contentView

        resizeResultPanelToFitContent()

        resultPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func resizeResultPanelToFitContent() {
        guard let panel = resultPanel, let contentView = panel.contentViewController?.view else { return }

        contentView.layoutSubtreeIfNeeded()
        var fittingSize = contentView.fittingSize

        fittingSize.width = max(320, fittingSize.width)
        fittingSize.height = max(120, fittingSize.height)

        guard fittingSize.width > 0, fittingSize.height > 0 else { return }
        panel.setContentSize(fittingSize)
    }
    
    func closeResultPanel() {
        resultPanel?.close()
        resultPanel = nil
    }

    func startCaptureAfterSettingsSave() {
        NSApp.setActivationPolicy(.accessory)
        settingsWindow?.close()
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Capture Lingo Settings"
            window.level = .floating
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.settingsWindow = window
        }
        
        let contentView = NSHostingController(rootView: SettingsView())
        settingsWindow?.contentViewController = contentView

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.makeMain()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow, closedWindow == settingsWindow else {
            return
        }
        settingsWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
