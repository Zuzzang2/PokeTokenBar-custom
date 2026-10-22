import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
let button = item.button!
button.appearance = NSAppearance(named: .aqua)
var redraws = 0
var controller: MenuAppearanceRefresh? = MenuAppearanceRefresh(button: button) {
    redraws += 1
    button.attributedTitle = NSAttributedString(string: "test 45%")
}
Task { @MainActor in
    for _ in 0..<500 { controller!.requestRefresh() }
    try? await Task.sleep(for: .milliseconds(250))
    precondition(redraws == 0, "same color redrawn")
    button.appearance = NSAppearance(named: .darkAqua)
    for _ in 0..<500 { controller!.requestRefresh() }
    try? await Task.sleep(for: .milliseconds(250))
    precondition(redraws == 1, "dark transition must draw once: \(redraws)")
    for _ in 0..<500 { controller!.requestRefresh() }
    try? await Task.sleep(for: .milliseconds(250))
    precondition(redraws == 1, "same dark color redrawn")
    button.appearance = NSAppearance(named: .aqua)
    controller!.requestRefresh()
    controller!.markRendered()
    try? await Task.sleep(for: .milliseconds(250))
    precondition(redraws == 1, "normal render did not invalidate pending draw")
    button.appearance = NSAppearance(named: .darkAqua)
    controller!.requestRefresh()
    weak var released = controller
    controller = nil
    precondition(released == nil, "pending task retains controller")
    try? await Task.sleep(for: .milliseconds(250))
    precondition(redraws == 1, "released controller redrew")
    print("PASS: production controller, 1500 redundant events, real light/dark transition, normal render, teardown")
    NSStatusBar.system.removeStatusItem(item)
    fflush(stdout)
    exit(0)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 10) { print("FAIL timeout"); fflush(stdout); exit(1) }
app.run()
