import Cocoa
import AppKit

// ─── Color palette ─────────────────────────────────────
struct Theme {
    static let bg       = NSColor(white: 0.12, alpha: 0.92)
    static let cardBg   = NSColor(white: 0.18, alpha: 1)
    static let text     = NSColor.white
    static let dim      = NSColor(white: 0.6, alpha: 1)
    static let accent   = NSColor(red: 0.85, green: 0.70, blue: 0.45, alpha: 1) // gold
    static let green    = NSColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1)
    static let red      = NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1)
    static let border   = NSColor(white: 0.25, alpha: 1)
}

// ─── Data model ─────────────────────────────────────────
struct TimeSlot: Codable {
    var startMinute: Int  // minutes from midnight
    var task: String
    var done: Bool
}

struct TimeBoxData: Codable {
    var slots: [TimeSlot]
    var currentTask: String

    static func load() -> TimeBoxData {
        guard let data = try? Data(contentsOf: dataPath()),
              let obj = try? JSONDecoder().decode(TimeBoxData.self, from: data)
        else { return TimeBoxData(slots: [], currentTask: "") }
        return obj
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: Self.dataPath(), options: .atomic)
        }
    }

    static func dataPath() -> URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TimeBox")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("timebox.json")
    }
}

// ─── Floating Panel ─────────────────────────────────────
class TimeBoxPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// ─── Main View Controller ───────────────────────────────
class TimeBoxViewController: NSViewController {
    private let data = TimeBoxData.load()

    private let timerLabel = NSTextField(labelWithString: "")
    private let blockLabel = NSTextField(labelWithString: "")
    private let taskField = NSTextField()
    private let progressView = NSView()
    private let logTable = NSTableView()
    private var timer: Timer?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 380))
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg.cgColor
        view.layer?.cornerRadius = 12
        view.layer?.borderWidth = 1
        view.layer?.borderColor = Theme.border.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateClock()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
    }

    private func setupUI() {
        // ── Drag handle ──
        let handleBtn = NSButton(title: "⠿", target: self, action: #selector(toggleDrag))
        handleBtn.bezelStyle = .rounded
        handleBtn.setButtonType(.momentaryChange)
        handleBtn.font = NSFont.systemFont(ofSize: 14)
        handleBtn.frame = CGRect(x: 8, y: 348, width: 30, height: 24)
        handleBtn.contentTintColor = Theme.dim
        view.addSubview(handleBtn)

        // ── Timer display ──
        timerLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 48, weight: .light)
        timerLabel.textColor = Theme.accent
        timerLabel.alignment = .center
        timerLabel.frame = CGRect(x: 0, y: 280, width: 320, height: 60)
        timerLabel.isEditable = false
        timerLabel.isSelectable = false
        view.addSubview(timerLabel)

        // ── Block label ──
        blockLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        blockLabel.textColor = Theme.dim
        blockLabel.alignment = .center
        blockLabel.frame = CGRect(x: 0, y: 260, width: 320, height: 20)
        blockLabel.isEditable = false
        blockLabel.isSelectable = false
        view.addSubview(blockLabel)

        // ── Progress bar (custom drawn) ──
        progressView.wantsLayer = true
        progressView.layer?.backgroundColor = Theme.cardBg.cgColor
        progressView.layer?.cornerRadius = 2
        progressView.frame = CGRect(x: 20, y: 242, width: 280, height: 4)
        view.addSubview(progressView)

        // ── Task input ──
        taskField.placeholderString = "这个10分钟做什么？"
        taskField.font = NSFont.systemFont(ofSize: 14)
        taskField.textColor = Theme.text
        taskField.backgroundColor = Theme.cardBg
        taskField.isBordered = false
        taskField.wantsLayer = true
        taskField.layer?.cornerRadius = 8
        taskField.layer?.backgroundColor = Theme.cardBg.cgColor
        taskField.frame = CGRect(x: 16, y: 200, width: 288, height: 32)
        taskField.delegate = self
        view.addSubview(taskField)

        // ── Punch button ──
        let punchBtn = NSButton(title: "✅ 打卡这个10分钟", target: self, action: #selector(punchIn))
        punchBtn.bezelStyle = .rounded
        punchBtn.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        punchBtn.frame = CGRect(x: 60, y: 155, width: 200, height: 32)
        punchBtn.contentTintColor = Theme.green
        punchBtn.wantsLayer = true
        punchBtn.layer?.cornerRadius = 8
        punchBtn.layer?.borderWidth = 1
        punchBtn.layer?.borderColor = NSColor.clear.cgColor
        view.addSubview(punchBtn)

        // ── Log table ──
        let scrollView = NSScrollView(frame: CGRect(x: 16, y: 10, width: 288, height: 130))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        logTable.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        logTable.headerView = nil
        logTable.backgroundColor = .clear
        logTable.delegate = self
        logTable.dataSource = self
        logTable.selectionHighlightStyle = .none

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("task"))
        col.width = 200
        logTable.addTableColumn(col)

        let col2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        col2.width = 80
        logTable.addTableColumn(col2)

        scrollView.documentView = logTable
        view.addSubview(scrollView)

        // Load saved task
        taskField.stringValue = data.currentTask

        // ── Drag gesture ──
        view.window?.isMovableByWindowBackground = true
    }

    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func currentSlotIndex() -> Int {
        let cal = Calendar.current
        let now = Date()
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        return mins / 10
    }

    private func slotStart(_ idx: Int) -> String {
        let h = idx * 10 / 60
        let m = idx * 10 % 60
        return String(format: "%02d:%02d", h, m)
    }

    private func slotEnd(_ idx: Int) -> String {
        let endMinutes = (idx + 1) * 10
        let h = endMinutes / 60 % 24
        let m = endMinutes % 60
        return String(format: "%02d:%02d", h, m)
    }

    @objc func updateClock() {
        let now = Date()
        let cal = Calendar.current
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let currentBlock = mins / 10
        let elapsed = mins - currentBlock * 10
        let remaining = 10 - elapsed

        // Timer display
        let m = remaining
        let s = 59 - cal.component(.second, from: now)
        timerLabel.stringValue = String(format: "%d:%02d", m, s)

        // Block label
        blockLabel.stringValue = "\(slotStart(currentBlock)) – \(slotEnd(currentBlock))  ·  第 \(currentBlock+1) 块"

        // Progress bar
        let pct = CGFloat(elapsed) / 10.0
        let fillLayer = CALayer()
        fillLayer.backgroundColor = remaining <= 2 ? Theme.red.cgColor : Theme.accent.cgColor
        fillLayer.frame = CGRect(x: 0, y: 0, width: 280 * pct, height: 4)
        fillLayer.cornerRadius = 2
        progressView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        progressView.layer?.addSublayer(fillLayer)

        logTable.reloadData()
    }

    @objc func punchIn() {
        let now = Date()
        let cal = Calendar.current
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let blockIdx = mins / 10
        let task = taskField.stringValue.trimmingCharacters(in: .whitespaces)

        // Remove existing entry for this block
        data.slots.removeAll { $0.startMinute == blockIdx * 10 }
        data.slots.append(TimeSlot(startMinute: blockIdx * 10, task: task.isEmpty ? "（未命名）" : task, done: true))
        data.currentTask = task
        data.save()
        logTable.reloadData()

        // Flash feedback
        if let layer = view.layer {
            let flash = CABasicAnimation(keyPath: "opacity")
            flash.fromValue = 0.4
            flash.toValue = 1.0
            flash.duration = 0.3
            layer.add(flash, forKey: "flash")
        }
    }

    @objc func toggleDrag() {
        view.window?.isMovableByWindowBackground.toggle()
    }
}

// ─── NSTableView ─────────────────────────────────────────
extension TimeBoxViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return min(data.slots.count, 15)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let sorted = data.slots.sorted { $0.startMinute > $1.startMinute }
        guard row < sorted.count else { return nil }

        let slot = sorted[row]
        let cell = NSTableCellView()

        if tableColumn?.identifier == NSUserInterfaceItemIdentifier("task") {
            let label = NSTextField(labelWithString: "\(slotStart(slot.startMinute/10))  \(slot.task)")
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = Theme.text
            label.frame = CGRect(x: 4, y: 0, width: 190, height: 22)
            cell.addSubview(label)
        } else {
            let label = NSTextField(labelWithString: slot.done ? "✅" : "⏳")
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = Theme.green
            label.frame = CGRect(x: 4, y: 0, width: 60, height: 22)
            cell.addSubview(label)
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 24
    }
}

// ─── NSTextField delegate ───────────────────────────────
extension TimeBoxViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        data.currentTask = taskField.stringValue
        data.save()
    }
}

// ─── App Delegate ───────────────────────────────────────
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var vc: TimeBoxViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        vc = TimeBoxViewController()

        panel = TimeBoxPanel(
            contentRect: NSRect(x: NSScreen.main!.frame.width - 360, y: 120, width: 320, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentViewController = vc
        panel.makeKeyAndOrderFront(nil)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
}

// ─── Entry ──────────────────────────────────────────────
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
