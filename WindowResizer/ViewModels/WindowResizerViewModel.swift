import Foundation

@MainActor
final class WindowResizerViewModel: ObservableObject {
    enum Notice: Equatable {
        case info(String)
        case success(String)
        case warning(String)
        case error(String)
    }

    @Published var windows: [TargetWindow] = []
    @Published var selectedWindowID: String?
    @Published var widthText = "1280"
    @Published var heightText = "720"
    @Published var isAccessibilityTrusted = false
    @Published var isLoading = false
    @Published var notice: Notice?

    let applicationPath: String

    private let windowManager: WindowManaging
    private let dimensionOverlay: DimensionOverlayPresenting
    private var hasStarted = false
    private var lastObservedGeometry: WindowGeometry?

    init(
        windowManager: WindowManaging? = nil,
        dimensionOverlay: DimensionOverlayPresenting? = nil,
        applicationPath: String = Bundle.main.bundleURL.path
    ) {
        self.windowManager = windowManager ?? AccessibilityWindowService()
        self.dimensionOverlay = dimensionOverlay ?? DimensionOverlayController()
        self.applicationPath = applicationPath
    }

    var selectedWindow: TargetWindow? {
        guard let selectedWindowID else { return nil }
        return windows.first { $0.id == selectedWindowID }
    }

    var canResize: Bool {
        isAccessibilityTrusted && selectedWindow != nil && !isLoading
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        isAccessibilityTrusted = windowManager.isAccessibilityTrusted

        if isAccessibilityTrusted {
            refresh()
        }
    }

    func requestAccessibilityAccess() {
        isAccessibilityTrusted = windowManager.requestAccessibilityAccess()
        if isAccessibilityTrusted {
            refresh()
        } else {
            notice = .info("Enable the exact copy shown above, then return here or check access again.")
        }
    }

    func applicationDidBecomeActive() {
        let wasAlreadyTrusted = isAccessibilityTrusted
        checkAccessibilityAccess()
        if wasAlreadyTrusted && isAccessibilityTrusted {
            refresh()
        }
    }

    func checkAccessibilityAccess(showFailureMessage: Bool = false) {
        let currentlyTrusted = windowManager.isAccessibilityTrusted
        let permissionWasJustGranted = currentlyTrusted && !isAccessibilityTrusted
        isAccessibilityTrusted = currentlyTrusted

        if permissionWasJustGranted {
            refresh()
        } else if showFailureMessage && !currentlyTrusted {
            notice = .warning(
                "macOS still reports no access for this copy. Remove the old WindowResizer row, " +
                    "add this app again with the + button, then relaunch it."
            )
        }
    }

    func refresh() {
        isAccessibilityTrusted = windowManager.isAccessibilityTrusted
        guard isAccessibilityTrusted else {
            windows = []
            selectedWindowID = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        let previousSelection = selectedWindowID
        do {
            windows = try windowManager.availableWindows()
            notice = nil
            if let previousSelection, windows.contains(where: { $0.id == previousSelection }) {
                selectedWindowID = previousSelection
            } else {
                selectedWindowID = nil
            }

            if windows.isEmpty {
                notice = .info("No resizable application windows are currently available.")
            }
        } catch {
            windows = []
            selectedWindowID = nil
            notice = .error(error.localizedDescription)
        }
    }

    func resizeSelectedWindow() {
        guard let selectedWindow else {
            notice = .error("Select an application window first.")
            return
        }

        do {
            let dimensions = try WindowDimensions(widthText: widthText, heightText: heightText)
            let actualSize = try windowManager.resize(selectedWindow, to: dimensions.size)

            if let index = windows.firstIndex(where: { $0.id == selectedWindow.id }) {
                windows[index].currentSize = actualSize
            }

            let actualWidth = Int(actualSize.width.rounded())
            let actualHeight = Int(actualSize.height.rounded())
            if abs(actualSize.width - dimensions.size.width) <= 1,
               abs(actualSize.height - dimensions.size.height) <= 1 {
                notice = .success("Resized \(selectedWindow.applicationName) to \(actualWidth) × \(actualHeight) points.")
            } else {
                notice = .warning(
                    "Requested \(dimensions.width) × \(dimensions.height); " +
                        "\(selectedWindow.applicationName) used \(actualWidth) × \(actualHeight) points."
                )
            }
        } catch {
            notice = .error(error.localizedDescription)
        }
    }

    func bringToFront(_ window: TargetWindow) {
        selectedWindowID = window.id
        do {
            try windowManager.bringToFront(window)
            showDimensionHint(for: window)
        } catch {
            notice = .error(error.localizedDescription)
        }
    }

    func selectedWindowDidChange() {
        guard let selectedWindow else {
            lastObservedGeometry = nil
            dimensionOverlay.hide()
            return
        }

        bringToFront(selectedWindow)
    }

    func pollSelectedWindowGeometry() {
        guard let selectedWindow else { return }

        do {
            let geometry = try windowManager.geometry(of: selectedWindow)
            let sizeChanged = lastObservedGeometry.map {
                abs($0.size.width - geometry.size.width) > 0.5 ||
                    abs($0.size.height - geometry.size.height) > 0.5
            } ?? false
            lastObservedGeometry = geometry

            guard sizeChanged else { return }
            if let index = windows.firstIndex(where: { $0.id == selectedWindow.id }) {
                windows[index].currentSize = geometry.size
            }
            dimensionOverlay.show(geometry: geometry, targetSize: configuredTargetSize)
        } catch {
            // Windows can disappear between refreshes; the next refresh reconciles the list.
        }
    }

    private func showDimensionHint(for window: TargetWindow) {
        do {
            let geometry = try windowManager.geometry(of: window)
            lastObservedGeometry = geometry
            dimensionOverlay.show(geometry: geometry, targetSize: configuredTargetSize)
        } catch {
            notice = .error(error.localizedDescription)
        }
    }

    private var configuredTargetSize: CGSize? {
        try? WindowDimensions(widthText: widthText, heightText: heightText).size
    }
}
