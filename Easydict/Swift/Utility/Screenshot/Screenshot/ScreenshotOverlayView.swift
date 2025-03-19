//
//  ScreenshotOverlayView.swift
//  Easydict
//
//  Created by tisfeng on 2025/3/11.
//  Copyright © 2025 izual. All rights reserved.
//

import SwiftUI

// MARK: - ScreenshotOverlayView

struct ScreenshotOverlayView: View {
    // MARK: Lifecycle

    init(
        state: ScreenshotState,
        onImageCaptured: @escaping (NSImage?) -> ()
    ) {
        self.state = state
        self.onImageCaptured = onImageCaptured

        self._backgroundImage = State(initialValue: takeScreenshot(screen: state.screen))

        // Load last screenshot area from UserDefaults
        let lastRect = Screenshot.shared.lastScreenshotRect
        self._savedRect = State(initialValue: lastRect)
        self._showTip = State(initialValue: !lastRect.isEmpty)
    }

    // MARK: Internal

    @ObservedObject var state: ScreenshotState

    var body: some View {
        ZStack {
            backgroundLayer
            selectionLayer

            // Show last screenshot area tip if available
            if showTip {
                tipLayer
            }
        }
        .ignoresSafeArea()
        .onChange(of: state.isShowingPreview) { showing in
            if showing {
                NSLog("Showing preview, take screenshot")
                // Show preview 1.0s, then take screenshot
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    handleDragEnd()
                }
            }
        }
    }

    // MARK: Private

    @State private var backgroundImage: NSImage?
    @State private var savedRect: CGRect
    @State private var showTip: Bool

    private let onImageCaptured: (NSImage?) -> ()

    // MARK: Gestures

    /// Drag gesture for selection
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged(handleDragChange)
            .onEnded(handleDragEnd)
    }

    // MARK: View Components

    /// Background screenshot with dark overlay
    private var backgroundLayer: some View {
        Group {
            if let image = backgroundImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()

                Rectangle()
                    .fill(Color.black.opacity(state.shouldHideDarkOverlay ? 0 : 0.4))
                    .ignoresSafeArea()
                    .animation(.easeInOut, value: state.shouldHideDarkOverlay)
            }
        }
    }

    /// Selection area and drag gesture handling
    private var selectionLayer: some View {
        GeometryReader { geometry in
            ZStack {
                if !state.selectedRect.isEmpty {
                    selectionRectangleView
                }
            }
            .compositingGroup()
            .onChange(of: state.selectedRect) { rect in
                if rect.isEmpty {
                    NSLog("Selection rect is empty")
                }
            }

            // Gesture recognition layer
            Rectangle()
                .fill(Color.clear)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(drag)
        }
    }

    /// Visual representation of the selection area
    private var selectionRectangleView: some View {
        Group {
            // Selection border with semi-transparent dark background
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .background(Color.black.opacity(0.1)) // Add a darker overlay for selection area
                .frame(width: state.selectedRect.width, height: state.selectedRect.height)
                .position(
                    x: state.selectedRect.midX,
                    y: state.selectedRect.midY
                )
        }
    }

    /// Tip layer at bottom-left corner
    private var tipLayer: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("screenshot.tip.click_d_to_capture_last_area")
                        .foregroundStyle(.white)

                    Divider()

                    Text("screenshot.tip.escape_to_cancel_capture")
                        .foregroundStyle(.white)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                        }
                }

                Spacer()
            }
        }
    }

    // MARK: Event Handlers

    /// Handle drag gesture change
    private func handleDragChange(_ value: DragGesture.Value) {
        let adjustedStartLocation = CGPoint(
            x: value.startLocation.x,
            y: value.startLocation.y
        )
        let adjustedLocation = CGPoint(
            x: value.location.x,
            y: value.location.y
        )

        // Calculate selection rectangle
        let origin = CGPoint(
            x: min(adjustedStartLocation.x, adjustedLocation.x),
            y: min(adjustedStartLocation.y, adjustedLocation.y)
        )
        let size = CGSize(
            width: abs(adjustedLocation.x - adjustedStartLocation.x),
            height: abs(adjustedLocation.y - adjustedStartLocation.y)
        )

        state.selectedRect = CGRect(origin: origin, size: size).integral
    }

    /// Handle drag gesture end
    private func handleDragEnd(_ value: DragGesture.Value? = nil) {
        let selectedRect = state.selectedRect
        NSLog("Drag ended, selected rect: \(selectedRect)")

        // Check if selection meets minimum size requirements
        if selectedRect.width > 10, selectedRect.height > 10 {
            asyncTakeScreenshot(
                screen: state.screen,
                rect: selectedRect,
                completion: onImageCaptured
            )
        } else {
            NSLog("Screenshot cancelled - Selection too small (minimum: 10x10)")
            onImageCaptured(nil)
        }
    }

    /// Take screenshot of the screen area asynchronously, and save last screenshot rect.
    private func asyncTakeScreenshot(
        screen: NSScreen,
        rect: CGRect,
        completion: @escaping (NSImage?) -> ()
    ) {
        NSLog("Async take screenshot, screen frame: \(screen.frame), rect: \(rect)")

        // Hide selection rectangle, avoid capturing it
        state.reset()

        // Save last screenshot rect
        Screenshot.shared.lastScreenshotRect = rect
        Screenshot.shared.lastScreen = screen

        // Async to wait for UI update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSLog("Async take screenshot completion")
            let image = takeScreenshot(screen: screen, rect: rect)
            completion(image)
        }
    }
}
