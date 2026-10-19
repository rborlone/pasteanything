# PasteAnything

Gestor de portapapeles para macOS, **100% local**: no usa la red, no tiene
analítica ni sincronización. Todo el historial queda en un archivo SQLite en tu Mac.

## Funciones

- **Ventana lateral** anclada a un borde de la pantalla (izquierda, derecha,
  arriba o abajo), con tarjetas que muestran la app de origen, la hora, el
  atajo `⌘1`–`⌘9` y una vista previa (texto, texto con formato, imágenes,
  archivos y enlaces).
- **Búsqueda**, clips **fijados** y **colecciones** con ícono y color.
- **Acciones por clip**: pegar, pegar sin formato, copiar, fijar, mover a una
  colección, transformar (mayúsculas, Base64, URL, JSON, hashes, ordenar
  líneas…), reconocer texto en imágenes, abrir enlace, mostrar en Finder y borrar.
- **Capturar texto de la pantalla**: seleccionas una zona y el texto queda
  copiado (reconocimiento con Vision, en el propio Mac).
- **Esquina activa**: abre la ventana al dejar el puntero en el borde.
- **Privacidad por defecto**: ignora contraseñas y contenido temporal marcado
  según la convención de [nspasteboard.org](http://nspasteboard.org)
  (1Password, Bitwarden, Llavero, etc.), apps elegidas y palabras clave.
- Límite de historial y antigüedad máxima; los fijados y los clips en
  colecciones no se borran.
- Importar y exportar el historial en JSON.

## Compilar

Requiere macOS 14 o superior y Xcode.

```bash
./scripts/build.sh
open build/PasteAnything.app
```

Aparece un ícono en la barra de menú y el atajo global **⇧⌘V** abre la ventana
lateral (se puede cambiar en Ajustes → Atajos). Para que el pegado automático
funcione, dale permiso en **Ajustes del Sistema → Privacidad y seguridad →
Accesibilidad**. Como la app se firma localmente, macOS puede volver a pedir ese
permiso después de cada recompilación.

El ícono de la app se genera con `swift scripts/make-icon.swift`.

## Atajos de la ventana lateral

| Tecla | Acción |
|---|---|
| Escribir | Buscar |
| ↑ ↓ | Moverse por los clips |
| ↩ / doble clic | Pegar |
| ⌥↩ | Pegar sin formato |
| ⌘1 … ⌘9 | Pegar el clip de esa posición |
| ⌘P | Fijar o quitar de fijados |
| ⌘C | Copiar sin pegar |
| ⌘⌫ | Borrar |
| ⌘, | Ajustes |
| esc | Limpiar búsqueda o cerrar |

## Estructura del proyecto

```
PasteAnything/
├── Package.swift            # paquete Swift (macOS 14+, sin dependencias externas)
├── Resources/               # Info.plist e ícono de la app
├── scripts/
│   ├── build.sh             # compila y arma build/PasteAnything.app
│   └── make-icon.swift      # genera Resources/AppIcon.icns
├── Sources/PasteAnything/
│   ├── PasteAnythingApp.swift   # arranque, menú de la barra y acciones
│   ├── ClipboardMonitor.swift   # captura y filtros del portapapeles
│   ├── ClipStore.swift          # base de datos SQLite local
│   ├── Panel/                   # ventana lateral y tarjetas
│   ├── Settings/                # ventana de Ajustes
│   └── …                        # modelos, atajos, transformaciones, OCR
└── build/PasteAnything.app  # la app compilada
```

## Dónde quedan los datos

`~/Library/Application Support/PasteAnything/history.sqlite`, con permisos
solo para tu usuario. Puedes borrarlo desde Ajustes o eliminando el archivo.

## Cómo comprobar que es local

El código no usa ninguna API de red. Puedes verificarlo en el binario:

```bash
nm -u build/PasteAnything.app/Contents/MacOS/PasteAnything | grep -E 'URLSession|NWConnection|CFNetwork|_socket$|_connect$|_getaddrinfo$'
```

No debería mostrar nada. También puedes confirmarlo con un monitor de red como
[LuLu](https://objective-see.org/products/lulu.html).
