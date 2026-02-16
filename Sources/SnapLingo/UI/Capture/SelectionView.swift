import AppKit
import SwiftUI

struct SelectionView: View {
    weak var window: NSWindow?
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var selectionRect: CGRect = .zero
    private let selectionColor = Color(red: 0.0, green: 0.78, blue: 1.0)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Transparent interaction layer for drag selection.
                Color.clear
                    .edgesIgnoringSafeArea(.all)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle()) // Ensure tap/drag target
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                NSCursor.crosshair.set()
                                print("SelectionView: Drag changed: \(value.location)")
                                if startPoint == nil {
                                    startPoint = value.startLocation
                                }
                                currentPoint = value.location
                                updateSelectionRect()
                            }
                            .onEnded { value in
                                print("SelectionView: Drag ended")
                                currentPoint = value.location
                                updateSelectionRect()
                                print("Selection completed: \(selectionRect)")
                                WindowManager.shared.capture(rect: selectionRect)
                                window?.close()
                            }
                    )
                    .onAppear {
                         print("SelectionView: appeared")
                         NSCursor.crosshair.set()
                    }
                    .onDisappear {
                        NSCursor.arrow.set()
                    }
                    .onHover { isHovering in
                        if isHovering {
                            NSCursor.crosshair.set()
                        }
                    }
                
                // Selection Rectangle
                if let _ = startPoint, let _ = currentPoint {
                    Rectangle()
                        .fill(selectionColor.opacity(0.18))
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black.opacity(0.9), lineWidth: 4)
                        )
                        .overlay(
                            Rectangle()
                                .stroke(selectionColor, lineWidth: 2)
                        )
                        .position(x: selectionRect.midX, y: selectionRect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color.clear)
    }
    
    private func updateSelectionRect() {
        guard let start = startPoint, let end = currentPoint else { return }
        
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(start.x - end.x)
        let height = abs(start.y - end.y)
        
        selectionRect = CGRect(x: x, y: y, width: width, height: height)
    }
}
