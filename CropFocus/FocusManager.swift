import AppKit
import Carbon.HIToolbox

final class FocusManager {
    static let shared = FocusManager()
    static let stateChangedNotification = Notification.Name("FocusManagerStateChanged")

    // 전역 단축키 (잘 쓰이지 않는 ⌃⌥⌘ 조합)
    static let selectHotKey = (keyCode: kVK_ANSI_F, display: "⌃⌥⌘F")  // 영역 선택 시작
    static let clearHotKey  = (keyCode: kVK_ANSI_C, display: "⌃⌥⌘C")  // 마스킹 해제

    private static let maskOpacityKey = "MaskOpacity"

    /// 마스크 어둡기. 변경 시 UserDefaults에 저장되어 재시작 후에도 유지된다.
    var maskOpacity: Double = {
        // 저장된 값이 있으면 사용, 없으면 기본 0.75
        if UserDefaults.standard.object(forKey: FocusManager.maskOpacityKey) != nil {
            return UserDefaults.standard.double(forKey: FocusManager.maskOpacityKey)
        }
        return 0.75
    }() {
        didSet {
            UserDefaults.standard.set(maskOpacity, forKey: FocusManager.maskOpacityKey)
            maskWindowController?.updateOpacity(maskOpacity)
        }
    }

    private static let showStatusBarKey = "ShowStatusBarWhileFocusing"

    /// 포커스(마스킹) 중에도 macOS 메뉴 막대를 가리지 않고 보이게 할지 여부.
    var showStatusBar: Bool = UserDefaults.standard.bool(forKey: FocusManager.showStatusBarKey) {
        didSet {
            UserDefaults.standard.set(showStatusBar, forKey: FocusManager.showStatusBarKey)
            maskWindowController?.updateStatusBarVisibility(showStatusBar)
        }
    }

    private(set) var isMaskActive: Bool = false {
        didSet {
            NotificationCenter.default.post(name: FocusManager.stateChangedNotification, object: nil)
        }
    }

    private var selectionWindowController: SelectionWindowController?
    private var maskWindowController: MaskWindowController?
    private var escHotKeyID: UInt32?
    private var selectionRects: [CGRect] = []   // 화면 좌표 기준 선택 영역들
    private var modifierTimer: Timer?

    private init() {
        // 전역 단축키 등록 (앱이 포커스 없어도 동작)
        let mods = HotKeyCenter.Modifiers.commandOptionControl
        HotKeyCenter.shared.register(keyCode: FocusManager.selectHotKey.keyCode, modifiers: mods) { [weak self] in
            self?.startSelection()
        }
        HotKeyCenter.shared.register(keyCode: FocusManager.clearHotKey.keyCode, modifiers: mods) { [weak self] in
            self?.clearMask()
        }
    }

    func startSelection() {
        // 이미 선택 모드면 중복 실행 방지
        guard selectionWindowController == nil else { return }
        clearMask()
        selectionWindowController = SelectionWindowController()

        selectionWindowController?.onSelectionComplete = { [weak self] screenRect in
            guard let self else { return }
            self.selectionWindowController = nil
            self.applyMask(to: screenRect)
        }

        selectionWindowController?.onCancelled = { [weak self] in
            self?.selectionWindowController = nil
        }

        selectionWindowController?.startSelection()
    }

    func clearMask() {
        maskWindowController?.close()
        maskWindowController = nil
        selectionRects = []
        stopModifierWatch()
        if let escHotKeyID {
            HotKeyCenter.shared.unregister(escHotKeyID)
            self.escHotKeyID = nil
        }
        isMaskActive = false
    }

    private func applyMask(to screenRect: CGRect) {
        guard screenRect.width > 10, screenRect.height > 10 else { return }
        selectionRects = [screenRect]
        let controller = MaskWindowController(selectionRectsInScreenCoords: selectionRects, opacity: maskOpacity, showStatusBar: showStatusBar)
        controller.onGesture = { [weak self] rect, mode in
            self?.handleGesture(rect, mode: mode)
        }
        maskWindowController = controller
        controller.showMask()

        // 마스킹 중에만 Esc로 해제 (전역 Esc는 다른 앱에 영향 주므로 마스킹 동안만 점유)
        escHotKeyID = HotKeyCenter.shared.register(keyCode: kVK_Escape, modifiers: 0) { [weak self] in
            self?.clearMask()
        }
        startModifierWatch()
        isMaskActive = true
    }

    /// ⌘ 드래그(교체) / ⌘⌥ 드래그(추가) 처리
    private func handleGesture(_ rect: CGRect, mode: MaskGestureMode) {
        guard rect.width > 10, rect.height > 10 else { return }
        switch mode {
        case .replace: selectionRects = [rect]
        case .add:     selectionRects.append(rect)
        }
        maskWindowController?.updateSelectionRects(selectionRects)
        // 영역이 바뀌었으니 현재 커서/수정자 기준으로 재판정
        let flags = NSEvent.modifierFlags
        maskWindowController?.updateInteraction(
            commandHeld: flags.contains(.command),
            optionHeld: flags.contains(.option),
            at: NSEvent.mouseLocation
        )
    }

    // MARK: - 수정자/커서 감시 (타이머 폴링, 접근성 권한 불필요)
    // NSEvent.modifierFlags로 ⌘ 눌림을 클릭 전에 즉시 감지해 십자 커서/잡기 상태를 갱신한다.

    private func startModifierWatch() {
        guard modifierTimer == nil else { return }
        let timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self, self.isMaskActive, let controller = self.maskWindowController else { return }
            let flags = NSEvent.modifierFlags
            controller.updateInteraction(
                commandHeld: flags.contains(.command),
                optionHeld: flags.contains(.option),
                at: NSEvent.mouseLocation
            )
        }
        // 메뉴 트래킹 등 다른 런루프 모드에서도 동작하도록
        RunLoop.main.add(timer, forMode: .common)
        modifierTimer = timer
    }

    private func stopModifierWatch() {
        modifierTimer?.invalidate()
        modifierTimer = nil
    }
}
