import Foundation

public struct CornerMenuItem: Equatable, Sendable {
    public let setting: CornerSetting
    /// AppKit shows an alternate only while exactly `setting.modifiers` are held.
    public let isAlternate: Bool

    public init(setting: CornerSetting, isAlternate: Bool) {
        self.setting = setting
        self.isAlternate = isAlternate
    }

    public var title: String { setting.title }
}

public struct MenuPosition: Equatable, Sendable {
    public let section: Int
    public let item: Int

    public init(section: Int, item: Int) {
        self.section = section
        self.item = item
    }
}

/// The pop-up's menu as pure data: System Settings' sections and order, each
/// action followed by its 15 modifier alternates. The same for every corner and
/// every value: the closed pop-up shows the current value on its own.
public enum CornerMenu {
    public static let sections: [[CornerMenuItem]] = HotCornerAction.menuSections.map { group in
        group.flatMap { action -> [CornerMenuItem] in
            let base = CornerMenuItem(setting: CornerSetting(action: action, modifiers: []), isAlternate: false)
            if action == .noAction { return [base] }
            return [base] + CornerModifiers.allCombinations.map {
                CornerMenuItem(setting: CornerSetting(action: action, modifiers: $0), isAlternate: true)
            }
        }
    }

    /// Where a setting sits in `sections`, or nil for a value the menu does not
    /// offer (an action from a newer macOS).
    public static func position(of setting: CornerSetting) -> MenuPosition? {
        let wanted = setting.normalized
        for (s, section) in sections.enumerated() {
            for (i, item) in section.enumerated() where item.setting.normalized == wanted {
                return MenuPosition(section: s, item: i)
            }
        }
        return nil
    }
}
