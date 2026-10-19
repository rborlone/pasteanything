# CLAUDE.md

Guía para trabajar en PasteAnything, un gestor de portapapeles para macOS en
Swift + SwiftUI. Ver `README.md` para las funciones y el uso.

## Regla principal: 100% local

- **No agregar código de red**: nada de `URLSession`, `Network`, `WebKit`,
  sockets, SDKs de analítica, reportes de errores ni sincronización.
  Abrir un enlace en el navegador por pedido del usuario (`NSWorkspace.open`) sí está permitido.
- Las funciones que en otras apps usan servicios externos se resuelven en el Mac
  (por ejemplo, el reconocimiento de texto usa Vision).
- Después de compilar, verifica que el binario sigue sin símbolos de red:
  ```bash
  nm -u build/PasteAnything.app/Contents/MacOS/PasteAnything | grep -E 'URLSession|NWConnection|CFNetwork|_socket$|_connect$|_getaddrinfo$'
  ```
  No debe mostrar nada.
- La privacidad viene activada por defecto: los filtros de contraseñas y
  contenido temporal parten encendidos. No cambiar esos valores por defecto.

## Compilar y ejecutar

```bash
./scripts/build.sh                      # compila en release y arma build/PasteAnything.app
pkill -x PasteAnything; open build/PasteAnything.app
open build/PasteAnything.app --args --show-panel      # abre la ventana lateral al iniciar
open build/PasteAnything.app --args --show-settings   # abre los Ajustes al iniciar
swift scripts/make-icon.swift           # regenera Resources/AppIcon.icns
```

- Requiere macOS 14+ y Xcode. Es un paquete de Swift Package Manager sin proyecto de Xcode.
- `build.sh` firma ad hoc; macOS puede volver a pedir el permiso de Accesibilidad tras cada compilación.
- No hay tests automatizados. Para probar la captura sin intervención: copia con
  `pbcopy` y consulta `~/Library/Application Support/PasteAnything/history.sqlite`
  con `sqlite3`. Guarda y restaura el portapapeles del usuario, y borra los clips de prueba.

## Arquitectura

| Archivo | Responsabilidad |
|---|---|
| `PasteAnythingApp.swift` | Punto de entrada, menú de la barra, `AppState` (une todo e implementa `ClipActionHandler`: pegar, copiar, OCR, borrar) y `AppDelegate` |
| `ClipboardMonitor.swift` | Revisa `NSPasteboard.changeCount` cada 0,5 s, aplica filtros (tipos ocultos/temporales, apps y palabras ignoradas, tipos permitidos) y guarda |
| `ClipStore.swift` | SQLite con la API C (`sqlite3`). Tablas `clips` y `collections`; migraciones en `migrate()` |
| `ClipItem.swift` | Modelos: `NewClip`, `ClipItem`, `ClipFilter`, `ClipCollection`, `CollectionColor` |
| `HistoryModel.swift` | Estado de la ventana lateral (búsqueda, filtro, selección) y protocolo `ClipActionHandler` |
| `Paster.swift` | Escribe en el portapapeles y simula ⌘V con `CGEvent` |
| `Preferences.swift` | Claves de `UserDefaults`, valores por defecto y enums de ajustes (`PanelEdge`, `AppearanceMode`, `HotKeyPreset`) |
| `HotKey.swift` / `HotEdgeMonitor.swift` | Atajo global (Carbon) y apertura al tocar el borde de la pantalla |
| `TextTransforms.swift` / `TextRecognizer.swift` | Transformaciones de texto y OCR con Vision / captura con `screencapture` |
| `ImportExport.swift` | Exportar e importar el historial en JSON |
| `Panel/` | Ventana lateral: controlador del `NSPanel`, vista principal y tarjetas |
| `Settings/` | Ventana de Ajustes con barra lateral; una vista por sección |

Flujo: `ClipboardMonitor` → `ClipStore.save` → notificación `ClipStore.didChange`
→ `HistoryModel.reload` → la vista se actualiza.

## Detalles que no hay que romper

- **El panel no debe activar la app.** Es un `NSPanel` con `.nonactivatingPanel`
  y `canBecomeKey = true`: recibe teclado pero la app de destino sigue al frente.
  Antes de simular ⌘V se cierra con `close(animated: false)` para devolverle el teclado.
- Después de escribir en el portapapeles desde la app, llama a
  `monitor.markOwnWrite()` para no volver a capturar lo mismo.
- Los clips fijados o dentro de una colección nunca se borran por límite ni antigüedad.
- Los clips repetidos se detectan por `hash` (SHA-256 del contenido) y solo se suben al principio.
- Los ajustes se leen en vivo desde `UserDefaults`; `AppState.applyPreferences()`
  reacciona a los cambios (atajo, apariencia, esquina activa).
- La ventana de Ajustes es un `NSWindow` propio (`SettingsWindowController`), no
  la escena `Settings` de SwiftUI, para poder abrirla desde el panel.

## Convenciones

- Interfaz, comentarios y mensajes en **español**.
- Swift en modo de lenguaje 5 (`swift-tools-version:5.10`). Las clases de UI y
  estado son `@MainActor`; en callbacks de `Timer`/`NotificationCenter` usa
  `MainActor.assumeIsolated`.
- Sigue el estilo existente: comentarios breves que explican el porqué, vistas
  pequeñas y privadas por archivo, sin dependencias externas.
- Compila sin advertencias antes de dar un cambio por terminado.
