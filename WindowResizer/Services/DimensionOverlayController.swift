import AppKit
import SwiftUI

@MainActor
protocol DimensionOverlayPresenting {
    func show(geometry: WindowGeometry, targetSize: CGSize?)
    func hide()
}

@MainActor
final class DimensionOverlayController: DimensionOverlayPresenting {
    private let panelSize = CGSize(width: 250, height: 92)
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func show(geometry: WindowGeometry, targetSize: CGSize?) {
        let panel = panel ?? makePanel()
        self.panel = panel

        let currentWidth = Int(geometry.size.width.rounded())
        let currentHeight = Int(geometry.size.height.rounded())
        let targetWidth = targetSize.map { Int($0.width.rounded()) }
        let targetHeight = targetSize.map { Int($0.height.rounded()) }
        let isAtTarget = targetSize.map {
            abs($0.width - geometry.size.width) <= 1 &&
                abs($0.height - geometry.size.height) <= 1
        } ?? false

        panel.contentView = NSHostingView(
            rootView: DimensionHUDView(
                width: currentWidth,
                height: currentHeight,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                isAtTarget: isAtTarget
            )
        )
        panel.setFrame(
            NSRect(origin: panelOrigin(for: geometry), size: panelSize),
            display: true
        )
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        scheduleHide()
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        return panel
    }

    private func panelOrigin(for geometry: WindowGeometry) -> CGPoint {
        let primaryScreenHeight = NSScreen.screens
            .first(where: { $0.frame.origin == .zero })?
            .frame.height ?? NSScreen.main?.frame.height ?? 0
        let targetCenter = CGPoint(
            x: geometry.position.x + geometry.size.width / 2,
            y: primaryScreenHeight - geometry.position.y - geometry.size.height / 2
        )
        let screen = NSScreen.screens.first(where: { $0.frame.contains(targetCenter) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(
            x: geometry.position.x,
            y: primaryScreenHeight - geometry.position.y - geometry.size.height,
            width: geometry.size.width,
            height: geometry.size.height
        )

        let desiredX = geometry.position.x + (geometry.size.width - panelSize.width) / 2
        let targetTop = primaryScreenHeight - geometry.position.y
        let desiredY = targetTop - panelSize.height - 18
        return CGPoint(
            x: min(max(desiredX, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8),
            y: min(max(desiredY, visibleFrame.minY + 8), visibleFrame.maxY - panelSize.height - 8)
        )
    }

    private func scheduleHide() {
        hideWorkItem?.cancel()
        let panel = panel
        let workItem = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel?.animator().alphaValue = 0
            } completionHandler: {
                panel?.orderOut(nil)
                panel?.alphaValue = 1
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: workItem)
    }
}

private struct DimensionHUDView: View {
    let width: Int
    let height: Int
    let targetWidth: Int?
    let targetHeight: Int?
    let isAtTarget: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text("\(width) × \(height)")
                .font(.system(size: 25, weight: .semibold, design: .monospaced))
                .contentTransition(.numericText())

            if let targetWidth, let targetHeight {
                HStack(spacing: 5) {
                    if isAtTarget {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Text("Target \(targetWidth) × \(targetHeight) pt")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            } else {
                Text("points")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(0.18))
        }
    }
}
