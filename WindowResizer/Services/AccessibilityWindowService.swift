import AppKit
import ApplicationServices

@MainActor
protocol WindowManaging {
    var isAccessibilityTrusted: Bool { get }
    @discardableResult func requestAccessibilityAccess() -> Bool
    func availableWindows() throws -> [TargetWindow]
    func bringToFront(_ window: TargetWindow) throws
    func geometry(of window: TargetWindow) throws -> WindowGeometry
    func resize(_ window: TargetWindow, to requestedSize: CGSize) throws -> CGSize
}

@MainActor
final class AccessibilityWindowService: WindowManaging {
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestAccessibilityAccess() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    func availableWindows() throws -> [TargetWindow] {
        guard isAccessibilityTrusted else {
            throw WindowOperationError.permissionRequired
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let applications = NSWorkspace.shared.runningApplications
            .filter {
                !$0.isTerminated &&
                    $0.processIdentifier != currentPID &&
                    $0.activationPolicy == .regular &&
                    $0.localizedName != nil
            }
            .sorted {
                ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending
            }

        var result: [TargetWindow] = []

        for application in applications {
            let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
            guard let elements: [AXUIElement] = value(of: kAXWindowsAttribute, from: applicationElement) else {
                continue
            }

            for (index, element) in elements.enumerated() {
                guard let size = size(of: element), size.width > 0, size.height > 0 else {
                    continue
                }

                let role: String? = value(of: kAXRoleAttribute, from: element)
                guard role == (kAXWindowRole as String) else {
                    continue
                }

                let title: String = value(of: kAXTitleAttribute, from: element) ?? ""
                let minimized: Bool = value(of: kAXMinimizedAttribute, from: element) ?? false
                let appName = application.localizedName ?? "Unknown application"
                let icon = application.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()

                result.append(
                    TargetWindow(
                        id: "\(application.processIdentifier):\(index):\(title)",
                        applicationName: appName,
                        title: title,
                        processIdentifier: application.processIdentifier,
                        icon: icon,
                        isMinimized: minimized,
                        currentSize: size,
                        accessibilityElement: element
                    )
                )
            }
        }

        return result.sorted {
            let appComparison = $0.applicationName.localizedCaseInsensitiveCompare($1.applicationName)
            if appComparison == .orderedSame {
                return $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
            }
            return appComparison == .orderedAscending
        }
    }

    func bringToFront(_ window: TargetWindow) throws {
        guard isAccessibilityTrusted else {
            throw WindowOperationError.permissionRequired
        }

        if window.isMinimized {
            let restoreError = AXUIElementSetAttributeValue(
                window.accessibilityElement,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
            guard restoreError == .success else {
                throw WindowOperationError.accessibility(restoreError)
            }
        }

        let runningApplication = NSRunningApplication(processIdentifier: window.processIdentifier)
        let activated = runningApplication?.activate(options: []) ?? false
        let applicationElement = AXUIElementCreateApplication(window.processIdentifier)
        let frontmostError = AXUIElementSetAttributeValue(
            applicationElement,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )

        _ = AXUIElementSetAttributeValue(
            window.accessibilityElement,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )
        let raiseError = AXUIElementPerformAction(
            window.accessibilityElement,
            kAXRaiseAction as CFString
        )

        guard raiseError == .success else {
            throw WindowOperationError.accessibility(raiseError)
        }
        guard activated || frontmostError == .success else {
            throw WindowOperationError.unableToActivate
        }
    }

    func resize(_ window: TargetWindow, to requestedSize: CGSize) throws -> CGSize {
        guard isAccessibilityTrusted else {
            throw WindowOperationError.permissionRequired
        }

        var isSettable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(
            window.accessibilityElement,
            kAXSizeAttribute as CFString,
            &isSettable
        )

        guard settableError == .success else {
            throw WindowOperationError.accessibility(settableError)
        }
        guard isSettable.boolValue else {
            throw WindowOperationError.notResizable
        }

        var size = requestedSize
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw WindowOperationError.unableToCreateSize
        }

        let resizeError = AXUIElementSetAttributeValue(
            window.accessibilityElement,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        guard resizeError == .success else {
            throw WindowOperationError.accessibility(resizeError)
        }

        return self.size(of: window.accessibilityElement) ?? requestedSize
    }

    func geometry(of window: TargetWindow) throws -> WindowGeometry {
        guard isAccessibilityTrusted else {
            throw WindowOperationError.permissionRequired
        }
        guard let position = position(of: window.accessibilityElement),
              let size = size(of: window.accessibilityElement) else {
            throw WindowOperationError.unableToReadGeometry
        }

        return WindowGeometry(position: position, size: size)
    }

    private func value<T>(of attribute: String, from element: AXUIElement) -> T? {
        var copiedValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &copiedValue)
        guard error == .success else { return nil }
        return copiedValue as? T
    }

    private func size(of element: AXUIElement) -> CGSize? {
        guard let value: AXValue = value(of: kAXSizeAttribute, from: element),
              AXValueGetType(value) == .cgSize else {
            return nil
        }

        var result = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &result) else { return nil }
        return result
    }

    private func position(of element: AXUIElement) -> CGPoint? {
        guard let value: AXValue = value(of: kAXPositionAttribute, from: element),
              AXValueGetType(value) == .cgPoint else {
            return nil
        }

        var result = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &result) else { return nil }
        return result
    }
}

enum WindowOperationError: LocalizedError {
    case permissionRequired
    case notResizable
    case unableToActivate
    case unableToCreateSize
    case unableToReadGeometry
    case accessibility(AXError)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Accessibility access is required to read and resize application windows."
        case .notResizable:
            return "This window does not allow its size to be changed."
        case .unableToActivate:
            return "The application could not be brought to the front."
        case .unableToCreateSize:
            return "The requested window size could not be created."
        case .unableToReadGeometry:
            return "The application did not provide the window position and size."
        case .accessibility(let error):
            switch error {
            case .apiDisabled:
                return "Accessibility access is disabled for Window Resizer."
            case .attributeUnsupported:
                return "This application does not expose a resizable window."
            case .cannotComplete:
                return "The application did not respond to the resize request."
            case .invalidUIElement, .invalidUIElementObserver:
                return "That window is no longer available. Refresh the window list and try again."
            case .noValue:
                return "The application did not provide a window size."
            default:
                return "macOS could not resize the window (Accessibility error \(error.rawValue))."
            }
        }
    }
}
