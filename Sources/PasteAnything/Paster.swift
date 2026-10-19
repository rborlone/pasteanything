import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
enum Paster {
    /// Pone el elemento en el portapapeles del sistema.
    static func copy(_ item: ClipItem, asPlainText: Bool = false) {
        if asPlainText, let text = item.plainText {
            copy(text: text)
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .richText:
            let pasteboardItem = NSPasteboardItem()
            if let rtf = item.data {
                pasteboardItem.setData(rtf, forType: .rtf)
            }
            pasteboardItem.setString(item.text ?? "", forType: .string)
            pasteboard.writeObjects([pasteboardItem])
        case .image:
            if let data = item.data, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .file:
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
            pasteboard.writeObjects(urls)
        }
    }

    static func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func clearSystemClipboard() {
        NSPasteboard.general.clearContents()
    }

    /// Reemplaza el contenido actual del portapapeles por su versión sin formato.
    static func convertClipboardToPlainText() -> Bool {
        let pasteboard = NSPasteboard.general
        guard let text = pasteboard.string(forType: .string) else { return false }
        copy(text: text)
        return true
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Simula ⌘V en la app activa. Requiere permiso de Accesibilidad.
    static func sendPasteKeystroke() {
        guard hasAccessibilityPermission else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
