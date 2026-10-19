import AppKit
import SwiftUI

/// Panel sin bordes que recibe teclado sin activar la app, así la app de destino
/// sigue al frente y recibe el pegado.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Ventana lateral anclada a un borde de la pantalla.
@MainActor
final class HistoryPanelController {
    private static let thickness: CGFloat = 300
    private static let margin: CGFloat = 8
    private static let slideDistance: CGFloat = 40

    private let model: HistoryModel
    private var panel: KeyPanel?
    private var resignObserver: NSObjectProtocol?
    private var animationGeneration = 0

    init(model: HistoryModel) {
        self.model = model
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle() {
        isVisible ? close() : show()
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        animationGeneration += 1

        let (frame, hiddenFrame) = frames()
        model.prepareForDisplay()
        if !panel.isVisible {
            panel.setFrame(hiddenFrame, display: false)
            panel.alphaValue = 0
        }
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    /// Muestra el panel sin quitarle el teclado a la app activa.
    func showWithoutFocus() {
        guard let panel else { return }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func close(animated: Bool = true) {
        guard let panel, panel.isVisible else { return }
        animationGeneration += 1
        guard animated else {
            panel.orderOut(nil)
            return
        }

        let generation = animationGeneration
        let hiddenFrame = frames().hidden
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hiddenFrame, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard self?.animationGeneration == generation else { return }
                panel.orderOut(nil)
            }
        })
    }

    private func makePanel() -> KeyPanel {
        let panel = KeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.thickness, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PanelView(model: model))

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.model.keepsOpen else { return }
                self.close()
            }
        }
        return panel
    }

    /// Posición visible y posición de entrada (desplazada hacia el borde) en la pantalla del puntero.
    private func frames() -> (visible: NSRect, hidden: NSRect) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let area = (screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900))
            .insetBy(dx: Self.margin, dy: Self.margin)
        let size = Self.thickness
        let slide = Self.slideDistance

        switch PanelEdge.current {
        case .right:
            let frame = NSRect(x: area.maxX - size, y: area.minY, width: size, height: area.height)
            return (frame, frame.offsetBy(dx: slide, dy: 0))
        case .left:
            let frame = NSRect(x: area.minX, y: area.minY, width: size, height: area.height)
            return (frame, frame.offsetBy(dx: -slide, dy: 0))
        case .top:
            let frame = NSRect(x: area.minX, y: area.maxY - size, width: area.width, height: size)
            return (frame, frame.offsetBy(dx: 0, dy: slide))
        case .bottom:
            let frame = NSRect(x: area.minX, y: area.minY, width: area.width, height: size)
            return (frame, frame.offsetBy(dx: 0, dy: -slide))
        }
    }
}
