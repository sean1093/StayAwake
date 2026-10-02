import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Info.plist 已設 LSUIElement；這行讓直接執行 binary（swift run）時也不出現在 Dock。
app.setActivationPolicy(.accessory)
app.run()
