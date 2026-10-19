import SwiftUI

struct CollectionSettings: View {
    let store: ClipStore

    @State private var collections: [ClipCollection] = []
    @State private var newName = ""
    @State private var newSymbol = CollectionColor.symbols[0]
    @State private var newColor = CollectionColor.blue

    var body: some View {
        Form {
            Section {
                if collections.isEmpty {
                    Text("Aún no tienes colecciones.")
                        .foregroundStyle(.secondary)
                }
                ForEach(collections) { collection in
                    CollectionRow(collection: collection, store: store)
                }
            } header: {
                Text("Colecciones")
            } footer: {
                Text("Agrupa clips que usas seguido. Los clips de una colección no se borran automáticamente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Nueva colección") {
                HStack(spacing: 8) {
                    SymbolPicker(symbol: $newSymbol, color: newColor)
                    ColorPicker(color: $newColor)
                    TextField("Nombre", text: $newName, prompt: Text("Ej.: Trabajo"))
                        .onSubmit(add)
                    Button("Agregar", action: add)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: ClipStore.didChange)) { _ in reload() }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        _ = try? store.addCollection(name: name, symbol: newSymbol, color: newColor)
        newName = ""
    }

    private func reload() {
        collections = (try? store.collections()) ?? []
    }
}

private struct CollectionRow: View {
    let collection: ClipCollection
    let store: ClipStore

    @State private var name: String
    @State private var symbol: String
    @State private var color: CollectionColor

    init(collection: ClipCollection, store: ClipStore) {
        self.collection = collection
        self.store = store
        _name = State(initialValue: collection.name)
        _symbol = State(initialValue: collection.symbol)
        _color = State(initialValue: collection.color)
    }

    var body: some View {
        HStack(spacing: 8) {
            SymbolPicker(symbol: $symbol, color: color)
            ColorPicker(color: $color)
            TextField("Nombre", text: $name)
                .onSubmit(save)
            Button {
                try? store.deleteCollection(id: collection.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Borrar colección (sus clips vuelven al historial)")
        }
        .onChange(of: symbol) { save() }
        .onChange(of: color) { save() }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try? store.updateCollection(ClipCollection(id: collection.id, name: trimmed, symbol: symbol, color: color))
    }
}

private struct SymbolPicker: View {
    @Binding var symbol: String
    let color: CollectionColor

    var body: some View {
        Menu {
            ForEach(CollectionColor.symbols, id: \.self) { option in
                Button {
                    symbol = option
                } label: {
                    Image(systemName: option)
                }
            }
        } label: {
            Image(systemName: symbol)
                .foregroundStyle(color.color)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Ícono")
    }
}

private struct ColorPicker: View {
    @Binding var color: CollectionColor

    var body: some View {
        Menu {
            ForEach(CollectionColor.allCases) { option in
                Button(option.title) { color = option }
            }
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: 12, height: 12)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Color")
    }
}

struct ImportExportSettings: View {
    let store: ClipStore
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Button("Exportar historial…") {
                    message = ImportExport.exportHistory(from: store)
                }
            } header: {
                Text("Exportar")
            } footer: {
                Text("Guarda todos los clips, fijados y colecciones en un archivo JSON. El archivo no está cifrado: guárdalo en un lugar seguro.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Importar historial…") {
                    message = ImportExport.importHistory(into: store)
                }
            } header: {
                Text("Importar")
            } footer: {
                Text("Agrega los clips de un archivo exportado por PasteAnything. No borra lo que ya tienes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message {
                Section {
                    Text(message)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutSettings: View {
    let store: ClipStore

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                    Text("PasteAnything")
                        .font(.title.bold())
                    Text("Versión \(version)")
                        .foregroundStyle(.secondary)
                    Text("Gestor de portapapeles 100% local.\nSin red, sin analítica y sin sincronización.")
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section("Datos") {
                LabeledContent("Archivo del historial") {
                    Text(store.fileURL.path)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                Button("Mostrar en Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                }
            }
        }
        .formStyle(.grouped)
    }
}
