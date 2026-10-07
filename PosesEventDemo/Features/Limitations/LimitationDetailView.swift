import SwiftUI

/// Runs both engines on one prepared photo. Reuses the Compare screen.
struct LimitationDetailView: View {
    let testCase: LimitationCase

    @State private var viewModel = CompareViewModel()

    var body: some View {
        VStack(spacing: 12) {
            hint

            if let url = testCase.url {
                CompareView(viewModel: viewModel)
                    .task {
                        guard viewModel.image == nil else { return }
                        // Reading the file off the main thread keeps the push animation smooth.
                        let image = await Task.detached(priority: .userInitiated) {
                            UIImage(contentsOfFile: url.path)
                        }.value
                        if let image { viewModel.setImage(image) }
                    }
            } else {
                ContentUnavailableView("File not found",
                                       systemImage: "questionmark.folder",
                                       description: Text("Add \(testCase.fileName) to Resources/TestCases and check that it belongs to the app target."))
                    .frame(maxHeight: .infinity)
            }
        }
        .padding()
        .navigationTitle(testCase.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if testCase.url != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.rerun()
                    } label: {
                        Label("Run again", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.image == nil || viewModel.isDetecting)
                }
            }
        }
    }

    private var hint: some View {
        Label(testCase.lookAt, systemImage: "eye")
            .font(.footnote.weight(.medium))
            .card()
    }
}
