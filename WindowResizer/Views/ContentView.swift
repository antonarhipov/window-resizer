import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: WindowResizerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if viewModel.isAccessibilityTrusted {
                dimensionControls
                windowPicker
                footer
            } else {
                permissionView
            }
        }
        .padding(24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Window Resizer")
                .font(.title.bold())
            Text("Set a size, choose an application window, and resize it.")
                .foregroundStyle(.secondary)
        }
    }

    private var permissionView: some View {
        ContentUnavailableView {
            Label("Accessibility Access Needed", systemImage: "lock.shield")
        } description: {
            VStack(spacing: 8) {
                Text("macOS requires your permission before Window Resizer can see or change other application windows.")
                Text("Running copy: \(viewModel.applicationPath)")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        } actions: {
            VStack(spacing: 10) {
                HStack {
                    Button("Open Accessibility Settings") {
                        viewModel.requestAccessibilityAccess()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Check Access Again") {
                        viewModel.checkAccessibilityAccess(showFailureMessage: true)
                    }
                }

                if let notice = viewModel.notice {
                    let presentation = presentation(for: notice)
                    Label(presentation.message, systemImage: presentation.symbol)
                        .font(.caption)
                        .foregroundStyle(presentation.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dimensionControls: some View {
        GroupBox("Target size") {
            HStack(spacing: 12) {
                dimensionField("Width", text: $viewModel.widthText)
                Image(systemName: "multiply")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                dimensionField("Height", text: $viewModel.heightText)
                Text("points")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func dimensionField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            .accessibilityLabel(title)
    }

    private var windowPicker: some View {
        GroupBox {
            VStack(spacing: 0) {
                HStack {
                    Text("Application windows")
                        .font(.headline)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button {
                        viewModel.refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

                if viewModel.windows.isEmpty {
                    ContentUnavailableView(
                        "No Windows Found",
                        systemImage: "macwindow",
                        description: Text("Open an application window, then refresh the list.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 190)
                } else {
                    List(viewModel.windows, selection: $viewModel.selectedWindowID) { window in
                        WindowRow(window: window)
                            .tag(window.id)
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 190)
                    .accessibilityLabel("Application windows")
                    .onChange(of: viewModel.selectedWindowID) {
                        viewModel.selectedWindowDidChange()
                    }
                }

                Text("Select a window to bring it forward. Resize it manually to see live dimensions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
            }
            .padding(.top, 4)
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 12) {
            noticeView
            Spacer(minLength: 12)
            Button("Resize Window") {
                viewModel.resizeSelectedWindow()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canResize)
        }
        .frame(minHeight: 34)
    }

    @ViewBuilder
    private var noticeView: some View {
        if let notice = viewModel.notice {
            let presentation = presentation(for: notice)
            Label(presentation.message, systemImage: presentation.symbol)
                .font(.callout)
                .foregroundStyle(presentation.color)
                .lineLimit(2)
                .accessibilityLabel(presentation.message)
        } else if let window = viewModel.selectedWindow {
            Text("Selected: \(window.applicationName) — \(window.displayTitle)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func presentation(for notice: WindowResizerViewModel.Notice) -> (message: String, symbol: String, color: Color) {
        switch notice {
        case .info(let message):
            return (message, "info.circle", .secondary)
        case .success(let message):
            return (message, "checkmark.circle.fill", .green)
        case .warning(let message):
            return (message, "exclamationmark.triangle.fill", .orange)
        case .error(let message):
            return (message, "xmark.octagon.fill", .red)
        }
    }
}
