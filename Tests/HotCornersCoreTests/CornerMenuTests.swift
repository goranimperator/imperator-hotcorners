import Testing
@testable import HotCornersCore

@Test func sectionsMirrorSettingsWithAlternates() {
    let sections = CornerMenu.sections
    #expect(sections.map(\.count) == [96, 32, 16, 16, 1])
    #expect(sections.map { $0.filter { !$0.isAlternate }.map(\.title) } == [
        ["Mission Control", "Application Windows", "Desktop", "Notification Center", "Apps", "Quick Note"],
        ["Start Screen Saver", "Disable Screen Saver"],
        ["Put Display to Sleep"],
        ["Lock Screen"],
        ["-"],
    ])
}

@Test func alternateCarriesItsModifiers() {
    let missionControl = Array(CornerMenu.sections[0][0..<16])
    #expect(missionControl[0] == CornerMenuItem(setting: CornerSetting(action: .missionControl, modifiers: []),
                                                isAlternate: false))
    #expect(missionControl[0].title == "Mission Control")
    #expect(missionControl.dropFirst().allSatisfy { $0.isAlternate && $0.setting.action == .missionControl })
    #expect(missionControl.contains(CornerMenuItem(setting: CornerSetting(action: .missionControl, modifiers: [.command]),
                                                   isAlternate: true)))
    #expect(missionControl.contains { $0.title == "⌃⌥⇧⌘ Mission Control" })
}

@Test func noActionHasNoAlternates() {
    #expect(CornerMenu.sections.last == [CornerMenuItem(setting: .noAction, isAlternate: false)])
}

@Test func unknownValueHasNoPosition() {
    #expect(CornerMenu.position(of: CornerSetting(action: HotCornerAction(rawValue: 15), modifiers: [])) == nil)
}

@Test func positionFindsModifiedAndLegacyValues() {
    let modified = CornerMenu.position(of: CornerSetting(action: .desktop, modifiers: [.command]))!
    #expect(CornerMenu.sections[modified.section][modified.item].title == "⌘ Desktop")
    let legacy = CornerMenu.position(of: CornerSetting(action: .legacyNoAction, modifiers: []))!
    #expect(CornerMenu.sections[legacy.section][legacy.item].title == "-")
}
