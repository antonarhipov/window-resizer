import SwiftUI

@main
struct WindowResizerApp: App {
    @StateObject private var viewModel = WindowResizerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 620, minHeight: 500)
                .onAppear {
                    viewModel.start()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    viewModel.applicationDidBecomeActive()
                }
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    if !viewModel.isAccessibilityTrusted {
                        viewModel.checkAccessibilityAccess()
                    }
                }
                .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                    if viewModel.isAccessibilityTrusted {
                        viewModel.pollSelectedWindowGeometry()
                    }
                }
        }
        .defaultSize(width: 700, height: 560)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh Windows") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
