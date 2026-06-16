import AppKit

final class SelectionView: NSView {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?
    var isInteractive: Bool = true

    private var startPoint: CGPoint?
    private var currentRect: CGRect?

    override var acceptsFirstResponder: Bool { isInteractive }

    // MARK: - Cursor

    private var trackingArea: NSTrackingArea?

    override func resetCursorRects() {
        if isInteractive {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        guard isInteractive else { return }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        if isInteractive { NSCursor.crosshair.set() }
    }

    override func mouseEntered(with event: NSEvent) {
        if isInteractive { NSCursor.crosshair.set() }
    }

    override func mouseMoved(with event: NSEvent) {
        if isInteractive { NSCursor.crosshair.set() }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // even-odd로 선택 영역만 투명 구멍을 낸 오버레이
        let path = CGMutablePath()
        path.addRect(bounds)
        if let rect = currentRect, isInteractive {
            path.addRect(rect)
        }

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.addPath(path)
        ctx.fillPath(using: .evenOdd)

        // 선택 중일 때 테두리 표시
        if let rect = currentRect, isInteractive {
            ctx.saveGState()
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineDash(phase: 0, lengths: [8, 4])
            ctx.addRect(rect)
            ctx.strokePath()

            // 크기 레이블
            let label = "\(Int(rect.width)) × \(Int(rect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let attrStr = NSAttributedString(string: label, attributes: attrs)
            let labelSize = attrStr.size()
            var labelOrigin = CGPoint(x: rect.midX - labelSize.width / 2, y: rect.maxY + 6)
            // 화면 상단을 벗어나면 아래에 표시
            if labelOrigin.y + labelSize.height > bounds.maxY - 4 {
                labelOrigin.y = rect.minY - labelSize.height - 6
            }
            // 배경 박스
            let padding: CGFloat = 4
            let bgRect = CGRect(
                x: labelOrigin.x - padding,
                y: labelOrigin.y - padding,
                width: labelSize.width + padding * 2,
                height: labelSize.height + padding * 2
            )
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
            ctx.fill(bgRect)
            ctx.restoreGState()

            attrStr.draw(at: labelOrigin)
        }

        // 비활성 오버레이 (비활성 화면은 더 어둡게)
        if !isInteractive {
            NSColor.black.withAlphaComponent(0.6).setFill()
            bounds.fill()
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        guard isInteractive else { return }
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isInteractive, let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isInteractive else { return }
        if let rect = currentRect, rect.width > 10, rect.height > 10 {
            onSelectionComplete?(rect)
        } else {
            onCancelled?()
        }
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancelled?()
        }
    }
}
