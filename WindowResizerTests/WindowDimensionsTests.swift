import AppKit
import ApplicationServices
import XCTest
@testable import WindowResizer

final class WindowDimensionsTests: XCTestCase {
    func testCreatesDimensionsFromWholeNumbers() throws {
        let dimensions = try WindowDimensions(widthText: "1280", heightText: " 720 ")

        XCTAssertEqual(dimensions.width, 1280)
        XCTAssertEqual(dimensions.height, 720)
        XCTAssertEqual(dimensions.size, CGSize(width: 1280, height: 720))
    }

    func testRejectsFractionalDimension() {
        XCTAssertThrowsError(try WindowDimensions(widthText: "800.5", heightText: "600")) { error in
            XCTAssertEqual(error as? DimensionError, .notAWholeNumber("Width"))
        }
    }

    func testRejectsDimensionOutsideAllowedRange() {
        XCTAssertThrowsError(try WindowDimensions(widthText: "0", heightText: "600")) { error in
            XCTAssertEqual(
                error as? DimensionError,
                .outOfRange("Width", WindowDimensions.allowedRange)
            )
        }
    }
}

@MainActor
final class WindowResizerViewModelTests: XCTestCase {
    func testDetectsAccessGrantedWhilePermissionScreenIsOpen() {
        let windowManager = WindowManagerStub()
        let viewModel = WindowResizerViewModel(
            windowManager: windowManager,
            applicationPath: "/Applications/Window Resizer.app"
        )
        viewModel.start()

        XCTAssertFalse(viewModel.isAccessibilityTrusted)

        windowManager.isAccessibilityTrusted = true
        viewModel.checkAccessibilityAccess()

        XCTAssertTrue(viewModel.isAccessibilityTrusted)
        XCTAssertEqual(windowManager.availableWindowsCallCount, 1)
    }

    func testExplainsHowToRecoverFromStaleAccessEntry() {
        let windowManager = WindowManagerStub()
        let viewModel = WindowResizerViewModel(windowManager: windowManager)

        viewModel.checkAccessibilityAccess(showFailureMessage: true)

        guard case .warning(let message) = viewModel.notice else {
            return XCTFail("Expected a warning")
        }
        XCTAssertTrue(message.contains("Remove the old WindowResizer row"))
    }

    func testRefreshesWindowsWhenApplicationReturnsToForeground() {
        let windowManager = WindowManagerStub()
        windowManager.isAccessibilityTrusted = true
        let viewModel = WindowResizerViewModel(windowManager: windowManager)
        viewModel.start()

        viewModel.applicationDidBecomeActive()

        XCTAssertEqual(windowManager.availableWindowsCallCount, 2)
    }

    func testBringToFrontSelectsAndDelegatesTheWindow() {
        let windowManager = WindowManagerStub()
        windowManager.isAccessibilityTrusted = true
        let dimensionOverlay = DimensionOverlayStub()
        let viewModel = WindowResizerViewModel(
            windowManager: windowManager,
            dimensionOverlay: dimensionOverlay
        )
        let window = TargetWindow(
            id: "42:0:Editor",
            applicationName: "Editor",
            title: "Document",
            processIdentifier: 42,
            icon: NSImage(),
            isMinimized: false,
            currentSize: CGSize(width: 800, height: 600),
            accessibilityElement: AXUIElementCreateSystemWide()
        )

        viewModel.bringToFront(window)

        XCTAssertEqual(viewModel.selectedWindowID, window.id)
        XCTAssertEqual(windowManager.broughtToFrontWindowID, window.id)
        XCTAssertEqual(dimensionOverlay.shownGeometry, windowManager.windowGeometry)
    }
}

@MainActor
private final class WindowManagerStub: WindowManaging {
    var isAccessibilityTrusted = false
    var availableWindowsCallCount = 0
    var broughtToFrontWindowID: String?
    var windowGeometry = WindowGeometry(
        position: CGPoint(x: 100, y: 100),
        size: CGSize(width: 800, height: 600)
    )

    func requestAccessibilityAccess() -> Bool {
        isAccessibilityTrusted
    }

    func availableWindows() throws -> [TargetWindow] {
        availableWindowsCallCount += 1
        return []
    }

    func bringToFront(_ window: TargetWindow) throws {
        broughtToFrontWindowID = window.id
    }

    func geometry(of window: TargetWindow) throws -> WindowGeometry {
        windowGeometry
    }

    func resize(_ window: TargetWindow, to requestedSize: CGSize) throws -> CGSize {
        requestedSize
    }
}

@MainActor
private final class DimensionOverlayStub: DimensionOverlayPresenting {
    var shownGeometry: WindowGeometry?

    func show(geometry: WindowGeometry, targetSize: CGSize?) {
        shownGeometry = geometry
    }

    func hide() {
        shownGeometry = nil
    }
}
