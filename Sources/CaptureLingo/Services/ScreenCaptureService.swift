import Cocoa
import ScreenCaptureKit
import CoreGraphics

class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    
    // For MacOS 14+ we should use ScreenCaptureKit, but for simplicity/older API combatibility (and because SCK is async and complex for a simple rect capture), 
    // we can use CGWindowListCreateImage for a static capture if permissions allow.
    // However, SCK is the modern way. Let's try CGWindowListCreateImage first as it's synchronous and easier for "region capture" after user selection.
    
    func capture(rect: CGRect) -> CGImage? {
        guard ensureScreenRecordingPermission() else {
            return nil
        }

        // The rect is in the overlay window's coordinate system (SwiftUI/Cocoa).
        // Check if we need to flip coordinates or adjust for multiple screens.
        // CGWindowListCreateImage takes a CGRect in screen coordinates.
        
        // For now, assume main screen and standard coordinates.
        // We might need to handle per-screen logic if the app expands.
        
        let windowImageOption: CGWindowImageOption = .bestResolution
        
        // Capture everything *below* our overlay window (which should be the topmost interactive one).
        // But we just want the screen content. .optionOnScreenOnly might include our overlay if we are not careful,
        // but capturing "BelowWindow" relative to the overlay window ID is safer.
        // However, we don't have easy access to the OverlayWindow ID here unless passed.
        
        // Simpler approach: Hide overlay, capture, show overlay (if needed, but we close overlay on capture)
        // Since we close the overlay locally before calling this probably, we can just capture screen.
        
        return CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, windowImageOption)
    }

    func ensureScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            if CGPreflightScreenCaptureAccess() {
                return true
            }
            return CGRequestScreenCaptureAccess()
        }
        return true
    }
}
