import AppKit
import HotCornersCore

/// `ImperatorHotCorners --dock-check`: reads the Dock through the same call the
/// app uses and compares it with the `wvous-*` preferences. Only the getter is
/// loaded; this check cannot write.
enum DockCheck {
    /// The Dock writes its preferences a moment after it applies a change, so a
    /// mismatch gets three tries half a second apart before it counts.
    static func run() -> Int32 {
        var result = measure()
        for _ in 1..<3 where !result.ok {
            Thread.sleep(forTimeInterval: 0.5)
            result = measure()
        }
        result.lines.forEach { print($0) }
        print(result.ok ? "DOCK_CHECK_OK" : "FAIL the Dock and its preferences disagree")
        return result.ok ? 0 : 1
    }

    private static func measure() -> (ok: Bool, lines: [String]) {
        guard let reader = CoreDockBackend.reader() else {
            return (false, ["FAIL CoreDockGetExposeCornerActionsWithModifiers not found"])
        }
        let layout: CornerLayout
        do { layout = try reader.read() } catch {
            return (false, ["FAIL read \(error)"])
        }
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        func pref(_ key: String) -> Int32? {
            (CFPreferencesCopyAppValue(key as CFString, "com.apple.dock" as CFString) as? Int)
                .flatMap { Int32(exactly: $0) }
        }
        var ok = true
        var lines: [String] = []
        for (corner, key) in zip(Corner.allCases, ["tl", "tr", "bl", "br"]) {
            let setting = layout[corner]
            let head = "\(key.uppercased()) \(setting.action.title) (\(setting.action.rawValue), mods \(setting.modifiers.rawValue))"
            // A fresh account has no key at all and the Dock uses its own
            // default, so a missing key is reported, not compared.
            guard let action = pref("wvous-\(key)-corner") else {
                lines.append("\(head) prefs default")
                continue
            }
            let modifiers = pref("wvous-\(key)-modifier") ?? 0
            let stored = CornerSetting(action: HotCornerAction(rawValue: action), modifiers: CornerModifiers(dockValue: modifiers))
            lines.append("\(head) prefs \(action)/\(modifiers)")
            if stored.normalized != setting.normalized {
                lines.append("FAIL \(key.uppercased()) dock \(setting.action.rawValue)/\(setting.modifiers.rawValue) prefs \(action)/\(modifiers)")
                ok = false
            }
        }
        return (ok, lines)
    }
}
