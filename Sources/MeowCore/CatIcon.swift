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

    /// What the app is doing. The cat's own ears and eyes change to show this,
    /// rather than a separate indicator being placed next to it.
    public enum State: Equatable {
        case idle
        case listening
        /// `phase` cycles the ear twitch so transcribing reads as active work.
        case thinking(phase: Int)
        case paused
        case attention
    }

    /// Monochrome cat for `NSStatusItem`. Marked as a template so macOS tints it
    /// white in dark mode and black in light mode automatically.
    public static func menuBarImage(state: State = .idle, pointSize: CGFloat = 18) -> NSImage {
        let cat = catImage(
            size: NSSize(width: pointSize, height: pointSize),
            color: .black,
            whiskers: false,
            expression: Expression(for: state)
        )

        // Needing permission is not a mood, so it keeps an unambiguous mark.
        guard state == .attention else {
            cat.isTemplate = true
            return cat
        }

        let unit = pointSize / 18
        let gap = 3.5 * unit
        let markWidth = 2.4 * unit

        let image = NSImage(
            size: NSSize(width: pointSize + gap + markWidth, height: pointSize),
            flipped: false
        ) { rect in
            cat.draw(in: NSRect(x: rect.minX, y: rect.minY, width: pointSize, height: pointSize))
            NSColor.black.setFill()
            drawAttentionMark(
                originX: rect.minX + pointSize + gap,
                centerY: rect.midY,
                unit: unit
            )
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawAttentionMark(originX: CGFloat, centerY: CGFloat, unit: CGFloat) {
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

    /// The only parts of the drawing a state may change: how far the head sits
    /// down the canvas, where each ear tip points, and the shape of the eyes.
    /// Everything else stays put so the cat still reads as the same cat.
    private struct Expression {
        /// Design units the head, eyes and nose slide down by. Dropping the head
        /// is what buys room for genuinely tall ears; the ears alone can only
        /// grow by the 11 units the neutral pose leaves above them.
        var headDrop: CGFloat
        var leftEarTip: (x: CGFloat, y: CGFloat)
        var rightEarTip: (x: CGFloat, y: CGFloat)
        /// Left eye box in design space; the right eye is mirrored from it.
        var eye: (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
        var eyesClosed: Bool

        static let neutral = Expression(
            headDrop: 0,
            leftEarTip: (24, 89),
            rightEarTip: (76, 89),
            eye: (27, 35, 15, 17),
            eyesClosed: false
        )

        /// Alert: head tucked down, ears at full stretch, eyes wide.
        static let listening = Expression(
            headDrop: 4,
            leftEarTip: (25, 100),
            rightEarTip: (75, 100),
            eye: (25, 33, 19, 21),
            eyesClosed: false
        )

        /// Eyes shut in concentration, ears swivelling through three frames.
        static func thinking(phase: Int) -> Expression {
            let tips: [((CGFloat, CGFloat), (CGFloat, CGFloat))] = [
                ((24, 89), (76, 89)),
                ((20, 93), (77, 85)),
                ((27, 85), (80, 93))
            ]
            let index = ((phase % tips.count) + tips.count) % tips.count
            return Expression(
                headDrop: 0,
                leftEarTip: tips[index].0,
                rightEarTip: tips[index].1,
                eye: (27, 42, 15, 3.6),
                eyesClosed: true
            )
        }

        /// Asleep: ears folded out to the sides, eyes shut.
        static let sleeping = Expression(
            headDrop: 0,
            leftEarTip: (14, 77),
            rightEarTip: (86, 77),
            eye: (27, 42, 15, 3.6),
            eyesClosed: true
        )

        init(for state: State) {
            switch state {
            case .idle, .attention: self = .neutral
            case .listening: self = .listening
            case .thinking(let phase): self = .thinking(phase: phase)
            case .paused: self = .sleeping
            }
        }

        private init(
            headDrop: CGFloat,
            leftEarTip: (x: CGFloat, y: CGFloat),
            rightEarTip: (x: CGFloat, y: CGFloat),
            eye: (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat),
            eyesClosed: Bool
        ) {
            self.headDrop = headDrop
            self.leftEarTip = leftEarTip
            self.rightEarTip = rightEarTip
            self.eye = eye
            self.eyesClosed = eyesClosed
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
        catImage(size: catRect.size, color: .white, whiskers: true, expression: Expression(for: .idle))
            .draw(in: catRect)
    }

    /// The cat on its own, with the eyes and nose punched out of the alpha
    /// channel so whatever sits behind it shows through.
    private static func catImage(
        size: NSSize,
        color: NSColor,
        whiskers: Bool,
        expression: Expression
    ) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            let canvas = Canvas(rect: rect)
            color.setFill()
            color.setStroke()

            body(in: canvas, expression: expression).fill()
            if whiskers {
                let path = whiskerPath(in: canvas)
                path.lineWidth = canvas.length(2.6)
                path.lineCapStyle = .round
                path.stroke()
            }

            guard let context = NSGraphicsContext.current else { return true }
            context.compositingOperation = .destinationOut
            features(in: canvas, expression: expression).fill()
            context.compositingOperation = .sourceOver
            return true
        }
    }

    /// Rounded head plus two triangular ears, merged by the non-zero winding rule.
    /// Every subpath must wind counter-clockwise to match `appendOval`, otherwise
    /// the overlaps subtract instead of merging and punch holes in the silhouette.
    /// Only the tips move between expressions; the bases stay anchored inside the
    /// head so the ears never detach.
    private static func body(in canvas: Canvas, expression: Expression) -> NSBezierPath {
        let drop = expression.headDrop
        let path = NSBezierPath()
        path.windingRule = .nonZero
        path.appendOval(in: canvas.box(x: 13, y: 6 - drop, width: 74, height: 68))

        path.move(to: canvas.point(20, 55 - drop))
        path.line(to: canvas.point(50, 72 - drop))
        path.line(to: canvas.point(expression.leftEarTip.x, expression.leftEarTip.y))
        path.close()

        path.move(to: canvas.point(80, 55 - drop))
        path.line(to: canvas.point(expression.rightEarTip.x, expression.rightEarTip.y))
        path.line(to: canvas.point(50, 72 - drop))
        path.close()
        return path
    }

    private static func features(in canvas: Canvas, expression: Expression) -> NSBezierPath {
        let drop = expression.headDrop
        let path = NSBezierPath()
        let eye = expression.eye
        let mirroredX = 100 - eye.x - eye.width

        for x in [eye.x, mirroredX] {
            let box = canvas.box(x: x, y: eye.y - drop, width: eye.width, height: eye.height)
            if expression.eyesClosed {
                let radius = box.height / 2
                path.appendRoundedRect(box, xRadius: radius, yRadius: radius)
            } else {
                path.appendOval(in: box)
            }
        }

        path.move(to: canvas.point(44, 30 - drop))
        path.line(to: canvas.point(56, 30 - drop))
        path.line(to: canvas.point(50, 21.5 - drop))
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
