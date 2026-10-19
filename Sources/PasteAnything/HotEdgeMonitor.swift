import AppKit

/// Abre la ventana lateral cuando el puntero se queda un momento en el borde
/// de la pantalla donde aparece.
@MainActor
final class HotEdgeMonitor {
    var onTrigger: () -> Void = {}

    private var monitor: Any?
    private var dwellTimer: Timer?
    private var isAtEdge = false

    func setEnabled(_ enabled: Bool) {
        if enabled, monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                MainActor.assumeIsolated { self?.pointerMoved() }
            }
        } else if !enabled, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            cancelDwell()
        }
    }

    private func pointerMoved() {
        let atEdge = Self.pointerIsAtEdge(PanelEdge.current)
        guard atEdge != isAtEdge else { return }
        isAtEdge = atEdge
        cancelDwell()
        guard atEdge else { return }

        let delay = max(0.1, UserDefaults.standard.double(forKey: PreferenceKey.hotEdgeDelay))
        dwellTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Self.pointerIsAtEdge(PanelEdge.current) else { return }
                self.onTrigger()
            }
        }
    }

    private func cancelDwell() {
        dwellTimer?.invalidate()
        dwellTimer = nil
    }

    private static func pointerIsAtEdge(_ edge: PanelEdge) -> Bool {
        let point = NSEvent.mouseLocation
        guard let frame = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })?.frame else {
            return false
        }
        let tolerance: CGFloat = 2
        switch edge {
        case .left: return point.x <= frame.minX + tolerance
        case .right: return point.x >= frame.maxX - tolerance
        case .top: return point.y >= frame.maxY - tolerance
        case .bottom: return point.y <= frame.minY + tolerance
        }
    }
}
