import Foundation

/// Version numbers as the update check compares them.
public enum ReleaseVersion {
    /// Numeric comparison, component by component, so 1.0.10 is newer than
    /// 1.0.9 where a string comparison says otherwise. A missing component
    /// counts as 0, so 1.0 and 1.0.0 are the same version.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0
            let y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }
}
