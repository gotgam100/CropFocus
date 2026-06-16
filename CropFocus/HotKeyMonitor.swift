import AppKit
import Carbon.HIToolbox

/// 앱이 포커스를 갖지 않는 메뉴바 앱에서도 동작하는 전역 단축키 센터.
/// Carbon RegisterEventHotKey를 사용하므로 손쉬운 사용(Accessibility) 권한이 필요 없다.
/// 여러 개의 핫키를 등록할 수 있으며, 단 하나의 이벤트 핸들러만 설치해 id로 분기한다.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    // Carbon 수정자(modifier) 마스크 헬퍼
    struct Modifiers {
        static let commandOptionControl =
            UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)
        static let commandOption =
            UInt32(cmdKey) | UInt32(optionKey)
    }

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    private init() {}

    /// 핫키 등록. 반환된 id로 나중에 해제한다.
    @discardableResult
    func register(keyCode: Int, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32 {
        installHandlerIfNeeded()

        let id = nextID
        nextID += 1
        handlers[id] = handler

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x46435553) /* 'FCUS' */, id: id)
        RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if let ref {
            refs[id] = ref
        }
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs[id] {
            UnregisterEventHotKey(ref)
            refs[id] = nil
        }
        handlers[id] = nil
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                HotKeyCenter.shared.handlers[hotKeyID.id]?()
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }
}
