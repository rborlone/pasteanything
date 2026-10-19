import AppKit
import SwiftUI

@main
struct PasteAnythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(PreferenceKey.showInMenuBar) private var showInMenuBar = true
    @AppStorage(PreferenceKey.paused) private var paused = false

    var body: some Scene {
        MenuBarExtra(isInserted: $showInMenuBar) {
            Button("Mostrar historial (\(HotKeyPreset.current.title))") { appDelegate.state?.panel.show() }
            Toggle("Pausar captura", isOn: $paused)
            Button("Capturar texto de la pantalla") { appDelegate.state?.captureScreenText() }
            Divider()
            Button("Ajustes…") { appDelegate.state?.openSettings(nil) }
                .keyboardShortcut(",")
            Button("Acerca de PasteAnything") { appDelegate.state?.showAbout() }
            Divider()
            Button("Salir de PasteAnything") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            Image(systemName: paused ? "pause.circle" : "doc.on.clipboard")
        }
    }
}

@MainActor
final class AppState: ClipActionHandler {
    let store: ClipStore
    let monitor: ClipboardMonitor
    let model: HistoryModel
    let panel: HistoryPanelController
    private let hotKey: HotKey
    private let hotEdge: HotEdgeMonitor
    private lazy var settings = SettingsWindowController(state: self)
    private var defaultsObserver: NSObjectProtocol?
    private var appliedHotKey: HotKeyPreset?
    private var appliedAppearance: AppearanceMode?

    init() throws {
        store = try ClipStore()
        monitor = ClipboardMonitor(store: store)
        model = HistoryModel(store: store)
        panel = HistoryPanelController(model: model)
        hotKey = HotKey()
        hotEdge = HotEdgeMonitor()

        model.handler = self
        hotKey.action = { [weak self] in self?.panel.toggle() }
        hotEdge.onTrigger = { [weak self] in
            guard let self, !self.panel.isVisible else { return }
            self.panel.show()
        }

        applyPreferences()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyPreferences() }
        }
        monitor.start()
    }

    private func applyPreferences() {
        let preset = HotKeyPreset.current
        if preset != appliedHotKey {
            hotKey.register(preset)
            appliedHotKey = preset
        }
        let appearance = AppearanceMode.current
        if appearance != appliedAppearance {
            appearance.apply()
            appliedAppearance = appearance
        }
        hotEdge.setEnabled(UserDefaults.standard.bool(forKey: PreferenceKey.hotEdgeEnabled))
    }

    // MARK: - ClipActionHandler

    func paste(_ item: ClipItem, asPlainText: Bool) {
        let plainText = asPlainText || UserDefaults.standard.bool(forKey: PreferenceKey.alwaysPlainText)
        Paster.copy(item, asPlainText: plainText)
        monitor.markOwnWrite()
        try? store.touch(id: item.id)
        sendPasteToFrontApp()
    }

    func copyToClipboard(_ item: ClipItem) {
        Paster.copy(item)
        monitor.markOwnWrite()
        try? store.touch(id: item.id)
        closePanel()
    }

    func pasteText(_ text: String) {
        saveGeneratedText(text)
        Paster.copy(text: text)
        monitor.markOwnWrite()
        sendPasteToFrontApp()
    }

    func recognizeText(in item: ClipItem) {
        guard let data = item.data else { return }
        Task {
            guard let text = await TextRecognizer.recognizeText(in: data) else {
                NSSound.beep()
                return
            }
            saveGeneratedText(text)
            Paster.copy(text: text)
            monitor.markOwnWrite()
            model.selection = model.items.first?.id
        }
    }

    func captureScreenText() {
        panel.close(animated: false)
        Task {
            guard let image = await TextRecognizer.captureScreenRegion() else { return }
            guard let text = await TextRecognizer.recognizeText(in: image) else {
                NSSound.beep()
                return
            }
            saveGeneratedText(text)
            Paster.copy(text: text)
            monitor.markOwnWrite()
            NSSound(named: "Tink")?.play()
        }
    }

    func closePanel() {
        panel.close()
    }

    func openSettings(_ page: SettingsPage?) {
        panel.close(animated: false)
        settings.show(page: page)
    }

    func showAbout() {
        openSettings(.about)
    }

    func clearHistory() {
        panel.close(animated: false)
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "¿Borrar todo el historial?"
        alert.informativeText = "Se conservan los clips fijados y los que están en colecciones. Esta acción no se puede deshacer."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Borrar")
        alert.addButton(withTitle: "Cancelar")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        try? store.deleteUnpinned()
    }

    func clearSystemClipboard() {
        Paster.clearSystemClipboard()
        monitor.markOwnWrite()
    }

    func convertClipboardToPlainText() {
        if Paster.convertClipboardToPlainText() {
            monitor.markOwnWrite()
        } else {
            NSSound.beep()
        }
    }

    // MARK: - Pegado

    /// Cierra el panel al instante (para devolver el teclado a la app de destino) y simula ⌘V.
    private func sendPasteToFrontApp() {
        let keepsOpen = model.keepsOpen
        panel.close(animated: false)

        guard UserDefaults.standard.bool(forKey: PreferenceKey.autoPaste) else { return }
        guard Paster.hasAccessibilityPermission else {
            Paster.requestAccessibilityPermission()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            Paster.sendPasteKeystroke()
            if keepsOpen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.panel.showWithoutFocus()
                }
            }
        }
    }

    private func saveGeneratedText(_ text: String) {
        try? store.save(NewClip(
            kind: .text,
            text: text,
            data: nil,
            sourceApp: "PasteAnything",
            sourceBundleID: Bundle.main.bundleIdentifier
        ))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var state: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.register()
        do {
            state = try AppState()
            // Para abrir una vista directamente al lanzar: open PasteAnything.app --args --show-panel
            if CommandLine.arguments.contains("--show-panel") {
                state?.panel.show()
            } else if CommandLine.arguments.contains("--show-settings") {
                state?.openSettings(nil)
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "PasteAnything no pudo iniciar"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    /// Al abrir la app de nuevo (por ejemplo, si el ícono de la barra está oculto) se muestran los Ajustes.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        state?.openSettings(nil)
        return true
    }
}
