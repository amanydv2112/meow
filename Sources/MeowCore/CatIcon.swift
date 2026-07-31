import AppKit
import Foundation

/// Vector cat artwork shared by the menu bar glyph and the generated `.icns`,
/// so the two renderings can never drift apart.
///
/// The artwork is authored in a 100x100 design space with the origin at the
/// bottom left, then mapped onto whatever rect it is asked to fill. Nothing is
/// rasterized ahead of time, so it stays crisp from 16px up to 1024px.
public enum CatIcon {
    public static let tileTopColor = NSColor(srgbRed: 0.42, green: 0.36, blue: 0.94, alpha: 1)
    public static let tileBottomColor = NSColor(srgbRed: 0.29, green: 0.23, blue: 0.78, alpha: 1)

    /// A small mark drawn beside the cat to show what the app is doing, so the
    /// menu bar never has to spell the state out in words.
    public enum Badge: Equatable {
        case recording
        case processing
        case paused
        case attention
    }

    /// Monochrome cat for `NSStatusItem`. Marked as a template so macOS tints it
    /// white in dark mode and black in light mode automatically.
    ///
    /// `processingPhase` advances the animated dots and is ignored by every
    /// other badge.
    public static func menuBarImage(
        badge: Badge? = nil,
        processingPhase: Int = 0,
        pointSize: CGFloat = 18
    ) -> NSImage {
        let cat = catImage(size: NSSize(width: pointSize, height: pointSize), color: .black, whiskers: false)
        guard let badge else {
            cat.isTemplate = true
            return cat
        }

        let unit = pointSize / 18
        let gap = 3.5 * unit
        let width = pointSize + gap + badgeWidth(badge, unit: unit)

        let image = NSImage(size: NSSize(width: width, height: pointSize), flipped: false) { rect in
            cat.draw(in: NSRect(x: rect.minX, y: rect.minY, width: pointSize, height: pointSize))
            NSColor.black.setFill()
            drawBadge(
                badge,
                originX: rect.minX + pointSize + gap,
                centerY: rect.midY,
                unit: unit,
                phase: processingPhase
            )
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func badgeWidth(_ badge: Badge, unit: CGFloat) -> CGFloat {
        switch badge {
        case .recording: return 6 * unit
        case .processing: return 11 * unit
        case .paused: return 6 * unit
        case .attention: return 2.4 * unit
        }
    }

    /// Badges are template artwork too, so shape and alpha are the only things
    /// that survive; each state gets a distinct silhouette rather than a colour.
    private static func drawBadge(
        _ badge: Badge,
        originX: CGFloat,
        centerY: CGFloat,
        unit: CGFloat,
        phase: Int
    ) {
        switch badge {
        case .recording:
            let diameter = 6 * unit
            NSBezierPath(ovalIn: NSRect(
                x: originX,
                y: centerY - diameter / 2,
                width: diameter,
                height: diameter
            )).fill()

        case .processing:
            let diameter = 2.5 * unit
            let stride = 4.25 * unit
            for index in 0..<3 {
                let dot = NSBezierPath(ovalIn: NSRect(
                    x: originX + CGFloat(index) * stride,
                    y: centerY - diameter / 2,
                    width: diameter,
                    height: diameter
                ))
                NSColor.black.withAlphaComponent(index == phase % 3 ? 1 : 0.3).setFill()
                dot.fill()
            }
            NSColor.black.setFill()

        case .paused:
            let barWidth = 2 * unit
            let barHeight = 9 * unit
            for index in 0..<2 {
                NSBezierPath(roundedRect: NSRect(
                    x: originX + CGFloat(index) * (barWidth + 2 * unit),
                    y: centerY - barHeight / 2,
                    width: barWidth,
                    height: barHeight
                ), xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
            }

        case .attention:
            let barWidth = 2.4 * unit
            let stemHeight = 6.4 * unit
            NSBezierPath(roundedRect: NSRect(
                x: originX,
                y: centerY + 9 * unit / 2 - stemHeight,
                width: barWidth,
                height: stemHeight
            ), xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
            NSBezierPath(ovalIn: NSRect(
                x: originX,
                y: centerY - 9 * unit / 2,
                width: barWidth,
                height: barWidth
            )).fill()
        }
    }

    /// One square page of the app icon: white cat on the indigo rounded-square tile.
    public static func appIconBitmap(pixelSize: Int) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        rep.size = NSSize(width: pixelSize, height: pixelSize)
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        drawAppIcon(in: NSRect(x: 0, y: 0, width: CGFloat(pixelSize), height: CGFloat(pixelSize)))
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// Apple's icon grid keeps the tile inside the canvas so shadows and badges
    /// have room: an 824pt tile on a 1024pt canvas with a 185pt corner radius.
    private static func drawAppIcon(in rect: NSRect) {
        let side = rect.width
        let tileInset = side * (100.0 / 1024.0)
        let tileRect = rect.insetBy(dx: tileInset, dy: tileInset)
        let cornerRadius = side * (185.0 / 1024.0)

        let tile = NSBezierPath(roundedRect: tileRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSGradient(starting: tileTopColor, ending: tileBottomColor)?.draw(in: tile, angle: -90)

        let catSide = tileRect.width * 0.74
        let catRect = NSRect(
            x: tileRect.midX - catSide / 2,
            y: tileRect.midY - catSide / 2,
            width: catSide,
            height: catSide
        )
        catImage(size: catRect.size, color: .white, whiskers: true).draw(in: catRect)
    }

    /// The cat on its own, with the eyes and nose punched out of the alpha
    /// channel so whatever sits behind it shows through.
    private static func catImage(size: NSSize, color: NSColor, whiskers: Bool) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            let canvas = Canvas(rect: rect)
            color.setFill()
            color.setStroke()

            body(in: canvas).fill()
            if whiskers {
                let path = whiskerPath(in: canvas)
                path.lineWidth = canvas.length(2.6)
                path.lineCapStyle = .round
                path.stroke()
            }

            guard let context = NSGraphicsContext.current else { return true }
            context.compositingOperation = .destinationOut
            features(in: canvas).fill()
            context.compositingOperation = .sourceOver
            return true
        }
    }

    /// Rounded head plus two triangular ears, merged by the non-zero winding rule.
    /// Every subpath must wind counter-clockwise to match `appendOval`, otherwise
    /// the overlaps subtract instead of merging and punch holes in the silhouette.
    private static func body(in canvas: Canvas) -> NSBezierPath {
        let path = NSBezierPath()
        path.windingRule = .nonZero
        path.appendOval(in: canvas.box(x: 13, y: 6, width: 74, height: 68))

        path.move(to: canvas.point(20, 55))
        path.line(to: canvas.point(50, 72))
        path.line(to: canvas.point(24, 89))
        path.close()

        path.move(to: canvas.point(80, 55))
        path.line(to: canvas.point(76, 89))
        path.line(to: canvas.point(50, 72))
        path.close()
        return path
    }

    private static func features(in canvas: Canvas) -> NSBezierPath {
        let path = NSBezierPath()
        path.appendOval(in: canvas.box(x: 27, y: 35, width: 15, height: 17))
        path.appendOval(in: canvas.box(x: 58, y: 35, width: 15, height: 17))

        path.move(to: canvas.point(44, 30))
        path.line(to: canvas.point(56, 30))
        path.line(to: canvas.point(50, 21.5))
        path.close()
        return path
    }

    private static func whiskerPath(in canvas: Canvas) -> NSBezierPath {
        let path = NSBezierPath()
        let strands: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (33, 33, 3, 39),
            (32, 27, 1, 26),
            (34, 21, 5, 13)
        ]
        for (x1, y1, x2, y2) in strands {
            path.move(to: canvas.point(x1, y1))
            path.line(to: canvas.point(x2, y2))
            path.move(to: canvas.point(100 - x1, y1))
            path.line(to: canvas.point(100 - x2, y2))
        }
        return path
    }

    /// Maps the 100x100 design space onto the rect being drawn into.
    private struct Canvas {
        let rect: NSRect

        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + x / 100 * rect.width, y: rect.minY + y / 100 * rect.height)
        }

        func box(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
            NSRect(
                origin: point(x, y),
                size: NSSize(width: width / 100 * rect.width, height: height / 100 * rect.height)
            )
        }

        func length(_ value: CGFloat) -> CGFloat {
            value / 100 * rect.width
        }
    }
}
