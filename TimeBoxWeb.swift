import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 0, y: 0, width: 360, height: 440)
        window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView, .resizable],
                         backing: .buffered, defer: false)
        window.title = "TimeBox"
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()

        webView = WKWebView(frame: rect)
        webView.setValue(false, forKey: "drawsBackground")
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView

        let resources = Bundle.main.resourcePath ?? ""
        let url = URL(fileURLWithPath: resources + "/timebox.html")
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

        window.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
