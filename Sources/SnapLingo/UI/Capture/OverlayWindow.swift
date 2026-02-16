import Cocoa
import SwiftUI

class OverlayWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        print("OverlayWindow: init with rect: \(contentRect)")
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.isMovable = false
        self.level = .mainMenu + 1
        
        let hostingView = CrosshairHostingView(rootView: SelectionView(window: self))
        hostingView.frame = NSRect(origin: .zero, size: contentRect.size)
        hostingView.autoresizingMask = [.width, .height]
        self.contentView = hostingView
    }
}
