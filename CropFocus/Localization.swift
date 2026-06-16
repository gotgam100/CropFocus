import Foundation

enum AppLanguage: String, CaseIterable {
    case korean = "ko"
    case english = "en"
}

enum L10nKey: String {
    case appName
    case menuStartSelection
    case menuClearMask
    case menuDarkness
    case menuSettings
    case menuAppInfo        // "앱 정보"
    case menuQuit
    case settingsWord       // "설정" / "Settings"
    case appVersion
    case launchAtLogin
    case showStatusBar      // "포커스 중 메뉴 막대 보기"
    case shortcutsButton    // "단축키 설명"
    case shortcutsTitle     // 안내 창 제목
    case shortcutSelect     // "영역 선택 시작"
    case shortcutClear      // "마스킹 해제"
    case shortcutEsc        // "마스킹 즉시 해제"
    case shortcutReplace    // "영역 다시 선택 (교체)"
    case shortcutAdd        // "영역 추가"
    case dragWord           // "드래그" / "drag"
    case okWord             // "확인" / "OK"
    case appInfoTitle       // 앱 정보 창 제목
    case appTagline         // "집중을 위한 화면"
    case websiteWord        // "웹페이지" / "Website"
    case copyrightText      // 저작권 문구
    case systemInfo
    case language
    case languageKorean     // "한국어"
    case languageEnglish    // "English"
    case pixelsUnit         // "픽셀" / "px"
    case displayFallback    // "디스플레이" / "Display"
    case launchFailTitle
    case macos13Tooltip
}

/// 런타임에 한국어/영어를 전환하는 간단한 로컬라이제이션 매니저.
/// 선택값은 UserDefaults에 저장되고, 변경 시 알림을 보내 메뉴/설정 창이 갱신된다.
final class Localization {
    static let shared = Localization()
    static let didChangeNotification = Notification.Name("LocalizationDidChange")

    private let defaultsKey = "AppLanguage"
    private(set) var language: AppLanguage

    private init() {
        if let saved = UserDefaults.standard.string(forKey: defaultsKey),
           let lang = AppLanguage(rawValue: saved) {
            language = lang
        } else {
            // 저장된 선택이 없으면 기본 언어는 한국어
            language = .korean
        }
    }

    func setLanguage(_ lang: AppLanguage) {
        guard lang != language else { return }
        language = lang
        UserDefaults.standard.set(lang.rawValue, forKey: defaultsKey)
        NotificationCenter.default.post(name: Localization.didChangeNotification, object: nil)
    }

    func string(_ key: L10nKey) -> String {
        let table = (language == .korean) ? Localization.ko : Localization.en
        return table[key] ?? key.rawValue
    }

    /// 설정 창 제목: "CropFocus - 설정" / "CropFocus - Settings"
    var settingsWindowTitle: String {
        language == .korean ? "CropFocus - 설정" : "CropFocus - Settings"
    }

    private static let ko: [L10nKey: String] = [
        .appName: "자르고 집중",
        .menuStartSelection: "영역 선택 시작",
        .menuClearMask: "마스킹 해제",
        .menuDarkness: "어둡기 조절",
        .menuSettings: "설정…",
        .menuAppInfo: "앱 정보",
        .menuQuit: "종료",
        .settingsWord: "설정",
        .appVersion: "앱 버전",
        .launchAtLogin: "로그인 시 자동 실행",
        .showStatusBar: "포커스 중 메뉴 막대 보기",
        .shortcutsButton: "단축키 설명",
        .shortcutsTitle: "단축키",
        .shortcutSelect: "영역 선택 시작",
        .shortcutClear: "마스킹 해제",
        .shortcutEsc: "마스킹 즉시 해제",
        .shortcutReplace: "영역 다시 선택 (교체)",
        .shortcutAdd: "영역 추가",
        .dragWord: "드래그",
        .okWord: "확인",
        .appInfoTitle: "앱 정보",
        .appTagline: "집중을 위한 화면",
        .websiteWord: "웹페이지",
        .copyrightText: "© 2026 CropFocus. All rights reserved.",
        .systemInfo: "화면 정보",
        .language: "언어",
        .languageKorean: "한국어",
        .languageEnglish: "English",
        .pixelsUnit: "픽셀",
        .displayFallback: "디스플레이",
        .launchFailTitle: "자동 실행 설정에 실패했습니다.",
        .macos13Tooltip: "macOS 13 이상에서 지원됩니다."
    ]

    private static let en: [L10nKey: String] = [
        .appName: "CropFocus",
        .menuStartSelection: "Start Selection",
        .menuClearMask: "Clear Mask",
        .menuDarkness: "Darkness",
        .menuSettings: "Settings…",
        .menuAppInfo: "About",
        .menuQuit: "Quit",
        .settingsWord: "Settings",
        .appVersion: "App Version",
        .launchAtLogin: "Launch at Login",
        .showStatusBar: "Show menu bar while focusing",
        .shortcutsButton: "Keyboard Shortcuts",
        .shortcutsTitle: "Keyboard Shortcuts",
        .shortcutSelect: "Start area selection",
        .shortcutClear: "Clear mask",
        .shortcutEsc: "Clear mask immediately",
        .shortcutReplace: "Reselect area (replace)",
        .shortcutAdd: "Add area",
        .dragWord: "drag",
        .okWord: "OK",
        .appInfoTitle: "About",
        .appTagline: "Focus on what matters",
        .websiteWord: "Website",
        .copyrightText: "© 2026 CropFocus. All rights reserved.",
        .systemInfo: "Display Information",
        .language: "Language",
        .languageKorean: "한국어",
        .languageEnglish: "English",
        .pixelsUnit: "px",
        .displayFallback: "Display",
        .launchFailTitle: "Failed to change the launch-at-login setting.",
        .macos13Tooltip: "Requires macOS 13 or later."
    ]
}

/// 짧은 접근 헬퍼
func L(_ key: L10nKey) -> String {
    Localization.shared.string(key)
}
