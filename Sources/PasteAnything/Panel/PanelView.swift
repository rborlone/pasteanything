import SwiftUI

struct PanelView: View {
    @ObservedObject var model: HistoryModel
    @AppStorage(PreferenceKey.panelEdge) private var edgeRaw = PanelEdge.right.rawValue
    @AppStorage(PreferenceKey.paused) private var paused = false
    @FocusState private var isSearchFocused: Bool

    private var edge: PanelEdge {
        PanelEdge(rawValue: edgeRaw) ?? .right
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if paused {
                pausedBanner
            }
            clips
            PanelToolbar(model: model, edge: edge, paused: $paused)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .onAppear { isSearchFocused = true }
        .onChange(of: model.focusRequest) { isSearchFocused = true }
    }

    // MARK: - Búsqueda

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar", text: $model.query)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onKeyPress(phases: .down, action: handleKey)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding([.horizontal, .top], 8)
    }

    private var pausedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "pause.circle.fill")
            Text("Captura en pausa")
            Spacer()
            Button("Reanudar") { paused = false }
                .buttonStyle(.link)
        }
        .font(.caption)
        .padding(8)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding([.horizontal, .top], 8)
    }

    // MARK: - Lista

    @ViewBuilder
    private var clips: some View {
        if model.items.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView(edge.isVertical ? .vertical : .horizontal) {
                    if edge.isVertical {
                        LazyVStack(spacing: 8) { cards(fillsHeight: false) }
                            .padding(8)
                    } else {
                        LazyHStack(spacing: 8) { cards(fillsHeight: true) }
                            .padding(8)
                    }
                }
                .onChange(of: model.selection) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) }
                }
            }
        }
    }

    private func cards(fillsHeight: Bool) -> some View {
        ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
            ClipCard(
                item: item,
                index: index,
                isSelected: model.selection == item.id,
                fillsHeight: fillsHeight,
                model: model
            )
            .frame(width: fillsHeight ? 240 : nil)
            .id(item.id)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture(count: 2) { model.paste(item) }
            .simultaneousGesture(TapGesture().onEnded { model.select(item) })
        }
    }

    private var emptyState: some View {
        let (title, message): (String, String) = if !model.query.isEmpty {
            ("Sin resultados", "No hay clips que contengan «\(model.query)».")
        } else {
            switch model.filter {
            case .recent: ("Historial vacío", "Copia algo y aparecerá aquí.")
            case .pinned: ("Sin fijados", "Fija un clip con ⌘P para tenerlo siempre a mano.")
            case .collection: ("Colección vacía", "Agrega clips desde su menú → Colección.")
            }
        }
        return ContentUnavailableView(title, systemImage: "doc.on.clipboard", description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Teclado

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let command = press.modifiers.contains(.command)
        let navigatesHorizontally = !edge.isVertical && model.query.isEmpty

        switch press.key {
        case .upArrow:
            model.moveSelection(by: -1)
            return .handled
        case .downArrow:
            model.moveSelection(by: 1)
            return .handled
        case .leftArrow where navigatesHorizontally:
            model.moveSelection(by: -1)
            return .handled
        case .rightArrow where navigatesHorizontally:
            model.moveSelection(by: 1)
            return .handled
        case .return:
            model.paste(asPlainText: press.modifiers.contains(.option) || press.modifiers.contains(.shift))
            return .handled
        case .escape:
            if model.query.isEmpty {
                model.close()
            } else {
                model.query = ""
            }
            return .handled
        case .delete where command:
            model.delete()
            return .handled
        default:
            break
        }

        guard command, let character = press.characters.first else { return .ignored }
        switch character {
        case "1"..."9":
            model.paste(at: Int(String(character))! - 1)
            return .handled
        case "p":
            model.togglePin()
            return .handled
        case "c" where model.query.isEmpty:
            model.copy()
            return .handled
        case ",":
            model.handler?.openSettings(nil)
            return .handled
        default:
            return .ignored
        }
    }
}

// MARK: - Barra inferior

private struct PanelToolbar: View {
    @ObservedObject var model: HistoryModel
    let edge: PanelEdge
    @Binding var paused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    FilterButton(symbol: "clock", title: "Recientes", tint: .accentColor, isActive: model.filter == .recent) {
                        model.filter = .recent
                    }
                    FilterButton(symbol: "heart.fill", title: "Fijados", tint: .pink, isActive: model.filter == .pinned) {
                        model.filter = .pinned
                    }
                    ForEach(model.collections) { collection in
                        FilterButton(
                            symbol: collection.symbol,
                            title: collection.name,
                            tint: collection.color.color,
                            isActive: model.filter == .collection(collection.id)
                        ) {
                            model.filter = .collection(collection.id)
                        }
                    }
                    FilterButton(symbol: "plus", title: "Nueva colección", tint: .secondary, isActive: false) {
                        model.handler?.openSettings(.collections)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 6)

            HStack(spacing: 2) {
                ToolbarIconButton(symbol: edge.closeSymbol, help: "Cerrar (esc)") {
                    model.close()
                }
                ToolbarIconButton(
                    symbol: model.keepsOpen ? "pin.fill" : "pin",
                    help: model.keepsOpen ? "Dejar de mantener abierto" : "Mantener abierto",
                    isActive: model.keepsOpen
                ) {
                    model.keepsOpen.toggle()
                }
                Spacer()
                Text(countLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                PanelMenu(model: model, paused: $paused)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private var countLabel: String {
        let count = model.items.count
        return count == 1 ? "1 clip" : "\(count) clips"
    }
}

private struct FilterButton: View {
    let symbol: String
    let title: String
    let tint: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? tint : Color.secondary)
                .frame(width: 32, height: 26)
                .background(
                    isActive ? tint.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct ToolbarIconButton: View {
    let symbol: String
    let help: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct PanelMenu: View {
    let model: HistoryModel
    @Binding var paused: Bool

    var body: some View {
        Menu {
            Toggle("Pausar captura", isOn: $paused)
            Button("Capturar texto de la pantalla") { model.handler?.captureScreenText() }
            Button("Convertir portapapeles a texto sin formato") { model.handler?.convertClipboardToPlainText() }
            Divider()
            Button("Ajustes…") { model.handler?.openSettings(nil) }
            Button("Acerca de PasteAnything") { model.handler?.showAbout() }
            Divider()
            Button("Borrar todo el historial…") { model.handler?.clearHistory() }
            Button("Borrar portapapeles del sistema") { model.handler?.clearSystemClipboard() }
            Divider()
            Button("Salir de PasteAnything") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help("Opciones")
    }
}
