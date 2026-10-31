import Foundation
import Testing
@testable import HotCornersCore

/// Goran's corners on 2026-10-27: Mission Control, Desktop, Apps, -.
private let goran = CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0, 0, 0])

private func freshDefaults() -> InMemoryStorage { InMemoryStorage() }

@MainActor
private func makeStore(_ system: CornerLayout) -> (HotCornerStore, InMemoryBackend, InMemoryStorage) {
    let defaults = freshDefaults()
    let backend = InMemoryBackend(layout: system)
    let store = HotCornerStore(backend: backend, defaults: defaults)
    store.refresh()
    return (store, backend, defaults)
}

private func record(_ defaults: SnapshotStorage) -> HotCornerStore.Snapshot? {
    defaults.data(forKey: HotCornerStore.snapshotKey).flatMap { try? JSONDecoder().decode(HotCornerStore.Snapshot.self, from: $0) }
}

private func snapshot(_ defaults: SnapshotStorage) -> CornerLayout? { record(defaults)?.layout }

@Test @MainActor func refreshShowsWhatSettingsHas() {
    let (store, backend, _) = makeStore(goran)
    #expect(store.layout == goran && store.isEnabled && store.problem == nil && backend.writes.isEmpty)
}

@Test @MainActor func switchingOffWritesNoActionToActiveCornersOnly() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    #expect(backend.layout == .allNoAction)
    #expect(backend.writes.map(\.corner) == [.topLeft, .topRight, .bottomLeft])
    #expect(!store.isEnabled && store.layout == goran && snapshot(defaults) == goran)
}

@Test @MainActor func switchingOnRestoresTheSnapshot() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    store.setEnabled(true)
    #expect(backend.layout == goran && store.isEnabled && snapshot(defaults) == nil)
}

@Test @MainActor func offStateSurvivesRelaunch() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    let relaunched = HotCornerStore(backend: backend, defaults: defaults)
    relaunched.refresh()
    #expect(!relaunched.isEnabled && relaunched.layout == goran)
}

@Test @MainActor func settingsChangeWhileOffWins() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    backend.layout[.topRight] = CornerSetting(action: .lockScreen, modifiers: [])
    store.refresh()
    #expect(store.isEnabled && store.layout == backend.layout && snapshot(defaults) == nil)
}

@Test @MainActor func choosingWhileOnWritesAtOnce() {
    let (store, backend, _) = makeStore(goran)
    let pick = CornerSetting(action: .lockScreen, modifiers: [.command])
    store.choose(pick, for: .bottomRight)
    #expect(backend.writes == [InMemoryBackend.Write(corner: .bottomRight, setting: pick)])
    #expect(store.layout.bottomRight == pick)
}

@Test @MainActor func choosingTheCurrentValueWritesNothing() {
    let (store, backend, _) = makeStore(goran)
    store.choose(goran.topLeft, for: .topLeft)
    #expect(backend.writes.isEmpty)
}

@Test @MainActor func choosingWhileOffOnlyEditsTheSnapshot() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    let writesWhileOff = backend.writes.count
    store.choose(CornerSetting(action: .quickNote, modifiers: []), for: .topLeft)
    #expect(backend.writes.count == writesWhileOff)
    #expect(store.layout.topLeft.action == .quickNote && snapshot(defaults)?.topLeft.action == .quickNote)
    store.setEnabled(true)
    #expect(backend.layout.topLeft.action == .quickNote)
}

@Test @MainActor func modifiersAndUnknownActionsSurviveOffAndOn() {
    let system = CornerLayout(dockActions: [15, 2, 0, 1], dockModifiers: [0x40000, 0x100000, 0, 0])
    let (store, backend, _) = makeStore(system)
    store.setEnabled(false)
    store.setEnabled(true)
    #expect(backend.layout == system)
}

@Test @MainActor func failedWriteWhileSwitchingOffRollsBack() {
    let (store, backend, defaults) = makeStore(goran)
    backend.failWrites = [.topRight]
    store.setEnabled(false)
    #expect(store.isEnabled && store.problem == .writeFailed(.topRight))
    #expect(backend.layout == goran && snapshot(defaults) == nil)
}

@Test @MainActor func failedWriteWhileSwitchingOnStaysOff() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    backend.failWrites = [.bottomLeft]
    store.setEnabled(true)
    #expect(!store.isEnabled && store.problem == .writeFailed(.bottomLeft))
    #expect(backend.layout == .allNoAction && snapshot(defaults) == goran)
}

@Test @MainActor func failedChoiceShowsWhatTheDockKept() {
    let (store, backend, _) = makeStore(goran)
    backend.failWrites = [.topLeft]
    store.choose(CornerSetting(action: .desktop, modifiers: []), for: .topLeft)
    #expect(store.problem == .writeFailed(.topLeft) && store.layout.topLeft == goran.topLeft)
}

@Test @MainActor func dockNotRespondingDisablesEditing() {
    let (store, backend, _) = makeStore(goran)
    backend.failReads = true
    store.refresh()
    store.choose(CornerSetting(action: .desktop, modifiers: []), for: .topLeft)
    #expect(store.problem == .dockNotResponding && !store.canEdit && backend.writes.isEmpty)
}

@Test @MainActor func missingApiDisablesEverything() {
    let store = HotCornerStore(backend: nil, defaults: freshDefaults())
    store.refresh()
    store.setEnabled(false)
    #expect(store.problem == .apiMissing && store.isEnabled && !store.canEdit)
}

@Test @MainActor func switchingOffWithNothingActiveStillTurnsOff() {
    let (store, backend, _) = makeStore(.allNoAction)
    store.setEnabled(false)
    #expect(!store.isEnabled && backend.writes.isEmpty)
}

@Test @MainActor func corruptSnapshotIsDropped() {
    let defaults = freshDefaults()
    defaults.set(Data("not json".utf8), forKey: HotCornerStore.snapshotKey)
    let store = HotCornerStore(backend: InMemoryBackend(layout: .allNoAction), defaults: defaults)
    store.refresh()
    #expect(store.isEnabled && defaults.data(forKey: HotCornerStore.snapshotKey) == nil)
}

@Test @MainActor func successfulRefreshClearsTheProblem() {
    let (store, backend, _) = makeStore(goran)
    backend.failReads = true
    store.refresh()
    backend.failReads = false
    store.refresh()
    #expect(store.problem == nil && store.canEdit)
}

@Test @MainActor func settingsWinsEvenWithTheSameValue() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    // Turned back on in System Settings, to the very action the app remembered.
    backend.layout[.topLeft] = goran.topLeft
    store.refresh()
    #expect(store.isEnabled && store.layout == backend.layout && snapshot(defaults) == nil)
}

@Test @MainActor func interruptedSwitchOnKeepsTheSnapshot() {
    let (store, backend, defaults) = makeStore(goran)
    store.setEnabled(false)
    // The top left write lands, top right fails, and the undo of top left fails too.
    backend.successfulWritesLeft = 1
    store.setEnabled(true)
    #expect(!store.isEnabled && store.problem == .writeFailed(.topRight) && store.layout == goran)
    #expect(record(defaults) == HotCornerStore.Snapshot(layout: goran, inTransition: true))
    store.refresh()
    #expect(!store.isEnabled && snapshot(defaults) == goran)
    backend.successfulWritesLeft = nil
    store.setEnabled(true)
    #expect(backend.layout == goran && store.isEnabled && snapshot(defaults) == nil)
}

@Test @MainActor func interruptedSwitchOffLosesNothing() {
    let (store, backend, defaults) = makeStore(goran)
    // Top left goes to "-", top right fails, and the undo of top left fails too.
    backend.successfulWritesLeft = 1
    store.setEnabled(false)
    #expect(store.problem == .writeFailed(.topRight))
    #expect(record(defaults) == HotCornerStore.Snapshot(layout: goran, inTransition: true))
    #expect(!store.isEnabled && store.layout == goran)
    backend.successfulWritesLeft = nil
    store.setEnabled(true)
    #expect(backend.layout == goran && store.isEnabled)
}

@Test @MainActor func hungDockStopsTheSwitchAtOnce() {
    let (store, backend, defaults) = makeStore(goran)
    backend.failWrites = [.topRight]
    backend.writeError = .noReply
    store.setEnabled(false)
    // One write landed, one hung: no undo calls into the hung Dock.
    #expect(backend.writeAttempts == 2)
    #expect(store.problem == .dockNotResponding && !store.canEdit)
    #expect(record(defaults) == HotCornerStore.Snapshot(layout: goran, inTransition: true))
}

@Test @MainActor func hungDockOnChooseDisablesEditing() {
    let (store, backend, _) = makeStore(goran)
    backend.failWrites = [.topLeft]
    backend.writeError = .noReply
    store.choose(CornerSetting(action: .desktop, modifiers: []), for: .topLeft)
    #expect(store.problem == .dockNotResponding && !store.canEdit)
}

@Test @MainActor func editsWaitForARefreshAfterTheDockHung() {
    let (store, backend, _) = makeStore(goran)
    backend.failReads = true
    store.refresh()
    // The Dock is back, but nothing has refreshed yet: the guard alone must block writes.
    backend.failReads = false
    store.choose(CornerSetting(action: .desktop, modifiers: []), for: .topLeft)
    store.setEnabled(false)
    #expect(backend.writeAttempts == 0)
}

@Test @MainActor func unreadDockIsNotShownAsReal() {
    let missing = HotCornerStore(backend: nil, defaults: freshDefaults())
    missing.refresh()
    #expect(!missing.hasReadDock)
    let backend = InMemoryBackend(layout: goran)
    backend.failReads = true
    let hung = HotCornerStore(backend: backend, defaults: freshDefaults())
    hung.refresh()
    #expect(!hung.hasReadDock && !hung.canEdit)
}

@Test @MainActor func oldSnapshotFormatStillLoads() throws {
    let defaults = freshDefaults()
    defaults.set(try JSONEncoder().encode(goran), forKey: HotCornerStore.snapshotKey)
    let store = HotCornerStore(backend: InMemoryBackend(layout: .allNoAction), defaults: defaults)
    store.refresh()
    #expect(!store.isEnabled && store.layout == goran)
}

@Test @MainActor func choosingComparesWithTheDockNotTheLastRefresh() {
    let (store, backend, _) = makeStore(goran)
    backend.layout[.topLeft] = CornerSetting(action: .desktop, modifiers: [])
    store.choose(goran.topLeft, for: .topLeft)
    #expect(backend.layout.topLeft == goran.topLeft)
    #expect(store.layout.topLeft == goran.topLeft)
}
