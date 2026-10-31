import Foundation

/// Where hot corners are read from and written to. The Dock is the real one;
/// `InMemoryBackend` stands in for it in tests, previews and the debug fake.
public protocol HotCornerBackend: AnyObject {
    func read() throws -> CornerLayout
    func write(_ setting: CornerSetting, to corner: Corner) throws
}

public enum DockError: Error, Equatable {
    /// The Dock answered non-zero. -4956 is HIServices' code for a call the
    /// Dock did not answer within 3 seconds.
    case status(Int32)
    /// The call returned 0 but the read-back still shows something else.
    case notApplied(Corner)

    public static let noReply = DockError.status(-4956)

    public var isNoReply: Bool { self == .noReply }
}

public final class InMemoryBackend: HotCornerBackend {
    public struct Write: Equatable {
        public let corner: Corner
        public let setting: CornerSetting

        public init(corner: Corner, setting: CornerSetting) {
            self.corner = corner
            self.setting = setting
        }
    }

    public var layout: CornerLayout
    public var failReads = false
    public var failWrites: Set<Corner> = []
    /// What a failing write throws. `DockError.noReply` stands in for a hung Dock.
    public var writeError: DockError = .status(-1)
    /// When set, this many more writes succeed and every one after that fails.
    public var successfulWritesLeft: Int?
    public private(set) var writes: [Write] = []
    public private(set) var writeAttempts = 0

    public init(layout: CornerLayout) { self.layout = layout }

    public func read() throws -> CornerLayout {
        if failReads { throw DockError.noReply }
        return layout
    }

    public func write(_ setting: CornerSetting, to corner: Corner) throws {
        writeAttempts += 1
        if failWrites.contains(corner) { throw writeError }
        if let left = successfulWritesLeft {
            if left <= 0 { throw writeError }
            successfulWritesLeft = left - 1
        }
        let stored = setting.normalized
        layout[corner] = stored
        writes.append(Write(corner: corner, setting: stored))
    }
}
