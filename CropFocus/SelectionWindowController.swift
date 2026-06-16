import AppKit

// 키보드 이벤트를 받기 위해 canBecomeKey를 오버라이드
final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SelectionWindowController {
    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var windows: [NSWindow] = []
    private var selectionViews: [SelectionView] = []
    private var activeScreen: NSScreen?

    func startSelection() {
        // 마우스 커서가 있는 화면 찾기
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        activeScreen = targetScreen

        // 모든 화면에 선택 오버레이 생성 (커서가 있는 화면만 선택 가능)
        for screen in NSScreen.screens {
            let isActive = screen == targetScreen
            let window = makeSelectionWindow(for: screen, isActive: isActive)
            windows.append(window)
        }

        // 메뉴 클릭/전역 단축키 직후 앱이 비활성 상태일 수 있으므로 활성화한다.
        NSApp.activate(ignoringOtherApps: true)

        // 활성 화면의 창을 최전면으로
        if let activeWindow = windows.first(where: { $0.screen == targetScreen }) {
            activeWindow.makeKeyAndOrderFront(nil)
        }

        // 마우스를 움직이지 않아도 즉시 십자 커서가 보이도록 설정
        NSCursor.crosshair.set()
    }

    private func makeSelectionWindow(for screen: NSScreen, isActive: Bool) -> NSWindow {
        let window = SelectionWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        // screen: 파라미터를 넘기면 음수/오프셋 원점이 backingScaleFactor만큼
        // 잘못 보정되므로, 생성 후 setFrame으로 정확한 위치를 지정한다.
        window.setFrame(screen.frame, display: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = !isActive

        let view = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.isInteractive = isActive

        if isActive {
            view.onSelectionComplete = { [weak self] localRect in
                guard let self, let screen = self.activeScreen else { return }
                // 뷰 로컬 좌표 → 화면(스크린) 좌표로 변환
                let screenRect = CGRect(
                    x: localRect.origin.x + screen.frame.origin.x,
                    y: localRect.origin.y + screen.frame.origin.y,
                    width: localRect.width,
                    height: localRect.height
                )
                self.finish()
                self.onSelectionComplete?(screenRect)
            }
            view.onCancelled = { [weak self] in
                self?.finish()
                self?.onCancelled?()
            }
        }

        window.contentView = view
        window.orderFront(nil)
        selectionViews.append(view)

        if isActive {
            window.makeFirstResponder(view)
        }

        return window
    }

    private func finish() {
        NSCursor.arrow.set()
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        selectionViews.removeAll()
    }
}
