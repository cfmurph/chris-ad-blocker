import SwiftUI

@main
struct AdBlockerHostApp: App {
    @StateObject private var viewModel = ContentBlockerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
