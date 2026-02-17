import Cocoa
import SwiftUI

class WindowManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = WindowManager()
    
    var overlayWindow: OverlayWindow?
    var resultPanel: NSPanel?
    var settingsWindow: NSWindow?
    private var isCaptureCursorPushed = false
    
    private override init() {
        super.init()
    }
    
    func showCaptureOverlay() {
        print("WindowManager: showCaptureOverlay called")
        guard ScreenCaptureService.shared.ensureScreenRecordingPermission() else {
            showScreenRecordingPermissionAlert()
            return
        }
        NSApp.setActivationPolicy(.accessory)
        if overlayWindow == nil {
            let screenFrame = NSScreen.main?.frame ?? .zero
            print("WindowManager: Creating overlay with frame: \(screenFrame)")
            let overlay = OverlayWindow(
                contentRect: screenFrame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            self.overlayWindow = overlay
        }

        if !isCaptureCursorPushed {
            NSCursor.crosshair.push()
            isCaptureCursorPushed = true
        }
        NSCursor.crosshair.set()
        overlayWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("WindowManager: Overlay ordered front")
    }
    
    func hideCaptureOverlay() {
        print("WindowManager: hideCaptureOverlay called")
        overlayWindow?.close()
        overlayWindow = nil
        if isCaptureCursorPushed {
            NSCursor.pop()
            isCaptureCursorPushed = false
        } else {
            NSCursor.arrow.set()
        }
    }
    
    func capture(rect: CGRect) {
        print("WindowManager: Capturing rect: \(rect)")
        guard rect.width >= 2, rect.height >= 2 else {
            hideCaptureOverlay()
            return
        }
        hideCaptureOverlay()
        
        // Brief delay to allow overlay to disappear completely
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let image = ScreenCaptureService.shared.capture(rect: rect.integral) else {
                print("WindowManager: Failed to capture image")
                return
            }
            
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

    private func showScreenRecordingPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Allow screen recording in System Settings > Privacy & Security > Screen Recording, then relaunch Capture Lingo."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
