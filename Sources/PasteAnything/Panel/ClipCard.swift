import AppKit
import SwiftUI

struct ClipCard: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let fillsHeight: Bool
    @ObservedObject var model: HistoryModel

    @AppStorage(PreferenceKey.previewsRichText) private var previewsRichText = true
    @AppStorage(PreferenceKey.showsClipMenuButton) private var showsMenuButton = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
            if fillsHeight {
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(isSelected ? 0.10 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.06),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .overlay(alignment: .bottomTrailing) {
            if showsMenuButton && isSelected {
                Menu {
                    ClipMenu(item: item, model: model)
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)
                .padding(8)
                .help("Acciones")
            }
        }
        .contextMenu {
            ClipMenu(item: item, model: model)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            AppIconView(bundleID: item.sourceBundleID)
                .frame(width: 22, height: 22)
                .help(item.sourceApp ?? "App desconocida")
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
            if let collection = model.collection(for: item) {
                Image(systemName: collection.symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(collection.color.color)
                    .help(collection.name)
            }
            Spacer(minLength: 4)
            RelativeTimeLabel(date: item.createdAt)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .image:
            if let image = ImageCache.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Label("Imagen", systemImage: "photo")
                    .foregroundStyle(.secondary)
            }
        case .file:
            FileList(paths: item.filePaths)
        case .richText where previewsRichText:
            if let attributed = RichTextCache.preview(for: item) {
                Text(attributed)
                    .lineLimit(6)
            } else {
                plainText
            }
        case .text where item.url != nil:
            VStack(alignment: .leading, spacing: 3) {
                Label(item.url?.host() ?? "", systemImage: "link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.preview)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(3)
            }
        default:
            plainText
        }
    }

    private var plainText: some View {
        Text(item.preview)
            .font(.system(size: 13))
            .lineLimit(6)
    }
}

/// Acciones de un clip, compartidas por el menú contextual y el botón de acciones.
struct ClipMenu: View {
    let item: ClipItem
    let model: HistoryModel

    var body: some View {
        Button("Pegar") { model.paste(item) }
        if item.kind == .richText {
            Button("Pegar como texto sin formato") { model.paste(item, asPlainText: true) }
        }
        Button("Copiar") { model.copy(item) }
        Divider()
        Button(item.isPinned ? "Quitar de fijados" : "Fijar") { model.togglePin(item) }
        Menu("Colección") {
            ForEach(model.collections) { collection in
                Button {
                    model.setCollection(collection.id, for: item)
                } label: {
                    Label(collection.name, systemImage: item.collectionID == collection.id ? "checkmark" : collection.symbol)
                }
            }
            if item.collectionID != nil {
                Divider()
                Button("Quitar de la colección") { model.setCollection(nil, for: item) }
            }
            Divider()
            Button("Administrar colecciones…") { model.handler?.openSettings(.collections) }
        }
        if item.kind == .text || item.kind == .richText {
            Menu("Transformar") {
                ForEach(TextTransforms.all) { transform in
                    Button {
                        model.apply(transform, to: item)
                    } label: {
                        Label(transform.title, systemImage: transform.symbol)
                    }
                }
            }
        }
        if item.kind == .image {
            Button("Reconocer texto") { model.recognizeText(in: item) }
        }
        if item.url != nil {
            Button("Abrir enlace") { model.open(item) }
        }
        if item.kind == .file {
            Button("Mostrar en Finder") { model.revealInFinder(item) }
        }
        Divider()
        Button("Borrar", role: .destructive) { model.delete(item) }
    }
}

private struct FileList: View {
    let paths: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(paths.prefix(4), id: \.self) { path in
                HStack(spacing: 6) {
                    Image(nsImage: IconCache.fileIcon(path))
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text((path as NSString).lastPathComponent)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if paths.count > 4 {
                Text("y \(paths.count - 4) más")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AppIconView: View {
    let bundleID: String?

    var body: some View {
        if let image = IconCache.appIcon(bundleID) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(2)
        }
    }
}

private struct RelativeTimeLabel: View {
    let date: Date

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(Self.format(date, relativeTo: context.date))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private static func format(_ date: Date, relativeTo now: Date) -> String {
        now.timeIntervalSince(date) < 10 ? "Justo ahora" : formatter.localizedString(for: date, relativeTo: now)
    }
}

// MARK: - Cachés de imágenes

@MainActor
enum IconCache {
    private static let appIcons = NSCache<NSString, NSImage>()
    private static let fileIcons = NSCache<NSString, NSImage>()
    private static var missingApps = Set<String>()

    static func appIcon(_ bundleID: String?) -> NSImage? {
        guard let bundleID, !missingApps.contains(bundleID) else { return nil }
        if let cached = appIcons.object(forKey: bundleID as NSString) {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            missingApps.insert(bundleID)
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons.setObject(icon, forKey: bundleID as NSString)
        return icon
    }

    static func fileIcon(_ path: String) -> NSImage {
        if let cached = fileIcons.object(forKey: path as NSString) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        fileIcons.setObject(icon, forKey: path as NSString)
        return icon
    }
}

@MainActor
private enum ImageCache {
    private static let thumbnails = NSCache<NSNumber, NSImage>()

    /// Miniatura reducida, para no decodificar capturas de pantalla completas en cada tarjeta.
    static func thumbnail(for item: ClipItem) -> NSImage? {
        let key = NSNumber(value: item.id)
        if let cached = thumbnails.object(forKey: key) {
            return cached
        }
        guard let data = item.data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 600,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        thumbnails.setObject(image, forKey: key)
        return image
    }
}

@MainActor
private enum RichTextCache {
    private static var previews: [Int64: AttributedString] = [:]

    /// Vista previa del texto con formato. Quita los colores para que se lea en modo oscuro
    /// y acota el tamaño de letra.
    static func preview(for item: ClipItem) -> AttributedString? {
        if let cached = previews[item.id] {
            return cached
        }
        guard let data = item.data,
              let text = NSMutableAttributedString(rtf: data, documentAttributes: nil)
        else { return nil }

        if text.length > 600 {
            text.deleteCharacters(in: NSRange(location: 600, length: text.length - 600))
        }
        let range = NSRange(location: 0, length: text.length)
        text.removeAttribute(.foregroundColor, range: range)
        text.removeAttribute(.backgroundColor, range: range)
        text.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? NSFont, font.pointSize < 11 || font.pointSize > 15 else { return }
            text.addAttribute(.font, value: NSFont(descriptor: font.fontDescriptor, size: 13) ?? .systemFont(ofSize: 13), range: subrange)
        }

        guard let preview = try? AttributedString(text, including: \.appKit) else { return nil }
        if previews.count > 500 {
            previews.removeAll()
        }
        previews[item.id] = preview
        return preview
    }
}
