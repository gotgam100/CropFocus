import AppKit

enum MaskGestureMode {
    case replace  // ⌘ + 드래그: 선택 영역 교체
    case add      // ⌘⌥ + 드래그: 선택 영역 추가
}

final class MaskView: NSView {
    /// 이 화면의 로컬 좌표 기준 선택(투명) 영역들
    var selectionRects: [CGRect] = [] {
        didSet { refreshMask() }
    }

    var maskOpacity: Double = 0.75 {
        didSet { refreshMask() }
    }

    /// 마스크가 마우스를 잡는 상태(어두운 영역 위 또는 ⌘ 눌림). 구멍 위 평소엔 false로 클릭 통과.
    var interactive: Bool = false

    /// ⌘ 눌림 → 십자 커서 표시 (재선택 모드 신호)
    var showCrosshair: Bool = false {
        didSet {
            guard showCrosshair != oldValue else { return }
            window?.invalidateCursorRects(for: self)
            (showCrosshair ? NSCursor.crosshair : NSCursor.arrow).set()
        }
    }

    /// 드래그 완료 시 (로컬 좌표 rect, 모드) 전달
    var onGesture: ((CGRect, MaskGestureMode) -> Void)?

    private(set) var isDragging = false

    private var dragStart: CGPoint?
    private var dragRect: CGRect?
    private var dragMode: MaskGestureMode = .replace
    private var trackingArea: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { interactive }

    override func layout() {
        super.layout()
        refreshMask()
    }

    // MARK: - Mask Rendering

    private func currentHoles() -> [CGRect] {
        var rects = selectionRects
        if isDragging, let dragRect {
            switch dragMode {
            case .replace: rects = [dragRect]
            case .add:     rects.append(dragRect)
            }
        }
        return rects
    }

    private func refreshMask() {
        needsDisplay = true
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 전체를 어둡게 채운다. (.copy로 픽셀을 그대로 덮어써 이전 프레임의 반투명
        //  값이 누적되지 않게 한다)
        ctx.setBlendMode(.copy)
        ctx.setFillColor(NSColor.black.withAlphaComponent(maskOpacity).cgColor)
        ctx.fill(bounds)

        // 선택 영역마다 clear 블렌드로 지워 구멍을 낸다.
        // 겹치는 영역도 모두 "지우기"라서 합집합으로 처리되어 검게 남지 않는다.
        ctx.setBlendMode(.clear)
        for rect in currentHoles() {
            let clipped = rect.intersection(bounds)
            if !clipped.isNull, clipped.width > 1, clipped.height > 1 {
                ctx.fill(clipped)
            }
        }
        ctx.setBlendMode(.normal)
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        if showCrosshair {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        if showCrosshair { NSCursor.crosshair.set() }
    }

    // MARK: - Drag Gesture

    override func mouseDown(with event: NSEvent) {
        guard interactive else { return }
        let flags = event.modifierFlags
        if flags.contains(.command) && flags.contains(.option) {
            dragMode = .add
        } else if flags.contains(.command) {
            dragMode = .replace
        } else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        dragStart = convert(event.locationInWindow, from: nil)
        dragRect = nil
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard interactive, isDragging, let start = dragStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        dragRect = CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        refreshMask()
    }

    override func mouseUp(with event: NSEvent) {
        guard interactive, isDragging else { return }
        isDragging = false
        let finished = dragRect
        let mode = dragMode
        dragStart = nil
        dragRect = nil
        refreshMask()
        if let finished, finished.width > 10, finished.height > 10 {
            onGesture?(finished, mode)
        }
    }
}
