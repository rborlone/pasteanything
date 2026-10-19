import AppKit
import CryptoKit
import SwiftUI

enum ClipKind: String {
    case text
    case richText
    case image
    case file
}

/// Contenido capturado del portapapeles, todavía sin guardar.
struct NewClip {
    let kind: ClipKind
    let text: String?
    let data: Data?
    let sourceApp: String?
    let sourceBundleID: String?

    /// Identifica contenido repetido para no duplicarlo en el historial.
    var hash: String {
        var hasher = SHA256()
        hasher.update(data: Data(kind.rawValue.utf8))
        if let text { hasher.update(data: Data(text.utf8)) }
        if let data { hasher.update(data: data) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

struct ClipItem: Identifiable, Equatable {
    let id: Int64
    let kind: ClipKind
    let text: String?
    let data: Data?
    let sourceApp: String?
    let sourceBundleID: String?
    let createdAt: Date
    var isPinned: Bool
    var collectionID: Int64?

    /// Texto que se puede pegar sin formato.
    var plainText: String? {
        kind == .image ? nil : text
    }

    /// Recorte del texto para mostrar en la tarjeta sin cargar textos enormes.
    var preview: String {
        String((text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))
    }

    var filePaths: [String] {
        kind == .file ? (text ?? "").split(separator: "\n").map(String.init) : []
    }

    /// El texto es un único enlace web.
    var url: URL? {
        guard kind == .text, let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.contains(where: \.isWhitespace),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host() != nil
        else { return nil }
        return url
    }

    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool {
        lhs.id == rhs.id
            && lhs.isPinned == rhs.isPinned
            && lhs.createdAt == rhs.createdAt
            && lhs.collectionID == rhs.collectionID
    }
}

enum ClipFilter: Equatable {
    case recent
    case pinned
    case collection(Int64)
}

struct ClipCollection: Identifiable, Equatable {
    let id: Int64
    var name: String
    var symbol: String
    var color: CollectionColor
}

enum CollectionColor: String, CaseIterable, Identifiable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal
    case gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        case .gray: .gray
        }
    }

    var title: String {
        switch self {
        case .blue: "Azul"
        case .purple: "Morado"
        case .pink: "Rosado"
        case .red: "Rojo"
        case .orange: "Naranjo"
        case .yellow: "Amarillo"
        case .green: "Verde"
        case .teal: "Turquesa"
        case .gray: "Gris"
        }
    }

    static let symbols = [
        "folder.fill", "star.fill", "bookmark.fill", "tag.fill", "briefcase.fill",
        "doc.text.fill", "link", "terminal.fill", "curlybraces", "key.fill",
        "person.fill", "cart.fill", "lightbulb.fill", "flag.fill", "paintpalette.fill",
    ]
}
