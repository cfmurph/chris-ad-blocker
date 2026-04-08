import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ContentBlockerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chris Ad Blocker")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Filter source URL")
                    .font(.headline)
                TextField("https://example.com/list.txt", text: $viewModel.sourceURLString)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
            }

            HStack(spacing: 12) {
                Button("Use bundled sample rules") {
                    Task {
                        await viewModel.useBundledRules()
                    }
                }

                Button("Fetch, compile, and reload") {
                    Task {
                        await viewModel.refreshRules()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.headline)
                Text(viewModel.statusText)
                    .textSelection(.enabled)
                    .font(.callout.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 420)
    }
}
