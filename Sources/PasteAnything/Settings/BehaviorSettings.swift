import Combine
import SwiftUI
import UniformTypeIdentifiers

struct HotEdgeSettings: View {
    @AppStorage(PreferenceKey.hotEdgeEnabled) private var enabled = false
    @AppStorage(PreferenceKey.hotEdgeDelay) private var delay = 0.3
    @AppStorage(PreferenceKey.panelEdge) private var panelEdge = PanelEdge.right.rawValue

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enabled) {
                    SettingLabel(
                        "Abrir al llevar el puntero al borde",
                        detail: "Deja el puntero un momento en el borde donde aparece la ventana lateral."
                    )
                }
            }
            Section("Opciones") {
                LabeledContent("Borde") {
                    EdgePicker(selection: $panelEdge)
                }
                LabeledContent("Espera") {
                    HStack {
                        Slider(value: $delay, in: 0.1...1.0, step: 0.1)
                            .frame(width: 180)
                        Text(String(format: "%.1f s", delay))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!enabled)
        }
        .formStyle(.grouped)
    }
}

struct PlainTextSettings: View {
    let state: AppState
    @AppStorage(PreferenceKey.alwaysPlainText) private var alwaysPlainText = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $alwaysPlainText) {
                    SettingLabel(
                        "Pegar siempre como texto sin formato",
                        detail: "Quita fuentes, colores y estilos al pegar."
                    )
                }
            }
            Section("Atajos") {
                LabeledContent("Pegar sin formato el clip seleccionado") {
                    KeyCaps("⌥↩")
                }
                Button("Convertir el portapapeles actual a texto sin formato") {
                    state.convertClipboardToPlainText()
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionSettings: View {
    @AppStorage(PreferenceKey.autoPaste) private var autoPaste = true
    @State private var isTrusted = Paster.hasAccessibilityPermission
    private let refresh = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Accesibilidad") {
                HStack(spacing: 10) {
                    Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(isTrusted ? .green : .orange)
                    SettingLabel(
                        isTrusted ? "Permiso concedido" : "Permiso pendiente",
                        detail: "Necesario para pegar automáticamente en la app que estás usando."
                    )
                    Spacer()
                    if !isTrusted {
                        Button("Dar permiso") {
                            Paster.requestAccessibilityPermission()
                        }
                    }
                }
                Toggle("Pegar automáticamente al elegir un clip", isOn: $autoPaste)
            }
            Section("Grabación de pantalla") {
                Text("Solo se usa en «Capturar texto de la pantalla». macOS lo pide la primera vez que usas esa función.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(refresh) { _ in
            isTrusted = Paster.hasAccessibilityPermission
        }
    }
}

struct AllowSettings: View {
    @AppStorage(PreferenceKey.allowText) private var allowText = true
    @AppStorage(PreferenceKey.allowRichText) private var allowRichText = true
    @AppStorage(PreferenceKey.allowImages) private var allowImages = true
    @AppStorage(PreferenceKey.allowFiles) private var allowFiles = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $allowText) { Label("Texto", systemImage: "text.alignleft") }
                Toggle(isOn: $allowRichText) { Label("Texto con formato", systemImage: "doc.richtext") }
                Toggle(isOn: $allowImages) { Label("Imágenes", systemImage: "photo") }
                Toggle(isOn: $allowFiles) { Label("Archivos", systemImage: "doc") }
            } header: {
                Text("Tipos de contenido que se guardan")
            } footer: {
                Text("Si desactivas «Texto con formato», ese contenido se guarda como texto simple.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct IgnoreSettings: View {
    @AppStorage(PreferenceKey.ignoreConcealed) private var ignoreConcealed = true
    @AppStorage(PreferenceKey.ignoreTransient) private var ignoreTransient = true
    @AppStorage(PreferenceKey.ignoreAutoGenerated) private var ignoreAutoGenerated = true
    @AppStorage(PreferenceKey.ignoredApps) private var ignoredAppsRaw = Preferences.defaultIgnoredApps
    @AppStorage(PreferenceKey.ignoredWords) private var ignoredWords = ""

    private var ignoredApps: [String] {
        ignoredAppsRaw.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            Section("Contenido") {
                Toggle(isOn: $ignoreConcealed) {
                    SettingLabel(
                        "Contraseñas y datos confidenciales",
                        detail: "Lo que marcan como oculto 1Password, Bitwarden, el Llavero y otras apps."
                    )
                }
                Toggle(isOn: $ignoreTransient) {
                    SettingLabel("Contenido temporal", detail: "Datos que las apps marcan como de uso pasajero.")
                }
                Toggle(isOn: $ignoreAutoGenerated) {
                    SettingLabel("Contenido generado automáticamente", detail: "Datos que no copiaste tú directamente.")
                }
            }

            Section {
                ForEach(ignoredApps, id: \.self) { bundleID in
                    HStack(spacing: 8) {
                        AppIconView(bundleID: bundleID)
                            .frame(width: 20, height: 20)
                        Text(Self.appName(for: bundleID) ?? bundleID)
                        Spacer()
                        Text(bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            remove(bundleID)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Quitar")
                    }
                }
                Button("Agregar app…", action: addApp)
            } header: {
                Text("Apps ignoradas")
            } footer: {
                Text("No se guarda nada de lo que copies desde estas apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                TextField("Palabras", text: $ignoredWords, prompt: Text("password, token, clave"))
            } header: {
                Text("Ignorar si contiene")
            } footer: {
                Text("Separa las palabras con comas. No distingue mayúsculas de minúsculas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Ignorar"
        guard panel.runModal() == .OK else { return }
        var apps = ignoredApps
        for url in panel.urls {
            if let bundleID = Bundle(url: url)?.bundleIdentifier, !apps.contains(bundleID) {
                apps.append(bundleID)
            }
        }
        ignoredAppsRaw = apps.joined(separator: "\n")
    }

    private func remove(_ bundleID: String) {
        ignoredAppsRaw = ignoredApps.filter { $0 != bundleID }.joined(separator: "\n")
    }

    /// Nombres de las apps ignoradas por defecto, para mostrarlas aunque no estén instaladas.
    private static let knownApps = [
        "com.1password.1password": "1Password",
        "com.bitwarden.desktop": "Bitwarden",
        "org.keepassxc.keepassxc": "KeePassXC",
    ]

    private static func appName(for bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return knownApps[bundleID]
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

struct TransformSettings: View {
    var body: some View {
        Form {
            Section {
                ForEach(TextTransforms.all) { transform in
                    Label(transform.title, systemImage: transform.symbol)
                }
            } header: {
                Text("Transformaciones disponibles")
            } footer: {
                Text("Clic derecho en un clip de texto → Transformar. El resultado se pega y queda guardado como un clip nuevo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutSettings: View {
    @AppStorage(PreferenceKey.hotKey) private var hotKey = HotKeyPreset.shiftCommandV.rawValue

    private let panelShortcuts: [(String, String)] = [
        ("Pegar el clip seleccionado", "↩"),
        ("Pegar sin formato", "⌥↩"),
        ("Pegar el clip 1 al 9", "⌘1 … ⌘9"),
        ("Moverse por los clips", "↑ ↓"),
        ("Fijar o quitar de fijados", "⌘P"),
        ("Copiar sin pegar", "⌘C"),
        ("Borrar", "⌘⌫"),
        ("Abrir Ajustes", "⌘,"),
        ("Limpiar búsqueda o cerrar", "esc"),
    ]

    var body: some View {
        Form {
            Section("Atajo global") {
                Picker("Abrir la ventana lateral", selection: $hotKey) {
                    ForEach(HotKeyPreset.allCases) { preset in
                        Text(preset.title).tag(preset.rawValue)
                    }
                }
            }
            Section("En la ventana lateral") {
                ForEach(panelShortcuts, id: \.0) { action, keys in
                    LabeledContent(action) {
                        KeyCaps(keys)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct KeyCaps: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.system(.body, design: .rounded).weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
