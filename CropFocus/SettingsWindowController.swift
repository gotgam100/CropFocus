import AppKit
import ServiceManagement

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        super.init(window: window)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: Localization.didChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        rebuild()
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func languageChanged() {
        rebuild()
    }

    // MARK: - UI 재구성 (언어 전환 시 전체 다시 그림)

    private func rebuild() {
        guard let window, let contentView = window.contentView else { return }
        window.title = Localization.shared.settingsWindowTitle
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // 언어 선택
        let langRow = NSStackView()
        langRow.orientation = .horizontal
        langRow.spacing = 8
        langRow.addArrangedSubview(makeLabel(L(.language) + ":"))
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItem(withTitle: L(.languageKorean))
        popup.lastItem?.representedObject = AppLanguage.korean.rawValue
        popup.addItem(withTitle: L(.languageEnglish))
        popup.lastItem?.representedObject = AppLanguage.english.rawValue
        popup.selectItem(at: Localization.shared.language == .korean ? 0 : 1)
        popup.target = self
        popup.action = #selector(languageSelected(_:))
        langRow.addArrangedSubview(popup)
        root.addArrangedSubview(langRow)

        // 로그인 시 자동 실행
        let launchCheckbox = NSButton(checkboxWithTitle: L(.launchAtLogin), target: self, action: #selector(toggleLaunchAtLogin(_:)))
        configureLaunchCheckbox(launchCheckbox)
        root.addArrangedSubview(launchCheckbox)

        // 포커스 중 메뉴 막대 보기
        let statusBarCheckbox = NSButton(checkboxWithTitle: L(.showStatusBar), target: self, action: #selector(toggleShowStatusBar(_:)))
        statusBarCheckbox.state = FocusManager.shared.showStatusBar ? .on : .off
        root.addArrangedSubview(statusBarCheckbox)

        // 단축키 설명 버튼
        let shortcutsButton = NSButton(title: L(.shortcutsButton), target: self, action: #selector(showShortcutsHelp))
        shortcutsButton.bezelStyle = .rounded
        root.addArrangedSubview(shortcutsButton)

        root.addArrangedSubview(makeSeparator())

        // 화면 정보
        root.addArrangedSubview(makeLabel(L(.systemInfo), bold: true))
        let screenInfo = NSStackView()
        screenInfo.orientation = .vertical
        screenInfo.alignment = .leading
        screenInfo.spacing = 4
        for block in makeScreenInfoBlocks() {
            screenInfo.addArrangedSubview(block)
        }
        root.addArrangedSubview(screenInfo)

        // 내용 높이에 맞춰 창 크기 조정 (남는 세로 공간이 블록 사이를 벌리지 않도록)
        root.layoutSubtreeIfNeeded()
        let fitting = root.fittingSize
        window.setContentSize(NSSize(width: 440, height: fitting.height))
    }

    private func makeLabel(_ text: String, bold: Bool = false, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold
            ? NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            : NSFont.systemFont(ofSize: secondary ? NSFont.smallSystemFontSize : NSFont.systemFontSize)
        if secondary {
            label.textColor = .secondaryLabelColor
        }
        return label
    }

    private func makeSeparator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 400).isActive = true
        return box
    }

    private func configureLaunchCheckbox(_ checkbox: NSButton) {
        if #available(macOS 13.0, *) {
            checkbox.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            checkbox.isEnabled = true
        } else {
            checkbox.isEnabled = false
            checkbox.toolTip = L(.macos13Tooltip)
        }
    }

    private func makeScreenInfoBlocks() -> [NSView] {
        let screens = NSScreen.screens
        let showNumber = screens.count >= 2
        return screens.enumerated().map { index, screen in
            let scale = screen.backingScaleFactor
            let ptW = Int(screen.frame.width)
            let ptH = Int(screen.frame.height)
            let baseName = screen.localizedName.isEmpty ? "\(L(.displayFallback)) \(index + 1)" : screen.localizedName
            let name = showNumber ? "\(index + 1). \(baseName)" : baseName

            let block = NSStackView()
            block.orientation = .vertical
            block.alignment = .leading
            block.spacing = 2
            block.addArrangedSubview(makeLabel("• \(name)"))
            // 논리(데스크탑) 해상도를 메인으로, 배율은 작게 병기
            block.addArrangedSubview(makeLabel("    \(ptW) × \(ptH)  ·  \(scaleString(scale))x", secondary: true))
            return block
        }
    }

    private func scaleString(_ scale: CGFloat) -> String {
        scale == scale.rounded() ? "\(Int(scale))" : String(format: "%.1f", scale)
    }

    // MARK: - 액션

    @objc private func languageSelected(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let lang = AppLanguage(rawValue: raw) else { return }
        Localization.shared.setLanguage(lang)  // → didChangeNotification → rebuild()
    }

    @objc private func toggleShowStatusBar(_ sender: NSButton) {
        FocusManager.shared.showStatusBar = (sender.state == .on)
    }

    @objc private func showShortcutsHelp() {
        let drag = L(.dragWord)
        let rows: [(combo: String, desc: String)] = [
            (FocusManager.selectHotKey.display, L(.shortcutSelect)),
            (FocusManager.clearHotKey.display,  L(.shortcutClear)),
            ("Esc",                             L(.shortcutEsc)),
            ("⌘ + \(drag)",                     L(.shortcutReplace)),
            ("⌘⌥ + \(drag)",                    L(.shortcutAdd))
        ]
        let body = rows.map { "\($0.combo)  —  \($0.desc)" }.joined(separator: "\n")

        let alert = NSAlert()
        alert.messageText = L(.shortcutsTitle)
        alert.addButton(withTitle: L(.okWord))

        // 기본 알림 폭에서는 영어 설명이 줄바꿈되므로, 줄바꿈 없는 라벨을
        // accessoryView로 넣어 내용 너비에 맞게 알림 폭을 넓힌다.
        let label = NSTextField(labelWithString: body)
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        label.lineBreakMode = .byClipping
        label.frame = NSRect(origin: .zero, size: label.fittingSize)
        alert.accessoryView = label

        if let window { alert.beginSheetModal(for: window, completionHandler: nil) }
        else { alert.runModal() }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if sender.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            configureLaunchCheckbox(sender)
            let alert = NSAlert()
            alert.messageText = L(.launchFailTitle)
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
