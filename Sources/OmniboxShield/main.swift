import AppKit

log("Omnibox Shield process started.")
if AppConstants.debugMode {
    log("Debug mode enabled before AppKit launch.")
}

let app = NSApplication.shared
let delegate = OmniboxShieldApp()
app.delegate = delegate
app.run()
