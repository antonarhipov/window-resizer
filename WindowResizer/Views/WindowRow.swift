import SwiftUI

struct WindowRow: View {
    let window: TargetWindow

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: window.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.applicationName)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(window.displayTitle)
                        .lineLimit(1)
                    if window.isMinimized {
                        Text("Minimized")
                            .font(.caption)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(window.currentSize.width.rounded())) × \(Int(window.currentSize.height.rounded()))")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(window.applicationName), \(window.displayTitle), " +
                "\(Int(window.currentSize.width.rounded())) by \(Int(window.currentSize.height.rounded())) points"
        )
    }
}
