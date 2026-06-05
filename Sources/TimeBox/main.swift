import Cocoa
import WebKit

class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class ViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 400))
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.width, .height]
        view.addSubview(webView)

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let htmlPath = appSupport.appendingPathComponent("TimeBox/web/index.html").path

        if FileManager.default.fileExists(atPath: htmlPath) {
            webView.loadFileURL(URL(fileURLWithPath: htmlPath), allowingReadAccessTo: URL(fileURLWithPath: appSupport.path))
        } else if let resPath = Bundle.main.resourcePath {
            let bundled = (resPath as NSString).appendingPathComponent("index.html")
            if FileManager.default.fileExists(atPath: bundled) {
                webView.loadFileURL(URL(fileURLWithPath: bundled), allowingReadAccessTo: URL(fileURLWithPath: Bundle.main.resourcePath!))
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vc = ViewController()
        window = FloatingWindow(
            contentRect: NSRect(x: NSScreen.main!.frame.width - 380, y: 100, width: 340, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView, .resizable],
            backing: .buffered, defer: false
        )
        window.level = .floating
        window.title = "TimeBox"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.contentViewController = vc
        window.makeKeyAndOrderFront(nil)
    }
}

NSApplication.shared.setActivationPolicy(.regular)
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
