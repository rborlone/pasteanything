import AppKit

@MainActor
protocol ClipActionHandler: AnyObject {
    func paste(_ item: ClipItem, asPlainText: Bool)
    func copyToClipboard(_ item: ClipItem)
    func pasteText(_ text: String)
    func recognizeText(in item: ClipItem)
    func captureScreenText()
    func closePanel()
    func openSettings(_ page: SettingsPage?)
    func showAbout()
    func clearHistory()
    func clearSystemClipboard()
    func convertClipboardToPlainText()
}

@MainActor
final class HistoryModel: ObservableObject {
    private static let fetchLimit = 300

    @Published var query = "" {
        didSet { if query != oldValue { reload() } }
    }
    @Published var filter: ClipFilter = .recent {
        didSet { if filter != oldValue { reload() } }
    }
    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var collections: [ClipCollection] = []
    @Published var selection: ClipItem.ID?
    @Published var keepsOpen = false
    /// Cambia cada vez que se abre el panel, para devolver el foco a la búsqueda.
    @Published private(set) var focusRequest = 0

    weak var handler: ClipActionHandler?

    private let store: ClipStore
    private var observer: NSObjectProtocol?

    init(store: ClipStore) {
        self.store = store
        observer = NotificationCenter.default.addObserver(
            forName: ClipStore.didChange,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    func prepareForDisplay() {
        query = ""
        reload()
        selection = items.first?.id
        focusRequest += 1
    }

    func reload() {
        do {
            collections = try store.collections()
            if case .collection(let id) = filter, !collections.contains(where: { $0.id == id }) {
                filter = .recent
                return
            }
            items = try store.fetch(query: query, filter: filter, limit: Self.fetchLimit)
        } catch {
            NSLog("PasteAnything: no se pudo leer el historial: \(error.localizedDescription)")
            items = []
        }
        if !items.contains(where: { $0.id == selection }) {
            selection = items.first?.id
        }
    }

    var selectedItem: ClipItem? {
        items.first { $0.id == selection }
    }

    func collection(for item: ClipItem) -> ClipCollection? {
        collections.first { $0.id == item.collectionID }
    }

    func select(_ item: ClipItem) {
        selection = item.id
        focusRequest += 1
    }

    func moveSelection(by offset: Int) {
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selection } ?? 0
        selection = items[min(max(current + offset, 0), items.count - 1)].id
    }

    // MARK: - Acciones

    func paste(_ item: ClipItem? = nil, asPlainText: Bool = false) {
        guard let item = item ?? selectedItem else { return }
        handler?.paste(item, asPlainText: asPlainText)
    }

    func paste(at index: Int) {
        guard items.indices.contains(index) else { return }
        handler?.paste(items[index], asPlainText: false)
    }

    func copy(_ item: ClipItem? = nil) {
        guard let item = item ?? selectedItem else { return }
        handler?.copyToClipboard(item)
    }

    func togglePin(_ item: ClipItem? = nil) {
        guard let item = item ?? selectedItem else { return }
        try? store.setPinned(!item.isPinned, id: item.id)
    }

    func setCollection(_ collectionID: Int64?, for item: ClipItem) {
        try? store.setCollection(collectionID, clipID: item.id)
    }

    func delete(_ item: ClipItem? = nil) {
        guard let item = item ?? selectedItem else { return }
        let index = items.firstIndex(of: item)
        try? store.delete(id: item.id)
        if let index, !items.isEmpty {
            selection = items[min(index, items.count - 1)].id
        }
    }

    func apply(_ transform: TextTransform, to item: ClipItem) {
        guard let text = item.plainText, let result = transform.apply(text) else {
            NSSound.beep()
            return
        }
        handler?.pasteText(result)
    }

    func recognizeText(in item: ClipItem) {
        handler?.recognizeText(in: item)
    }

    func open(_ item: ClipItem) {
        guard let url = item.url else { return }
        NSWorkspace.shared.open(url)
        handler?.closePanel()
    }

    func revealInFinder(_ item: ClipItem) {
        NSWorkspace.shared.activateFileViewerSelecting(item.filePaths.map { URL(fileURLWithPath: $0) })
        handler?.closePanel()
    }

    func close() {
        handler?.closePanel()
    }
}
