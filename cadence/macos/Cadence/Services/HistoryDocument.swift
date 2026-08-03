import SwiftUI
import UniformTypeIdentifiers

/// Export wrapper so the session log can leave the app as a plain JSON file.
///
/// This is the mechanical half of the "no account, your data is yours"
/// promise — there is no sync service to fall back on, so export has to be
/// genuinely easy.
struct HistoryDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var sessions: [FocusSession]

    init(sessions: [FocusSession]) {
        self.sessions = sessions
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sessions = try decoder.decode(HistoryFileStore.Envelope.self, from: data).sessions
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(HistoryFileStore.Envelope(sessions: sessions))
        return FileWrapper(regularFileWithContents: data)
    }
}
