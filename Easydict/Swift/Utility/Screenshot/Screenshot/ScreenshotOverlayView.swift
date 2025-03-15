//
//  ScreenshotOverlayView.swift
//  Easydict
//
//  Created by tisfeng on 2025/3/11.
//  Copyright © 2025 izual. All rights reserved.
//

import Carbon
import ScreenCaptureKit
import SwiftUI

// MARK: - ScreenshotOverlayView

struct ScreenshotOverlayView: View {
    // MARK: Lifecycle

    init(screenFrame: CGRect, onImageCaptured: @escaping (NSImage?) -> ()) {
        self.onImageCaptured = onImageCaptured
        self.screenFrame = screenFrame

        let screenBounds = getBounds(of: screenFrame)
        self._backgroundImage = State(initialValue: takeScreenshot(of: screenBounds))
    }

    // MARK: Internal

    var body: some View {
        ZStack {
            // Display background screenshot
            if let image = backgroundImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
                    .border(.red)

                // Dark mask when selecting, turn to transparent when mouse moving.
                Rectangle()
                    .fill(Color.black.opacity(isMouseMoved ? 0 : 0.4))
                    .ignoresSafeArea()
                    .animation(.easeOut, value: isMouseMoved)
                    .onAppear {
                        NSLog("onAppear mask, isMouseMoved: \(isMouseMoved)")
                    }
            }

            GeometryReader { geometry in
                ZStack {
                    if isSelecting {
                        // Selection area with light gray background
                        Rectangle()
                            .stroke(Color.white, lineWidth: 2)
                            .background(Color.black.opacity(0.1))
                            .frame(width: selectedRect.width, height: selectedRect.height)
                            .position(
                                x: selectedRect.midX,
                                y: selectedRect.midY
                            )

                        // Clear mask for selection area
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: selectedRect.width, height: selectedRect.height)
                            .position(
                                x: selectedRect.midX,
                                y: selectedRect.midY
                            )
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                // Gesture recognition layer
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .gesture(drag)
            }
        }
        .ignoresSafeArea()
        .border(.orange)
        .onAppear {
            setupKeyboardMonitor()
            setupMouseMonitor()
            isMouseMoved = false
        }
        .onDisappear {
            removeKeyboardMonitor()
            removeMouseMonitor()
        }
    }

    // MARK: Private

    @State private var selectedRect = CGRect.zero
    @State private var isSelecting = false
    @State private var backgroundImage: NSImage?
    @State private var isMouseMoved = false
    @State private var mouseMonitor: Any?
    // Modified to array to store multiple monitors
    @State private var keyboardMonitors: [Any] = []
    @State private var keyboardMonitor: Any?

    /// Screen frame is `bottom-left` origin.
    private let screenFrame: CGRect
    private let onImageCaptured: (NSImage?) -> ()

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                // value is `top-left` coordinate location in current screen

                let adjustedStartLocation = CGPoint(
                    x: value.startLocation.x,
                    y: value.startLocation.y
                )
                let adjustedLocation = CGPoint(
                    x: value.location.x,
                    y: value.location.y
                )

                let origin = CGPoint(
                    x: min(adjustedStartLocation.x, adjustedLocation.x),
                    y: min(adjustedStartLocation.y, adjustedLocation.y)
                )
                let size = CGSize(
                    width: abs(adjustedLocation.x - adjustedStartLocation.x),
                    height: abs(adjustedLocation.y - adjustedStartLocation.y)
                )
                selectedRect = CGRect(origin: origin, size: size)
                isSelecting = true
                isMouseMoved = true
            }
            .onEnded { _ in
                isSelecting = false
                NSLog("Selected rect: \(selectedRect)")

                if selectedRect.width > 10, selectedRect.height > 10 {
                    onImageCaptured(takeScreenshot(of: selectedRect))
                } else {
                    NSLog("Selected rect is too small, ignore")
                    onImageCaptured(nil)
                }
            }
    }

    private func setupMouseMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { _ in
            if !isMouseMoved {
                DispatchQueue.main.async {
                    isMouseMoved = true
                    NSLog("Mouse moved, isMouseMoved: \(isMouseMoved)")
                }
            }
        }
    }

    private func removeMouseMonitor() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }

    private func setupKeyboardMonitor() {
        removeKeyboardMonitor()

        // Use global monitor instead of local monitor
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            NSLog("Global key: \(event.keyCode)")

            if event.keyCode == kVK_Escape {
                NSLog("ESC key detected, close window")
                DispatchQueue.main.async {
                    onImageCaptured(nil)
                }
            }
        }

        // Also add local monitor as backup
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            NSLog("Local key: \(event.keyCode)")

            if event.keyCode == kVK_Escape {
                NSLog("ESC key detected, close window")
                DispatchQueue.main.async {
                    onImageCaptured(nil)
                }
                return nil
            }
            return event
        }

        // Save both monitors
        keyboardMonitors = [keyboardMonitor, localMonitor].compactMap { $0 }
    }

    // Method to remove monitors
    private func removeKeyboardMonitor() {
        for monitor in keyboardMonitors {
            NSEvent.removeMonitor(monitor)
        }
        keyboardMonitors = []
        NSLog("Remove all keyboard monitors")
    }
}
