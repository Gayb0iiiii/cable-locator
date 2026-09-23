import SwiftUI

@main
struct CableLocatorApp: App {
    @StateObject private var store = ProjectStore()

    var body: some Scene {
        WindowGroup {
            ProjectListView()
                .environmentObject(store)
        }
    }
}
