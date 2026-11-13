import Testing
@testable import HotCornersCore

@Test func versionsCompareNumericallyPerComponent() {
    #expect(ReleaseVersion.isNewer("1.0.10", than: "1.0.9"))
    #expect(!ReleaseVersion.isNewer("1.0.9", than: "1.0.10"))
    #expect(!ReleaseVersion.isNewer("1.0.1", than: "1.0.1"))
    #expect(ReleaseVersion.isNewer("1.1", than: "1.0.9"))
    #expect(!ReleaseVersion.isNewer("1.0", than: "1.0.0"))
    #expect(ReleaseVersion.isNewer("2.0.0", than: "1.9.9"))
}
