import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general
    case hotEdge
    case plainText
    case permissions
    case allow
    case ignore
    case collections
    case transforms
    case shortcuts
    case importExport
    case about

    var id: String { rawValue }

    static let groups: [[SettingsPage]] = [
        [.general, .hotEdge, .plainText, .permissions],
        [.allow, .ignore, .collections, .transforms, .shortcuts],
        [.importExport],
        [.about],
    ]

    var title: String {
        switch self {
        case .general: "General"
        case .hotEdge: "Esquina activa"
        case .plainText: "Texto sin formato"
        case .permissions: "Permisos"
        case .allow: "Permitir"
        case .ignore: "Ignorar"
        case .collections: "Colecciones"
        case .transforms: "Transformar"
        case .shortcuts: "Atajos"
        case .importExport: "Importar y exportar"
        case .about: "Acerca de"
        }
    }

    var symbol: String {
        switch self {
        case .general: "macwindow"
        case .hotEdge: "cursorarrow.rays"
        case .plainText: "doc.plaintext"
        case .permissions: "lock.shield.fill"
        case .allow: "hand.thumbsup.fill"
        case .ignore: "hand.thumbsdown.fill"
        case .collections: "square.stack.3d.up.fill"
        case .transforms: "wand.and.stars"
        case .shortcuts: "keyboard"
        case .importExport: "arrow.up.arrow.down"
        case .about: "info"
        }
    }

    var color: Color {
        switch self {
        case .general: .blue
        case .hotEdge: .orange
        case .plainText: .teal
        case .permissions: .red
        case .allow: .green
        case .ignore: .pink
        case .collections: .indigo
        case .transforms: .purple
        case .shortcuts: .cyan
        case .importExport: .mint
        case .about: .gray
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    @Published var page: SettingsPage? = .general
}

@MainActor
final class SettingsWindowController {
    private unowned let state: AppState
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show(page: SettingsPage? = nil) {
        if let page {
            navigation.page = page
        }
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "PasteAnything"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(state: state, navigation: navigation))
        window.center()
        window.setFrameAutosaveName("PasteAnythingSettings")
        return window
    }
}

struct SettingsView: View {
    let state: AppState
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.page) {
                ForEach(SettingsPage.groups.indices, id: \.self) { index in
                    Section {
                        ForEach(SettingsPage.groups[index]) { page in
                            SidebarRow(page: page)
                                .tag(page)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
        } detail: {
            detail(for: navigation.page ?? .general)
                .navigationTitle((navigation.page ?? .general).title)
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    @ViewBuilder
    private func detail(for page: SettingsPage) -> some View {
        switch page {
        case .general: GeneralSettings(state: state)
        case .hotEdge: HotEdgeSettings()
        case .plainText: PlainTextSettings(state: state)
        case .permissions: PermissionSettings()
        case .allow: AllowSettings()
        case .ignore: IgnoreSettings()
        case .collections: CollectionSettings(store: state.store)
        case .transforms: TransformSettings()
        case .shortcuts: ShortcutSettings()
        case .importExport: ImportExportSettings(store: state.store)
        case .about: AboutSettings(store: state.store)
        }
    }
}

private struct SidebarRow: View {
    let page: SettingsPage

    var body: some View {
        Label {
            Text(page.title)
        } icon: {
            Image(systemName: page.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(page.color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.vertical, 2)
    }
}

/// Fila con título y explicación debajo, como en los Ajustes del Sistema.
struct SettingLabel: View {
    let title: String
    let detail: String

    init(_ title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
