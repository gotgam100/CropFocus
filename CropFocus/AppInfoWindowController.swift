import AppKit

final class AppInfoWindowController: NSWindowController {
    static let shared = AppInfoWindowController()

    private static let websiteURL = URL(string: "https://gotgam100.github.io/CropFocus/")!

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
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

    private func L(_ key: L10nKey) -> String { Localization.shared.string(key) }

    private func rebuild() {
        guard let window, let contentView = window.contentView else { return }
        window.title = L(.appInfoTitle)
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // 앱 아이콘 + (이름 / 태그라인)
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage  // 에셋의 AppIcon 사용 (변경 시 자동 반영)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56)
        ])
        header.addArrangedSubview(iconView)

        let titleStack = NSStackView()
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        titleStack.addArrangedSubview(makeLabel("CropFocus", font: .systemFont(ofSize: 18, weight: .semibold)))
        titleStack.addArrangedSubview(makeLabel(L(.appTagline), secondary: true))
        header.addArrangedSubview(titleStack)

        root.addArrangedSubview(header)

        // 앱 버전
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        root.addArrangedSubview(makeLabel("\(L(.appVersion)): \(version) (\(build))"))

        // 웹페이지 링크
        let link = NSButton(title: AppInfoWindowController.websiteURL.absoluteString,
                            target: self, action: #selector(openWebsite))
        link.isBordered = false
        link.bezelStyle = .inline
        link.contentTintColor = .linkColor
        link.attributedTitle = NSAttributedString(
            string: AppInfoWindowController.websiteURL.absoluteString,
            attributes: [.foregroundColor: NSColor.linkColor,
                         .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
        )
        link.toolTip = L(.websiteWord)
        root.addArrangedSubview(link)

        // 저작권
        root.addArrangedSubview(makeLabel(L(.copyrightText), secondary: true))

        root.layoutSubtreeIfNeeded()
        let fitting = root.fittingSize
        window.setContentSize(NSSize(width: max(360, fitting.width), height: fitting.height))
    }

    private func makeLabel(_ text: String, font: NSFont? = nil, secondary: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font ?? NSFont.systemFont(ofSize: secondary ? NSFont.smallSystemFontSize : NSFont.systemFontSize)
        if secondary { label.textColor = .secondaryLabelColor }
        return label
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(AppInfoWindowController.websiteURL)
    }
}
