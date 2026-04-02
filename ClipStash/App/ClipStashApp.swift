import SwiftUI

@main
struct ClipStashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a Settings scene as a placeholder since our UI
        // is entirely driven by the floating panel and menu bar.
        // The Settings window won't appear unless the user explicitly opens it.
        Settings {
            EmptyView()
        }
    }
}
