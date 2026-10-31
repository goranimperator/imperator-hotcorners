import Foundation
import HotCornersCore

#if DEBUG
/// A fake Dock for clicking through every state without touching the real
/// corners. `IMPERATOR_HOTCORNERS_FAKE=1` turns it on;
/// `IMPERATOR_HOTCORNERS_FAKE_FAIL` takes `reads` or a comma list of
/// `tl,tr,bl,br`. Compiled out of release builds.
func makeDebugBackend() -> HotCornerBackend? {
    let environment = ProcessInfo.processInfo.environment
    guard environment["IMPERATOR_HOTCORNERS_FAKE"] == "1" else { return nil }
    let backend = InMemoryBackend(
        layout: CornerLayout(dockActions: [2, 4, 11, 1], dockModifiers: [0, 0, 0, 0]))
    for token in (environment["IMPERATOR_HOTCORNERS_FAKE_FAIL"] ?? "").split(separator: ",") {
        switch token {
        case "reads": backend.failReads = true
        case "tl": backend.failWrites.insert(.topLeft)
        case "tr": backend.failWrites.insert(.topRight)
        case "bl": backend.failWrites.insert(.bottomLeft)
        case "br": backend.failWrites.insert(.bottomRight)
        default: break
        }
    }
    return backend
}
#endif
