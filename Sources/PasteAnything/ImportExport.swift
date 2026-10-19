import AppKit
import UniformTypeIdentifiers

/// Exporta e importa el historial como un archivo JSON local.
@MainActor
enum ImportExport {
    private struct ExportFile: Codable {
        var format = "pasteanything"
        var version = 1
        var exportedAt: Date
        var collections: [ExportedCollection]
        var clips: [ExportedClip]
    }

    private struct ExportedCollection: Codable {
        let name: String
        let symbol: String
        let color: String
    }

    private struct ExportedClip: Codable {
        let kind: String
        let text: String?
        let data: Data?
        let sourceApp: String?
        let sourceBundleID: String?
        let createdAt: Date
        let pinned: Bool
        let collection: String?
    }

    /// Devuelve un mensaje con el resultado, o nil si el usuario canceló.
    static func exportHistory(from store: ClipStore) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "PasteAnything-\(formatter.string(from: Date())).json"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            let collections = try store.collections()
            let names = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0.name) })
            let clips = try store.fetch(query: "", filter: .recent, limit: Int(Int32.max))
            let file = ExportFile(
                exportedAt: Date(),
                collections: collections.map {
                    ExportedCollection(name: $0.name, symbol: $0.symbol, color: $0.color.rawValue)
                },
                clips: clips.map { clip in
                    ExportedClip(
                        kind: clip.kind.rawValue,
                        text: clip.text,
                        data: clip.data,
                        sourceApp: clip.sourceApp,
                        sourceBundleID: clip.sourceBundleID,
                        createdAt: clip.createdAt,
                        pinned: clip.isPinned,
                        collection: clip.collectionID.flatMap { names[$0] }
                    )
                }
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]
            try encoder.encode(file).write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return "Se exportaron \(clips.count) clips."
        } catch {
            return "No se pudo exportar: \(error.localizedDescription)"
        }
    }

    static func importHistory(into store: ClipStore) -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let file = try decoder.decode(ExportFile.self, from: Data(contentsOf: url))
            guard file.format == "pasteanything" else {
                return "El archivo no es una exportación de PasteAnything."
            }

            var collectionIDs = Dictionary(
                try store.collections().map { ($0.name, $0.id) },
                uniquingKeysWith: { first, _ in first }
            )
            for collection in file.collections where collectionIDs[collection.name] == nil {
                collectionIDs[collection.name] = try store.addCollection(
                    name: collection.name,
                    symbol: collection.symbol,
                    color: CollectionColor(rawValue: collection.color) ?? .blue
                )
            }

            var imported = 0
            for clip in file.clips {
                guard let kind = ClipKind(rawValue: clip.kind) else { continue }
                try store.save(
                    NewClip(
                        kind: kind,
                        text: clip.text,
                        data: clip.data,
                        sourceApp: clip.sourceApp,
                        sourceBundleID: clip.sourceBundleID
                    ),
                    date: clip.createdAt,
                    pinned: clip.pinned,
                    collectionID: clip.collection.flatMap { collectionIDs[$0] }
                )
                imported += 1
            }
            return "Se importaron \(imported) clips."
        } catch {
            return "No se pudo importar: \(error.localizedDescription)"
        }
    }
}
