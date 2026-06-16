import AppKit

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let focusManager = FocusManager.shared

    override init() {
        super.init()
        setupStatusItem()
        observeFocusManager()
        observeLanguage()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.on.rectangle.dashed", accessibilityDescription: L(.appName))
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        // 실제 트리거는 전역 단축키(HotKeyCenter)이므로, 메뉴에는 표시만 한다.
        let selectItem = NSMenuItem(title: L(.menuStartSelection), action: #selector(startSelection), keyEquivalent: "f")
        selectItem.keyEquivalentModifierMask = [.control, .option, .command]
        selectItem.target = self
        setSymbol("rectangle.dashed", on: selectItem)
        menu.addItem(selectItem)

        let clearItem = NSMenuItem(title: L(.menuClearMask), action: #selector(clearMask), keyEquivalent: "c")
        clearItem.keyEquivalentModifierMask = [.control, .option, .command]
        clearItem.target = self
        setSymbol("xmark.circle", on: clearItem)
        menu.addItem(clearItem)

        menu.addItem(.separator())

        // 어둡기 서브메뉴
        let opacityParent = NSMenuItem(title: L(.menuDarkness), action: nil, keyEquivalent: "")
        setSymbol("circle.lefthalf.filled", on: opacityParent)
        let opacityMenu = NSMenu()
        for (label, value): (String, Double) in [("25%", 0.25), ("50%", 0.50), ("75%", 0.75), ("90%", 0.90), ("95%", 0.95), ("100%", 1.0)] {
            let item = NSMenuItem(title: label, action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.representedObject = value
            item.target = self
            if abs(value - focusManager.maskOpacity) < 0.01 {
                item.state = .on
            }
            opacityMenu.addItem(item)
        }
        opacityParent.submenu = opacityMenu
        menu.addItem(opacityParent)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: L(.menuSettings), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        setSymbol("gearshape", on: settingsItem)
        menu.addItem(settingsItem)

        let appInfoItem = NSMenuItem(title: L(.menuAppInfo), action: #selector(openAppInfo), keyEquivalent: "")
        appInfoItem.target = self
        setSymbol("info.circle", on: appInfoItem)
        menu.addItem(appInfoItem)

        let quitItem = NSMenuItem(title: L(.menuQuit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        setSymbol("power", on: quitItem)
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// 메뉴 항목 앞에 SF Symbol 아이콘을 붙인다. (템플릿 이미지라 다크/라이트 자동 대응)
    private func setSymbol(_ name: String, on item: NSMenuItem) {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: item.title)
        image?.isTemplate = true
        item.image = image
    }

    private func observeFocusManager() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(focusStateChanged),
            name: FocusManager.stateChangedNotification,
            object: nil)
    }

    private func observeLanguage() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(languageChanged),
            name: Localization.didChangeNotification,
            object: nil)
    }

    @objc private func languageChanged() {
        buildMenu()
    }

    @objc private func focusStateChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateIcon()
        }
    }

    private func updateIcon() {
        let symbolName = focusManager.isMaskActive
            ? "rectangle.fill.on.rectangle.fill"
            : "rectangle.on.rectangle.dashed"
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: L(.appName))
        statusItem.button?.image?.isTemplate = true
    }

    @objc private func startSelection() {
        focusManager.startSelection()
    }

    @objc private func clearMask() {
        focusManager.clearMask()
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        focusManager.maskOpacity = value
        // 체크마크 업데이트
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openAppInfo() {
        AppInfoWindowController.shared.show()
    }
}
