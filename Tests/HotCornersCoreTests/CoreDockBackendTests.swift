import Foundation
import Testing
@testable import HotCornersCore

/// A stand-in for the Dock: the two C functions as closures over four-slot arrays.
final class FakeDock {
    var actions: [Int32]
    var modifiers: [Int32]
    var getStatus: Int32 = 0
    var ignoreSets = false
    /// A set lands only after this many further reads, like a Dock that applies
    /// the change after it replies.
    var applyAfterReads = 0
    private var pending: (index: Int, action: Int32, modifiers: Int32, readsLeft: Int)?
    private(set) var reads = 0
    private(set) var calls: [[Int32]] = []

    init(_ actions: [Int32], _ modifiers: [Int32] = [0, 0, 0, 0]) {
        self.actions = actions
        self.modifiers = modifiers
    }

    func backend(readBackTimeout: TimeInterval = 0) -> CoreDockBackend {
        CoreDockBackend(
            get: { [self] a, m in
                reads += 1
                if let p = pending {
                    if p.readsLeft <= 0 {
                        actions[p.index] = p.action
                        modifiers[p.index] = p.modifiers
                        pending = nil
                    } else {
                        pending = (p.index, p.action, p.modifiers, p.readsLeft - 1)
                    }
                }
                for i in 0..<4 { a[i] = actions[i]; m[i] = modifiers[i] }
                return getStatus
            },
            set: { [self] action, code, mods in
                calls.append([action, code, mods])
                guard !ignoreSets,
                      let i = Corner.allCases.firstIndex(where: { CoreDockBackend.cornerCode($0) == code })
                else { return 0 }
                if applyAfterReads > 0 {
                    pending = (i, action, mods, applyAfterReads)
                } else {
                    actions[i] = action
                    modifiers[i] = mods
                }
                return 0
            },
            readBackTimeout: readBackTimeout,
            pollInterval: 0)
    }
}

@Test func readMapsTheDockArraysInOrder() throws {
    let dock = FakeDock([2, 4, 11, 1], [0, 0x100000, 0, 0])
    #expect(try dock.backend().read() == CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0x100000, 0, 0]))
}

@Test func readThrowsWhenTheDockDoesNotAnswer() {
    let dock = FakeDock([1, 1, 1, 1])
    dock.getStatus = -4956
    #expect(throws: DockError.noReply) { try dock.backend().read() }
}

@Test func writeSendsActionCornerModifiersInSettingsOrder() throws {
    let dock = FakeDock([2, 4, 11, 1])
    try dock.backend().write(CornerSetting(action: .desktop, modifiers: [.command]), to: .bottomLeft)
    #expect(dock.calls == [[4, CoreDockBackend.cornerCode(.bottomLeft), 0x100000]])
    #expect(dock.actions == [2, 4, 4, 1])
}

@Test func writeNormalizesTheLegacyNoAction() throws {
    let dock = FakeDock([2, 4, 11, 1])
    try dock.backend().write(CornerSetting(action: .legacyNoAction, modifiers: [.command]), to: .topLeft)
    #expect(dock.calls == [[1, CoreDockBackend.cornerCode(.topLeft), 0]])
}

@Test func writeThatLandsAtOnceReadsBackOnce() throws {
    let dock = FakeDock([2, 4, 11, 1])
    try dock.backend(readBackTimeout: 0.3).write(.noAction, to: .topRight)
    #expect(dock.reads == 1)
}

@Test func writeThatLandsLateIsWaitedFor() throws {
    let dock = FakeDock([2, 4, 11, 1])
    dock.applyAfterReads = 2
    try dock.backend(readBackTimeout: 0.3).write(.noAction, to: .topRight)
    #expect(dock.actions == [2, 1, 11, 1])
    #expect(dock.reads == 3)
}

@Test func writeThatNeverLandsThrows() {
    let dock = FakeDock([2, 4, 11, 1])
    dock.ignoreSets = true
    #expect(throws: DockError.notApplied(.topRight)) { try dock.backend(readBackTimeout: 0).write(.noAction, to: .topRight) }
    #expect(dock.reads == 1)
}

@Test func readerNeverWrites() throws {
    // `reader()` loads only the getter; its write must fail without a Dock call.
    guard let reader = CoreDockBackend.reader() else { return }
    #expect(throws: DockError.status(-1)) { try reader.write(.noAction, to: .topLeft) }
}

@Test func cornerCodesAreDistinct() {
    #expect(Set(Corner.allCases.map(CoreDockBackend.cornerCode)).count == 4)
}

@Test func cornerCodesMatchTheCalibration() {
    // From `scripts/calibrate-dock.swift --run` on 2026-10-31, macOS 27.2 (26B123).
    #expect(Corner.allCases.map(CoreDockBackend.cornerCode) == [0, 1, 2, 3])
}
