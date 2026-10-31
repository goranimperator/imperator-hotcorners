import AppKit

// Gates rather than features: each runs, measures, and exits. Nothing else in
// the app starts.
let arguments = CommandLine.arguments
if arguments.contains("--dock-check") {
    exit(DockCheck.run())
}
if arguments.contains("--icon-check") {
    exit(MainActor.assumeIsolated { IconCheck.run() })
}
if arguments.contains("--about-check") {
    exit(MainActor.assumeIsolated { AboutCheck.run() })
}
if let flag = arguments.firstIndex(of: "--render-preview") {
    // A gate with a missing directory must fail, not fall through to the live app.
    guard arguments.count > flag + 1, !arguments[flag + 1].hasPrefix("--") else {
        print("FAIL --render-preview needs a directory")
        exit(2)
    }
    let directory = arguments[flag + 1]
    exit(MainActor.assumeIsolated { PreviewRender.run(directory: directory) })
}
if let unknown = arguments.dropFirst().first(where: { $0.hasPrefix("--") }) {
    print("FAIL unknown flag \(unknown)")
    exit(2)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
