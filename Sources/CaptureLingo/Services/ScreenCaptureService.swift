import Cocoa
import ScreenCaptureKit
import CoreGraphics

class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    private var hasRequestedScreenCaptureAccessThisLaunch = false
    
    // For MacOS 14+ we should use ScreenCaptureKit, but for simplicity/older API combatibility (and because SCK is async and complex for a simple rect capture), 
    // we can use CGWindowListCreateImage for a static capture if permissions allow.
    // However, SCK is the modern way. Let's try CGWindowListCreateImage first as it's synchronous and easier for "region capture" after user selection.
    
    func capture(rect: CGRect, belowWindowID: CGWindowID? = nil) -> CGImage? {
        let hasPermission = ensureScreenRecordingPermission()
        if !hasPermission {
            print("ScreenCaptureService: Permission preflight is false. Capture aborted.")
            return nil
        }

        // `rect` is received in AppKit global screen coordinates (origin: bottom-left).
        // CGWindowListCreateImage expects Quartz screen coordinates (origin: top-left).
        let captureRect = convertAppKitRectToQuartzScreenRect(rect).integral
        let windowImageOption: CGWindowImageOption = .bestResolution

        let listOption: CGWindowListOption
        let targetWindowID: CGWindowID
        if let belowWindowID {
            listOption = .optionOnScreenBelowWindow
            targetWindowID = belowWindowID
        } else {
            listOption = .optionOnScreenOnly
            targetWindowID = kCGNullWindowID
        }

        print("ScreenCaptureService: capture rect appKit=\(rect) quartz=\(captureRect) option=\(listOption)")
        return CGWindowListCreateImage(captureRect, listOption, targetWindowID, windowImageOption)
    }

    private func convertAppKitRectToQuartzScreenRect(_ rect: CGRect) -> CGRect {
        let primaryHeight = primaryScreenHeight()
        guard primaryHeight > 0 else {
            return rect
        }
        return CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func primaryScreenHeight() -> CGFloat {
        if let menuBarScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero }) {
            return menuBarScreen.frame.height
        }
        return NSScreen.main?.frame.height ?? 0
    }

    func ensureScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            let preflightGranted = CGPreflightScreenCaptureAccess()
            print("ScreenCaptureService: CGPreflightScreenCaptureAccess=\(preflightGranted)")
            if preflightGranted {
                hasRequestedScreenCaptureAccessThisLaunch = false
                return true
            }

            if !hasRequestedScreenCaptureAccessThisLaunch {
                hasRequestedScreenCaptureAccessThisLaunch = true
                let requested = CGRequestScreenCaptureAccess()
                print("ScreenCaptureService: CGRequestScreenCaptureAccess=\(requested)")
                return requested
            }

            return false
        }
        return true
    }
}
