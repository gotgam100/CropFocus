import AppKit

final class MaskWindowController {
    private struct Entry {
        let window: NSWindow
        let view: MaskView
        let screen: NSScreen
    }

    private var entries: [Entry] = []
    private var selectionRectsInScreenCoords: [CGRect]
    private var opacity: Double
    private var showStatusBar: Bool

    /// 드래그 제스처 완료 시 (화면 좌표 rect, 모드) 전달
    var onGesture: ((CGRect, MaskGestureMode) -> Void)?

    /// 현재 어느 화면에서든 드래그 진행 중인지
    var isDragging: Bool {
        entries.contains { $0.view.isDragging }
    }

    init(selectionRectsInScreenCoords: [CGRect], opacity: Double, showStatusBar: Bool) {
        self.selectionRectsInScreenCoords = selectionRectsInScreenCoords
        self.opacity = opacity
        self.showStatusBar = showStatusBar
    }

    /// 마스크가 실제로 덮을 프레임. 메뉴 막대 보기 모드면 상단 메뉴 막대 높이만큼 제외한다.
    private func maskFrame(for screen: NSScreen) -> CGRect {
        var frame = screen.frame
        if showStatusBar {
            // visibleFrame.maxY는 메뉴 막대 아래 지점 → 차이가 그 화면의 메뉴 막대 높이.
            // (Dock은 좌/우/하단에만 영향을 주므로 상단 높이에는 반영되지 않음)
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            if menuBarHeight > 0 {
                frame.size.height -= menuBarHeight  // 원점(하단) 고정, 상단만 낮춤
            }
        }
        return frame
    }

    func showMask() {
        for screen in NSScreen.screens {
            let entry = makeMaskEntry(for: screen)
            entries.append(entry)
            entry.window.orderFront(nil)
        }
        // 초기 상태: 현재 커서 위치/수정자 기준으로 판정
        let flags = NSEvent.modifierFlags
        updateInteraction(commandHeld: flags.contains(.command), optionHeld: flags.contains(.option), at: NSEvent.mouseLocation)
    }

    private func makeMaskEntry(for screen: NSScreen) -> Entry {
        let frame = maskFrame(for: screen)
        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        // screen: 파라미터를 넘기면 음수/오프셋 원점이 backingScaleFactor만큼
        // 잘못 보정되므로, 생성 후 setFrame으로 정확한 위치를 지정한다.
        window.setFrame(frame, display: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = true  // 초기엔 통과 (updateCapture가 재판정)

        let maskView = MaskView(frame: NSRect(origin: .zero, size: frame.size))
        maskView.selectionRects = localRects(for: screen)
        maskView.maskOpacity = opacity
        maskView.onGesture = { [weak self] localRect, mode in
            guard let self else { return }
            // 뷰 로컬 좌표 → 화면 좌표
            let screenRect = CGRect(
                x: localRect.origin.x + screen.frame.origin.x,
                y: localRect.origin.y + screen.frame.origin.y,
                width: localRect.width,
                height: localRect.height
            )
            self.onGesture?(screenRect, mode)
        }
        window.contentView = maskView
        return Entry(window: window, view: maskView, screen: screen)
    }

    private func localRects(for screen: NSScreen) -> [CGRect] {
        selectionRectsInScreenCoords.map { rect in
            CGRect(
                x: rect.origin.x - screen.frame.origin.x,
                y: rect.origin.y - screen.frame.origin.y,
                width: rect.width,
                height: rect.height
            )
        }
    }

    /// 선택 영역 갱신 (모든 화면 동기화)
    func updateSelectionRects(_ screenRects: [CGRect]) {
        selectionRectsInScreenCoords = screenRects
        for entry in entries {
            entry.view.selectionRects = localRects(for: entry.screen)
        }
        lastState = nil  // 다음 틱에 잡기/통과 재판정
    }

    private var lastState: (capture: Bool, cmd: Bool, screen: NSScreen)?

    /// ⌘/⌥ 눌림 상태로 마우스 잡기/통과 및 커서 모양을 판정한다.
    /// - 수정자 없음: 어디서든 클릭 통과(어두운 영역의 딤된 콘텐츠도 클릭/스크롤 가능)
    /// - ⌘ 또는 ⌥ 눌림: 어디서든 마스크가 잡음(재선택 제스처 + Option 누수 차단)
    ///   ⌘일 때는 십자 커서 표시(재선택 모드)
    func updateInteraction(commandHeld: Bool, optionHeld: Bool, at point: CGPoint) {
        if isDragging { return }
        guard let target = entries.first(where: { $0.screen.frame.contains(point) }) else { return }

        let capture = commandHeld || optionHeld
        if let last = lastState, last.capture == capture, last.cmd == commandHeld, last.screen == target.screen {
            return
        }
        lastState = (capture, commandHeld, target.screen)

        for entry in entries {
            if entry.screen == target.screen {
                entry.window.ignoresMouseEvents = !capture
                entry.view.interactive = capture
                entry.view.showCrosshair = commandHeld
            } else {
                entry.window.ignoresMouseEvents = true
                entry.view.interactive = false
                entry.view.showCrosshair = false
            }
        }
    }

    func updateOpacity(_ opacity: Double) {
        self.opacity = opacity
        for entry in entries {
            entry.view.maskOpacity = opacity
        }
    }

    /// 메뉴 막대 보기 모드를 켜고 끌 때 각 마스크 창의 프레임을 즉시 다시 맞춘다.
    func updateStatusBarVisibility(_ show: Bool) {
        guard show != showStatusBar else { return }
        showStatusBar = show
        for entry in entries {
            let frame = maskFrame(for: entry.screen)
            entry.window.setFrame(frame, display: true)
            entry.view.frame = NSRect(origin: .zero, size: frame.size)
        }
    }

    func close() {
        for entry in entries {
            entry.window.orderOut(nil)
        }
        entries.removeAll()
        lastState = nil
    }
}
