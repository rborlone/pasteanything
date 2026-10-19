import ServiceManagement
import SwiftUI

struct GeneralSettings: View {
    let state: AppState

    @AppStorage(PreferenceKey.paused) private var paused = false
    @AppStorage(PreferenceKey.showInMenuBar) private var showInMenuBar = true
    @AppStorage(PreferenceKey.panelEdge) private var panelEdge = PanelEdge.right.rawValue
    @AppStorage(PreferenceKey.appearance) private var appearance = AppearanceMode.system.rawValue
    @AppStorage(PreferenceKey.previewsRichText) private var previewsRichText = true
    @AppStorage(PreferenceKey.showsClipMenuButton) private var showsClipMenuButton = true
    @AppStorage(PreferenceKey.playSound) private var playSound = false
    @AppStorage(PreferenceKey.maxItems) private var maxItems = 1000
    @AppStorage(PreferenceKey.retentionDays) private var retentionDays = 0

    @State private var launchesAtLogin = LaunchAtLogin.isEnabled
    @State private var launchMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { !paused }, set: { paused = !$0 })) {
                    SettingLabel("Activar", detail: paused ? "Captura en pausa" : "Capturando datos del portapapeles")
                }
            }

            Section("General") {
                Toggle("Ejecutar al iniciar sesión", isOn: Binding(
                    get: { launchesAtLogin },
                    set: { enabled in
                        launchMessage = LaunchAtLogin.set(enabled)
                        launchesAtLogin = LaunchAtLogin.isEnabled
                    }
                ))
                if let launchMessage {
                    Text(launchMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Toggle(isOn: $showInMenuBar) {
                    SettingLabel(
                        "Mostrar en la barra de menús",
                        detail: "Si lo ocultas, abre PasteAnything de nuevo para ver los Ajustes."
                    )
                }
                LabeledContent("Posición de la ventana lateral") {
                    EdgePicker(selection: $panelEdge)
                }
            }

            Section("Visualización") {
                LabeledContent("Apariencia") {
                    AppearancePicker(selection: $appearance)
                }
                Toggle("Vista previa de texto con formato", isOn: $previewsRichText)
                Toggle(isOn: $showsClipMenuButton) {
                    SettingLabel("Mostrar botón de acciones", detail: "Botón de acciones en el clip seleccionado")
                }
                Toggle("Sonido al copiar", isOn: $playSound)
            }

            Section {
                Picker("Guardar hasta", selection: $maxItems) {
                    ForEach([100, 500, 1000, 5000, 20000], id: \.self) { count in
                        Text("\(count) clips").tag(count)
                    }
                }
                Picker("Conservar durante", selection: $retentionDays) {
                    ForEach(RetentionOption.all) { option in
                        Text(option.title).tag(option.days)
                    }
                }
                Button("Borrar historial…", role: .destructive) {
                    state.clearHistory()
                }
            } header: {
                Text("Historial")
            } footer: {
                Text("Los clips fijados o guardados en una colección nunca se borran automáticamente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Devuelve un mensaje si el cambio no se pudo aplicar o requiere aprobación.
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            return "No se pudo cambiar: \(error.localizedDescription)"
        }
        if SMAppService.mainApp.status == .requiresApproval {
            return "Apruébalo en Ajustes del Sistema → General → Ítems de inicio."
        }
        return nil
    }
}

struct EdgePicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PanelEdge.allCases) { edge in
                let isSelected = selection == edge.rawValue
                Button {
                    selection = edge.rawValue
                } label: {
                    Image(systemName: edge.symbol)
                        .font(.system(size: 15))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 34, height: 26)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .help(edge.title)
            }
        }
    }
}

private struct AppearancePicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppearanceMode.allCases) { mode in
                let isSelected = selection == mode.rawValue
                Button {
                    selection = mode.rawValue
                } label: {
                    VStack(spacing: 4) {
                        AppearanceThumbnail(mode: mode)
                            .frame(width: 66, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.accentColor : Color.primary.opacity(0.15),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )
                        Text(mode.title)
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AppearanceThumbnail: View {
    let mode: AppearanceMode

    var body: some View {
        GeometryReader { geometry in
            switch mode {
            case .light:
                window(light: true)
            case .dark:
                window(light: false)
            case .system:
                HStack(spacing: 0) {
                    window(light: true).frame(width: geometry.size.width / 2).clipped()
                    window(light: false).frame(width: geometry.size.width / 2).clipped()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func window(light: Bool) -> some View {
        let line = light ? Color(white: 0.78) : Color(white: 0.34)
        return ZStack(alignment: .topLeading) {
            light ? Color(white: 0.96) : Color(white: 0.17)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(line).frame(height: 6)
                RoundedRectangle(cornerRadius: 2).fill(line).frame(width: 34, height: 4)
                RoundedRectangle(cornerRadius: 2).fill(line).frame(width: 22, height: 4)
            }
            .padding(6)
        }
    }
}
