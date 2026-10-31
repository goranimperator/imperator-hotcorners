import Foundation
import Testing
@testable import HotCornersCore

@Test func cornerOrderMatchesTheDockArrays() {
    #expect(Corner.allCases.map(\.rawValue) == [0, 1, 2, 3])
    #expect(Corner.topLeft.settingsName == "Top Left Hot Corner")
    #expect(Corner.bottomRight.settingsName == "Bottom Right Hot Corner")
    #expect(Corner.topRight.shortName == "top right")
}

@Test func actionTitlesAndOrderMatchSystemSettings() {
    #expect(HotCornerAction.menuSections.map { $0.map(\.title) } == [
        ["Mission Control", "Application Windows", "Desktop", "Notification Center", "Apps", "Quick Note"],
        ["Start Screen Saver", "Disable Screen Saver"],
        ["Put Display to Sleep"],
        ["Lock Screen"],
        ["-"],
    ])
    #expect(HotCornerAction.menuSections.flatMap { $0 }.map(\.rawValue) == [2, 3, 4, 12, 11, 14, 5, 6, 10, 13, 1])
}

@Test func legacyZeroReadsAsNoAction() {
    #expect(HotCornerAction.legacyNoAction.title == "-")
    #expect(!HotCornerAction.legacyNoAction.isActive && !HotCornerAction.noAction.isActive)
    #expect(CornerSetting(action: .legacyNoAction, modifiers: [.command]).normalized == .noAction)
}

@Test func unknownActionIsKeptAndLabelled() {
    let future = HotCornerAction(rawValue: 15)
    #expect(future.isActive && !future.isKnown)
    #expect(future.title == "Other (15)")
}

@Test func modifiersUseTheSettingsMaskAndGlyphOrder() {
    #expect(CornerModifiers(dockValue: 0x100000 | 0x80000 | 0x1) == [.command, .option])
    #expect(CornerModifiers([.command, .shift, .option, .control]).glyphs == "⌃⌥⇧⌘")
    #expect(CornerModifiers.allCombinations.count == 15)
    #expect(Set(CornerModifiers.allCombinations).count == 15)
    #expect(!CornerModifiers.allCombinations.contains([]))
}

@Test func settingTitleShowsModifiersFirst() {
    #expect(CornerSetting(action: .missionControl, modifiers: [.command]).title == "⌘ Mission Control")
    #expect(CornerSetting.noAction.title == "-")
}

@Test func layoutRoundTripsTheDockArrays() {
    let layout = CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0x100000, 0, 0])
    #expect(layout.topLeft.action == .missionControl)
    #expect(layout[.topRight] == CornerSetting(action: .desktop, modifiers: [.command]))
    #expect(layout.bottomLeft.action == .apps)
    #expect(layout.bottomRight == .noAction)
    #expect(layout.dockActions == [2, 4, 11, 1] && layout.dockModifiers == [0, 0x100000, 0, 0])
    #expect(layout.hasActiveCorner && !CornerLayout.allNoAction.hasActiveCorner)
}

@Test func layoutSurvivesJSON() throws {
    let layout = CornerLayout(dockActions: [15, 0, 13, 1], dockModifiers: [0x40000, 0, 0, 0])
    let decoded = try JSONDecoder().decode(CornerLayout.self, from: JSONEncoder().encode(layout))
    #expect(decoded == layout)
}
