// Supervised calibration of the Dock's hot corner setter (PLAN.md Task 3).
//
//   swift scripts/calibrate-dock.swift          dry run, reads only, never loads the setter
//   swift scripts/calibrate-dock.swift --run    changes each corner for under a second, undoing every change
//
// Finds the corner numbers (and the argument order) CoreDockSetExposeCornerActionWithModifier
// expects, then proves the Dock and the com.apple.dock preferences are back where they started.
import Foundation

typealias GetFn = @convention(c) (UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32
typealias SetFn = @convention(c) (Int32, Int32, Int32) -> Int32

let live = CommandLine.arguments.contains("--run")
let library = "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
guard let handle = dlopen(library, RTLD_LAZY),
      let getSymbol = dlsym(handle, "CoreDockGetExposeCornerActionsWithModifiers") else {
    print("FAIL CoreDockGetExposeCornerActionsWithModifiers not found")
    exit(1)
}
let get = unsafeBitCast(getSymbol, to: GetFn.self)

struct Snapshot: Equatable { var actions: [Int32]; var modifiers: [Int32] }

func read() -> Snapshot {
    var a = [Int32](repeating: 1, count: 4), m = [Int32](repeating: 0, count: 4)
    let status = a.withUnsafeMutableBufferPointer { ap in
        m.withUnsafeMutableBufferPointer { mp in get(ap.baseAddress!, mp.baseAddress!) }
    }
    if status != 0 { print("FAIL get status \(status)"); exit(1) }
    return Snapshot(actions: a, modifiers: m.map { $0 & 0x1E0000 })
}

func prefs() -> [String] {
    CFPreferencesAppSynchronize("com.apple.dock" as CFString)
    return ["tl", "tr", "bl", "br"].flatMap { c in ["corner", "modifier"].map { k in
        let value = CFPreferencesCopyAppValue("wvous-\(c)-\(k)" as CFString, "com.apple.dock" as CFString)
        return "\(c)-\(k)=" + (value.map { "\($0)" } ?? "nil")
    } }
}

let titles: [Int32: String] = [1: "-", 2: "Mission Control", 3: "Application Windows", 4: "Desktop", 5: "Start Screen Saver",
    6: "Disable Screen Saver", 10: "Put Display to Sleep", 11: "Apps", 12: "Notification Center", 13: "Lock Screen", 14: "Quick Note"]
func title(_ a: Int32) -> String { a == 0 ? "-" : titles[a] ?? "Other (\(a))" }

let s0 = read()
let prefs0 = prefs()
let names = ["TL", "TR", "BL", "BR"]
for i in 0..<4 { print("\(names[i]) \(title(s0.actions[i])) (raw \(s0.actions[i]), mods \(s0.modifiers[i]))") }
let undo = (0..<4).map { "\(names[$0])=\(title(s0.actions[$0]))" }.joined(separator: " ")
print("To undo by hand: System Settings > Desktop & Dock > Hot Corners: \(undo)")

guard let probe = [Int32(12), 14, 6, 5].first(where: { !s0.actions.contains($0) }) else {
    print("NO_FREE_PROBE_ACTION")
    exit(6)
}
print("probe action \(probe), orders: action,corner,modifiers then corner,action,modifiers; candidate codes 1 2 3 4 0 8")

if !live {
    print("DRY_RUN_OK")
    exit(0)
}

print("This changes your live hot corners for under a second at a time, undoing each change. Type yes to continue:")
guard readLine() == "yes" else { print("aborted"); exit(0) }

guard let setSymbol = dlsym(handle, "CoreDockSetExposeCornerActionWithModifier") else {
    print("FAIL setter not found"); exit(1)
}
let set = unsafeBitCast(setSymbol, to: SetFn.self)

func settle() { Thread.sleep(forTimeInterval: 0.3) }
func call(_ actionFirst: Bool, action: Int32, code: Int32, mods: Int32) {
    _ = actionFirst ? set(action, code, mods) : set(code, action, mods)
    settle()
}

for actionFirst in [true, false] {
    var found: [Int: Int32] = [:]
    for code in [Int32(1), 2, 3, 4, 0, 8] {
        call(actionFirst, action: probe, code: code, mods: 0)
        let s1 = read()
        let changed = (0..<4).filter { s1.actions[$0] != s0.actions[$0] || s1.modifiers[$0] != s0.modifiers[$0] }
        for i in changed { call(actionFirst, action: s0.actions[i], code: code, mods: s0.modifiers[i]) }
        if read() != s0 { print("RESTORE_FAILED"); print("To undo by hand: \(undo)"); exit(2) }
        if changed.count == 1, s1.actions[changed[0]] == probe { found[changed[0]] = code }
        else if !changed.isEmpty { print("AMBIGUOUS c=\(code) changed=\(changed)"); exit(3) }
    }
    if found.count == 4 {
        print(actionFirst ? "ORDER action,corner,modifiers" : "ORDER corner,action,modifiers")
        print("CORNER_CODES tl=\(found[0]!) tr=\(found[1]!) bl=\(found[2]!) br=\(found[3]!)")
        if read() == s0, prefs() == prefs0 { print("STATE_RESTORED") } else {
            print("RESTORE_FAILED"); print("To undo by hand: \(undo)"); exit(2)
        }
        print("CALIBRATION_OK")
        exit(0)
    }
    if !found.isEmpty { print("PARTIAL \(found)"); exit(4) }
}
print("CALIBRATION_FAILED: no corner changed under either order")
exit(5)
