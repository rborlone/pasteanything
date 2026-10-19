import CryptoKit
import Foundation

struct TextTransform: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let apply: (String) -> String?
}

enum TextTransforms {
    static let all: [TextTransform] = [
        TextTransform(id: "uppercase", title: "MAYÚSCULAS", symbol: "textformat.size.larger") {
            $0.uppercased()
        },
        TextTransform(id: "lowercase", title: "minúsculas", symbol: "textformat.size.smaller") {
            $0.lowercased()
        },
        TextTransform(id: "capitalized", title: "Tipo Título", symbol: "textformat") {
            $0.capitalized
        },
        TextTransform(id: "trim", title: "Quitar espacios al inicio y al final", symbol: "scissors") {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        },
        TextTransform(id: "singleLine", title: "Unir en una sola línea", symbol: "arrow.right.to.line") {
            lines($0).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        },
        TextTransform(id: "sortLines", title: "Ordenar líneas", symbol: "arrow.up.arrow.down") {
            lines($0).sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: "\n")
        },
        TextTransform(id: "uniqueLines", title: "Quitar líneas duplicadas", symbol: "line.3.horizontal.decrease") {
            var seen = Set<String>()
            return lines($0).filter { seen.insert($0).inserted }.joined(separator: "\n")
        },
        TextTransform(id: "reverseLines", title: "Invertir orden de líneas", symbol: "arrow.uturn.down") {
            lines($0).reversed().joined(separator: "\n")
        },
        TextTransform(id: "base64Encode", title: "Codificar en Base64", symbol: "lock") {
            Data($0.utf8).base64EncodedString()
        },
        TextTransform(id: "base64Decode", title: "Decodificar Base64", symbol: "lock.open") {
            Data(base64Encoded: $0.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { String(data: $0, encoding: .utf8) }
        },
        TextTransform(id: "urlEncode", title: "Codificar para URL", symbol: "link") {
            $0.addingPercentEncoding(withAllowedCharacters: urlValueAllowed)
        },
        TextTransform(id: "urlDecode", title: "Decodificar URL", symbol: "link") {
            $0.removingPercentEncoding
        },
        TextTransform(id: "jsonPretty", title: "Formatear JSON", symbol: "curlybraces") {
            reformatJSON($0, pretty: true)
        },
        TextTransform(id: "jsonMinify", title: "Compactar JSON", symbol: "curlybraces.square") {
            reformatJSON($0, pretty: false)
        },
        TextTransform(id: "sha256", title: "Hash SHA-256", symbol: "number") {
            hex(SHA256.hash(data: Data($0.utf8)))
        },
        TextTransform(id: "md5", title: "Hash MD5", symbol: "number") {
            hex(Insecure.MD5.hash(data: Data($0.utf8)))
        },
    ]

    private static let urlValueAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

    private static func lines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
    }

    private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func reformatJSON(_ text: String, pretty: Bool) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { return nil }
        var options: JSONSerialization.WritingOptions = [.withoutEscapingSlashes, .fragmentsAllowed]
        if pretty {
            options.insert(.prettyPrinted)
        }
        guard let output = try? JSONSerialization.data(withJSONObject: object, options: options) else { return nil }
        return String(data: output, encoding: .utf8)
    }
}
