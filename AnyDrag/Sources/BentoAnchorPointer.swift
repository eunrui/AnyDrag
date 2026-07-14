import AppKit

enum BentoPointerEdge {
    case left, right, top, bottom
}

/// A mouse-transparent popover tip connecting a displaced bento panel to the
/// original middle-button press point. The panel is separate so the existing
/// bento content and hit-test coordinate system remain unchanged.
final class BentoAnchorPointer: NSPanel {

    static let depth: CGFloat = 10
    private static let base: CGFloat = 18
    private static let cornerClearance: CGFloat = 24
    private static let panelOverlap: CGFloat = 1

    private let pointerView = BentoAnchorPointerView()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        animationBehavior = .none
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        contentView = pointerView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(attachedTo panelFrame: NSRect, edge: BentoPointerEdge, pointingAt point: NSPoint) {
        let frame: NSRect
        switch edge {
        case .left, .right:
            guard panelFrame.height >= Self.cornerClearance * 2 + Self.base else {
                hide()
                return
            }
            let centerY = max(
                panelFrame.minY + Self.cornerClearance + Self.base / 2,
                min(point.y, panelFrame.maxY - Self.cornerClearance - Self.base / 2)
            )
            let x = edge == .left
                ? panelFrame.minX - Self.depth + Self.panelOverlap
                : panelFrame.maxX - Self.panelOverlap
            frame = NSRect(x: x, y: centerY - Self.base / 2,
                           width: Self.depth, height: Self.base)

        case .top, .bottom:
            guard panelFrame.width >= Self.cornerClearance * 2 + Self.base else {
                hide()
                return
            }
            let centerX = max(
                panelFrame.minX + Self.cornerClearance + Self.base / 2,
                min(point.x, panelFrame.maxX - Self.cornerClearance - Self.base / 2)
            )
            let y = edge == .bottom
                ? panelFrame.minY - Self.depth + Self.panelOverlap
                : panelFrame.maxY - Self.panelOverlap
            frame = NSRect(x: centerX - Self.base / 2, y: y,
                           width: Self.base, height: Self.depth)
        }

        pointerView.edge = edge
        setFrame(frame, display: true)
        if !isVisible {
            orderFrontRegardless()
        }
    }

    func hide() {
        if isVisible {
            orderOut(nil)
        }
    }
}

private final class BentoAnchorPointerView: NSVisualEffectView {

    private let maskLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()

    var edge: BentoPointerEdge = .right {
        didSet { needsLayout = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.mask = maskLayer
        layer?.addSublayer(borderLayer)
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.lineWidth = 1
        updateBorderColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let path = trianglePath(in: bounds, edge: edge)
        maskLayer.frame = bounds
        maskLayer.path = path
        borderLayer.frame = bounds
        borderLayer.path = outlinePath(in: bounds, edge: edge)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorderColor()
    }

    private func updateBorderColor() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        borderLayer.strokeColor = (isDark
            ? NSColor.white.withAlphaComponent(0.18)
            : NSColor.black.withAlphaComponent(0.12)).cgColor
    }

    private func trianglePath(in rect: NSRect, edge: BentoPointerEdge) -> CGPath {
        let path = CGMutablePath()
        switch edge {
        case .left:
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .right:
            path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .top:
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        case .bottom:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }

    /// Stroke only the two exposed sides. Drawing the base would leave a
    /// hairline between the pointer and the panel it visually belongs to.
    private func outlinePath(in rect: NSRect, edge: BentoPointerEdge) -> CGPath {
        let path = CGMutablePath()
        switch edge {
        case .left:
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .right:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .top:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .bottom:
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        return path
    }
}
