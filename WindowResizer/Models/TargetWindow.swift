import AppKit
import ApplicationServices

struct TargetWindow: Identifiable {
    let id: String
    let applicationName: String
    let title: String
    let processIdentifier: pid_t
    let icon: NSImage
    let isMinimized: Bool
    var currentSize: CGSize
    let accessibilityElement: AXUIElement

    var displayTitle: String {
        title.isEmpty ? "Untitled window" : title
    }
}

struct WindowGeometry: Equatable {
    let position: CGPoint
    let size: CGSize
}

struct WindowDimensions {
    static let allowedRange = 1...16_384

    let width: Int
    let height: Int

    init(widthText: String, heightText: String) throws {
        width = try Self.parse(widthText, label: "Width")
        height = try Self.parse(heightText, label: "Height")
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    private static func parse(_ text: String, label: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Int(trimmed) else {
            throw DimensionError.notAWholeNumber(label)
        }

        guard allowedRange.contains(value) else {
            throw DimensionError.outOfRange(label, allowedRange)
        }

        return value
    }
}

enum DimensionError: LocalizedError, Equatable {
    case notAWholeNumber(String)
    case outOfRange(String, ClosedRange<Int>)

    var errorDescription: String? {
        switch self {
        case .notAWholeNumber(let label):
            return "\(label) must be a whole number."
        case .outOfRange(let label, let range):
            return "\(label) must be between \(range.lowerBound) and \(range.upperBound) points."
        }
    }
}
