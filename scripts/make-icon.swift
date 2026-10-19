// Genera Resources/AppIcon.icns: degradado con un símbolo de portapapeles.
// Uso: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func renderIcon(size: Int) -> Data {
    let pixels = CGFloat(size)
    let image = NSImage(size: NSSize(width: pixels, height: pixels), flipped: false) { rect in
        // Margen y radio de la plantilla de íconos de macOS.
        let inset = rect.width * 0.1
        let body = rect.insetBy(dx: inset, dy: inset)
        let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)

        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -rect.width * 0.01)
        shadow.shadowBlurRadius = rect.width * 0.02
        shadow.set()
        NSGradient(colors: [
            NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.86, alpha: 1),
            NSColor(calibratedRed: 0.24, green: 0.36, blue: 0.95, alpha: 1),
        ])?.draw(in: path, angle: -60)
        NSGraphicsContext.current?.restoreGraphicsState()

        let configuration = NSImage.SymbolConfiguration(pointSize: body.width * 0.5, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        if let symbol = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) {
            let symbolSize = symbol.size
            symbol.draw(in: NSRect(
                x: body.midX - symbolSize.width / 2,
                y: body.midY - symbolSize.height / 2,
                width: symbolSize.width,
                height: symbolSize.height
            ))
        }
        return true
    }
    let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    representation.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return representation.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try renderIcon(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try renderIcon(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let output = root.appendingPathComponent("Resources/AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
print(process.terminationStatus == 0 ? "Ícono generado: \(output.path)" : "iconutil falló")
