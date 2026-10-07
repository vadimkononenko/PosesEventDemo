import SwiftUI

struct EngineSwitcher: View {
    @Binding var engine: PoseEngine

    var body: some View {
        Picker("Engine", selection: $engine) {
            ForEach(PoseEngine.allCases) { engine in
                Text(engine.rawValue).tag(engine)
            }
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    @Previewable @State var engine: PoseEngine = .vision
    EngineSwitcher(engine: $engine)
        .padding()
}
