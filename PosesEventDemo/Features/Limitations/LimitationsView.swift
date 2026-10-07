import SwiftUI

struct LimitationsView: View {
    var body: some View {
        List {
            ForEach(LimitationCase.images) { row(for: $0) }
        }
        .navigationDestination(for: LimitationCase.self) { testCase in
            LimitationDetailView(testCase: testCase)
        }
    }

    private func row(for testCase: LimitationCase) -> some View {
        NavigationLink(value: testCase) {
            HStack(spacing: 12) {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(testCase.title)
                    Text(testCase.problem)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if testCase.url == nil {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("File is missing")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LimitationsView()
            .navigationTitle("Limitations")
    }
}
