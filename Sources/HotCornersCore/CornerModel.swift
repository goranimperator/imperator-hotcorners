import Foundation

/// The four screen corners, in the order the Dock's arrays use (top left, top
/// right, bottom left, bottom right).
public enum Corner: Int, CaseIterable, Codable, Sendable {
    case topLeft = 0, topRight = 1, bottomLeft = 2, bottomRight = 3

    /// System Settings' accessibility name for the corner's pop-up button.
    public var settingsName: String {
        switch self {
        case .topLeft: "Top Left Hot Corner"
        case .topRight: "Top Right Hot Corner"
        case .bottomLeft: "Bottom Left Hot Corner"
        case .bottomRight: "Bottom Right Hot Corner"
        }
    }

    public var shortName: String {
        switch self {
        case .topLeft: "top left"
        case .topRight: "top right"
        case .bottomLeft: "bottom left"
        case .bottomRight: "bottom right"
        }
    }
}

/// What a corner does. The raw value is the Dock's own number, kept as is so a
/// value this app has never heard of survives a round trip.
public struct HotCornerAction: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) { self.rawValue = rawValue }

    /// The old "no-op". Means the same as `noAction`.
    public static let legacyNoAction = HotCornerAction(rawValue: 0)
    public static let noAction = HotCornerAction(rawValue: 1)
    public static let missionControl = HotCornerAction(rawValue: 2)
    public static let applicationWindows = HotCornerAction(rawValue: 3)
    public static let desktop = HotCornerAction(rawValue: 4)
    public static let startScreenSaver = HotCornerAction(rawValue: 5)
    public static let disableScreenSaver = HotCornerAction(rawValue: 6)
    public static let putDisplayToSleep = HotCornerAction(rawValue: 10)
    public static let apps = HotCornerAction(rawValue: 11)
    public static let notificationCenter = HotCornerAction(rawValue: 12)
    public static let lockScreen = HotCornerAction(rawValue: 13)
    public static let quickNote = HotCornerAction(rawValue: 14)

    /// System Settings' menu order, one array per separator group.
    public static let menuSections: [[HotCornerAction]] = [
        [.missionControl, .applicationWindows, .desktop, .notificationCenter, .apps, .quickNote],
        [.startScreenSaver, .disableScreenSaver],
        [.putDisplayToSleep],
        [.lockScreen],
        [.noAction],
    ]

    public var isKnown: Bool {
        rawValue == 0 || Self.menuSections.joined().contains(self)
    }

    public var isActive: Bool { rawValue != 0 && rawValue != 1 }

    public var title: String {
        switch rawValue {
        case 0, 1: "-"
        case 2: "Mission Control"
        case 3: "Application Windows"
        case 4: "Desktop"
        case 5: "Start Screen Saver"
        case 6: "Disable Screen Saver"
        case 10: "Put Display to Sleep"
        case 11: "Apps"
        case 12: "Notification Center"
        case 13: "Lock Screen"
        case 14: "Quick Note"
        default: "Other (\(rawValue))"
        }
    }
}

/// Modifier keys held while the pointer is in a corner. The bits are
/// `NSEvent.ModifierFlags`, and System Settings keeps only these four.
public struct CornerModifiers: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: Int32

    public init(rawValue: Int32) { self.rawValue = rawValue }

    public static let shift = CornerModifiers(rawValue: 0x20000)
    public static let control = CornerModifiers(rawValue: 0x40000)
    public static let option = CornerModifiers(rawValue: 0x80000)
    public static let command = CornerModifiers(rawValue: 0x100000)
    public static let dockMask: Int32 = 0x1E0000

    public init(dockValue: Int32) { self.init(rawValue: dockValue & Self.dockMask) }

    /// Menu glyph order: control, option, shift, command.
    public var glyphs: String {
        var text = ""
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }

    /// The 15 non-empty sets, by bit pattern with control as the lowest bit.
    public static let allCombinations: [CornerModifiers] = (1...15).map { n in
        var set: CornerModifiers = []
        if n & 1 != 0 { set.insert(.control) }
        if n & 2 != 0 { set.insert(.option) }
        if n & 4 != 0 { set.insert(.shift) }
        if n & 8 != 0 { set.insert(.command) }
        return set
    }
}

public struct CornerSetting: Hashable, Codable, Sendable {
    public var action: HotCornerAction
    public var modifiers: CornerModifiers

    public init(action: HotCornerAction, modifiers: CornerModifiers) {
        self.action = action
        self.modifiers = modifiers
    }

    public static let noAction = CornerSetting(action: .noAction, modifiers: [])

    /// 0 becomes 1, and "-" carries no modifiers.
    public var normalized: CornerSetting {
        action.isActive ? self : .noAction
    }

    public var title: String {
        modifiers.isEmpty ? action.title : "\(modifiers.glyphs) \(action.title)"
    }
}

public struct CornerLayout: Hashable, Codable, Sendable {
    public var topLeft: CornerSetting
    public var topRight: CornerSetting
    public var bottomLeft: CornerSetting
    public var bottomRight: CornerSetting

    public init(topLeft: CornerSetting, topRight: CornerSetting,
                bottomLeft: CornerSetting, bottomRight: CornerSetting) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }

    /// Both arrays hold four values, top left first. Raw actions are kept as
    /// they are; modifiers are masked the way System Settings masks them.
    public init(dockActions: [Int32], dockModifiers: [Int32]) {
        func setting(_ i: Int) -> CornerSetting {
            CornerSetting(
                action: HotCornerAction(rawValue: i < dockActions.count ? dockActions[i] : 1),
                modifiers: CornerModifiers(dockValue: i < dockModifiers.count ? dockModifiers[i] : 0))
        }
        self.init(topLeft: setting(0), topRight: setting(1), bottomLeft: setting(2), bottomRight: setting(3))
    }

    public subscript(corner: Corner) -> CornerSetting {
        get {
            switch corner {
            case .topLeft: topLeft
            case .topRight: topRight
            case .bottomLeft: bottomLeft
            case .bottomRight: bottomRight
            }
        }
        set {
            switch corner {
            case .topLeft: topLeft = newValue
            case .topRight: topRight = newValue
            case .bottomLeft: bottomLeft = newValue
            case .bottomRight: bottomRight = newValue
            }
        }
    }

    public var dockActions: [Int32] { Corner.allCases.map { self[$0].action.rawValue } }
    public var dockModifiers: [Int32] { Corner.allCases.map { self[$0].modifiers.rawValue } }
    public var hasActiveCorner: Bool { Corner.allCases.contains { self[$0].action.isActive } }

    public static let allNoAction = CornerLayout(
        topLeft: .noAction, topRight: .noAction, bottomLeft: .noAction, bottomRight: .noAction)
}
