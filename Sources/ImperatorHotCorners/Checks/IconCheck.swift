import AppKit

/// `ImperatorHotCorners --icon-check` measures the drawn glyph in pixels against
/// the geometry written down in SPEC.md, not against the code that draws it: the
/// WidgetClock frame, and dots 4 pt wide and as tall as the border, with their
/// outer corners 2 pt inside the frame's.
@MainActor
enum IconCheck {
    private struct Expected {
        let frame: NSRect
        let dots: [NSRect]
    }

    /// Bottom-left origin, in points.
    private static let expected: [CGFloat: Expected] = [
        18: Expected(frame: NSRect(x: 1, y: 3, width: 16, height: 12),
                     dots: [NSRect(x: 3, y: 5, width: 4, height: 1.125), NSRect(x: 11, y: 5, width: 4, height: 1.125),
                            NSRect(x: 3, y: 11.875, width: 4, height: 1.125), NSRect(x: 11, y: 11.875, width: 4, height: 1.125)]),
        16: Expected(frame: NSRect(x: 1, y: 3, width: 14, height: 11),
                     dots: [NSRect(x: 3, y: 5, width: 4, height: 1), NSRect(x: 9, y: 5, width: 4, height: 1),
                            NSRect(x: 3, y: 11, width: 4, height: 1), NSRect(x: 9, y: 11, width: 4, height: 1)]),
    ]

    /// 8x makes every expected edge, 1.125 pt included, land on a whole pixel.
    private static let scale = 8

    /// Alpha of the image drawn at `scale`, row 0 at the bottom.
    private static func alpha(of image: NSImage, scale: Int) -> (data: [UInt8], width: Int, height: Int)? {
        let width = Int(image.size.width) * scale
        let height = Int(image.size.height) * scale
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4, bitsPerPixel: 32),
            let context = NSGraphicsContext(bitmapImageRep: rep),
            let bytes = rep.bitmapData
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        var data = [UInt8](repeating: 0, count: width * height)
        for row in 0..<height {
            for x in 0..<width {
                // Bitmap rows run top down; flip so row 0 is the bottom, like points.
                data[(height - 1 - row) * width + x] = bytes[row * rep.bytesPerRow + x * 4 + 3]
            }
        }
        return (data, width, height)
    }

    static func run() -> Int32 {
        _ = NSApplication.shared
        var failures: [String] = []
        let expect = { (ok: Bool, message: String) in if !ok { failures.append(message) } }

        for mark in [StatusItemIcon.CornerMark.dot, .stroke] {
            for (size, want) in expected.sorted(by: { $0.key > $1.key }) {
                let name = "\(mark) \(Int(size))pt"
                let icon = StatusItemIcon.make(size: size, mark: mark)
                expect(icon.isTemplate, "\(name): not a template image")
                expect(icon.size == NSSize(width: size, height: size), "\(name): canvas is \(icon.size)")
                guard let a = alpha(of: icon, scale: scale) else {
                    failures.append("\(name): could not rasterize"); continue
                }
                let px = { (p: CGFloat) in Int((p * CGFloat(scale)).rounded()) }
                func at(_ x: Int, _ y: Int) -> UInt8 { a.data[y * a.width + x] }

                // The frame's outer edge.
                var minX = a.width, maxX = -1, minY = a.height, maxY = -1
                for y in 0..<a.height {
                    for x in 0..<a.width where at(x, y) >= 128 {
                        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
                let box = NSRect(x: CGFloat(minX) / CGFloat(scale), y: CGFloat(minY) / CGFloat(scale),
                                 width: CGFloat(maxX - minX + 1) / CGFloat(scale), height: CGFloat(maxY - minY + 1) / CGFloat(scale))
                print("\(name) frame \(box.width) x \(box.height) at (\(box.minX), \(box.minY)), spec \(want.frame.width) x \(want.frame.height)")
                expect(box == want.frame, "\(name): frame is \(box), spec says \(want.frame)")

                // Left-right mirror symmetry, and top-bottom where the frame is centred.
                var worstH = 0, worstV = 0
                for y in 0..<a.height {
                    for x in 0..<a.width {
                        worstH = max(worstH, abs(Int(at(x, y)) - Int(at(a.width - 1 - x, y))))
                        worstV = max(worstV, abs(Int(at(x, y)) - Int(at(x, a.height - 1 - y))))
                    }
                }
                expect(worstH <= 16, "\(name): not left-right symmetric (worst alpha gap \(worstH))")
                if want.frame.midY == size / 2 {
                    expect(worstV <= 16, "\(name): not top-bottom symmetric (worst alpha gap \(worstV))")
                }

                // Each dot fills exactly its rectangle: solid inside, clear in the
                // pixel row and column just outside.
                guard mark == .dot else { continue }
                for dot in want.dots {
                    let x0 = px(dot.minX), x1 = px(dot.maxX), y0 = px(dot.minY), y1 = px(dot.maxY)
                    for y in y0..<y1 { for x in x0..<x1 where at(x, y) < 250 {
                        failures.append("\(name): dot \(dot) not solid at pixel (\(x), \(y))"); break
                    } }
                    let ring = (x0..<x1).flatMap { [($0, y0 - 1), ($0, y1)] } + (y0..<y1).flatMap { [(x0 - 1, $0), (x1, $0)] }
                    for (x, y) in ring where at(x, y) > 8 {
                        failures.append("\(name): dot \(dot) spills to pixel (\(x), \(y))"); break
                    }
                }
            }
        }
        if failures.isEmpty {
            print("ICON_CHECK_OK")
            return 0
        }
        for failure in failures { print("FAIL \(failure)") }
        return 1
    }
}
