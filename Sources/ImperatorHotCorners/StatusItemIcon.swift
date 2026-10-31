import AppKit

/// The app's glyph, used by the menu bar item and by the panel header.
///
/// Imperator WidgetClock's frame, drawn with its formula (16 x 12 pt at (1, 3)
/// on an 18 pt canvas, 1.125 pt stroke, 1.7 pt outer radius), with its colon
/// replaced by a mark in each corner: the frame is the screen and the marks are
/// the hot corners. Brandbook 8.1: 18 x 18 pt, template, `.squareLength` item.
enum StatusItemIcon {
    enum CornerMark { case dot, stroke }

    static let dotSize: CGFloat = 2
    /// Dots are twice as wide as they are tall (Goran, 2026-10-31).
    static let dotWidth: CGFloat = 4
    static let markInset: CGFloat = 2

    /// The frame's outer edge, WidgetClock's formula snapped to whole points.
    static func frameRect(size: CGFloat) -> NSRect {
        NSRect(x: ((size - size * (16 / 18)) / 2).rounded(),
               y: ((size - size * (12 / 18)) / 2).rounded(),
               width: (size * (16 / 18)).rounded(),
               height: (size * (12 / 18)).rounded())
    }

    /// The four dots, bottom-left origin, 2 pt inside the frame's corners.
    static func dotRects(size: CGFloat) -> [NSRect] {
        let ink = frameRect(size: size)
        let xs = [ink.minX + markInset, ink.maxX - markInset - dotWidth]
        // As tall as the frame's border is thick (Goran, 2026-10-31). Each dot's
        // outer edge stays on the 2 pt inset, so the pair mirrors exactly.
        let height = borderWidth(size: size)
        let ys = [ink.minY + markInset, ink.maxY - markInset - height]
        return xs.flatMap { x in ys.map { y in NSRect(x: x, y: y, width: dotWidth, height: height) } }
    }

    /// The frame's stroke: 1.125 pt at 18 pt, as WidgetClock draws it.
    static func borderWidth(size: CGFloat) -> CGFloat { size * (1.125 / 18) }

    static func make(size: CGFloat = 18, mark: CornerMark = .dot) -> NSImage {
        let ink = frameRect(size: size)
        let line = borderWidth(size: size)
        // A stroked path is drawn on its centreline, so the radius asked for is
        // half a stroke smaller than the outer one.
        let radius = size * (1.7 / 18) - line / 2
        let dot = dotSize
        let inset = markInset

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSColor.black.setStroke()
            let outline = NSBezierPath(roundedRect: ink.insetBy(dx: line / 2, dy: line / 2),
                                       xRadius: radius, yRadius: radius)
            outline.lineWidth = line
            outline.lineJoinStyle = .round
            outline.stroke()

            let left = ink.minX + inset
            let right = ink.maxX - inset - dot
            let bottom = ink.minY + inset
            let top = ink.maxY - inset - dot
            switch mark {
            case .dot:
                NSColor.black.setFill()
                for rect in dotRects(size: size) { NSBezierPath(rect: rect).fill() }
            case .stroke:
                let reach: CGFloat = 1.75
                let marks = NSBezierPath()
                marks.lineWidth = line
                marks.lineCapStyle = .round
                // Each mark starts at the corner dot's outer point and runs
                // toward the centre of the frame.
                let corners: [(NSPoint, CGFloat, CGFloat)] = [
                    (NSPoint(x: left, y: bottom), 1, 1),
                    (NSPoint(x: right + dot, y: bottom), -1, 1),
                    (NSPoint(x: left, y: top + dot), 1, -1),
                    (NSPoint(x: right + dot, y: top + dot), -1, -1),
                ]
                for (point, dx, dy) in corners {
                    marks.move(to: point)
                    marks.line(to: NSPoint(x: point.x + dx * reach, y: point.y + dy * reach))
                }
                NSColor.black.setStroke()
                marks.stroke()
            }
            return true
        }
        // Template, so macOS inverts it for light and dark menu bars.
        image.isTemplate = true
        return image
    }
}
