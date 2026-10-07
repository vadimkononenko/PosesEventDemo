import CoreTransferable
import UniformTypeIdentifiers

/// Wraps a detection result for `ShareLink`: the result is shared as a `.json` file.
nonisolated struct PoseExport: Transferable {
    let result: PoseDetectionResult

    var fileName: String {
        "pose-\(result.engine.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")).json"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(export.result)

            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let url = directory.appendingPathComponent(export.fileName)
            try data.write(to: url)
            return SentTransferredFile(url)
        }
    }
}
