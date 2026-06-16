import AppKit

// MARK: - Pixel art

let PALETTE: [Character: NSColor] = [
    "b": NSColor(red: 0.784, green: 0.478, blue: 0.333, alpha: 1), // #c87a55 body
    "d": NSColor(red: 0.227, green: 0.141, blue: 0.102, alpha: 1), // #3a241a dark
    "c": NSColor(red: 0.910, green: 0.643, blue: 0.529, alpha: 1)  // #e8a487 blush
]

enum Mood {
    static let idle = [
        "...bb..bb...",
        "..bbbbbbbb..",
        ".bbbbbbbbbb.",
        "bbddbbbbddbb",
        "bbddbbbbddbb",
        "bbbbbbbbbbbb",
        ".bddddddddb.",
        ".bbbbbbbbbb.",
        "..bb....bb.."]
    static let happy = [
        "...bb..bb...",
        "..bbbbbbbb..",
        ".bbbbbbbbbb.",
        "bbddbbbbddbb",
        "bbbbbbbbbbbb",
        "bcbbbbbbbbcb",
        "bbbbddddbbbb",
        ".bbbddddbbb.",
        "..bb....bb.."]
    static let poof = [
        "...b....b...",
        ".b...bb...b.",
        "...bb..bb...",
        ".b.bb..bb.b.",
        "..b.bbbb.b..",
        ".b..bbbb..b.",
        "...b....b...",
        ".b........b.",
        "....b..b...."]
    static let wink = [
        "...bb..bb...",
        "..bbbbbbbb..",
        ".bbbbbbbbbb.",
        "bbddbbbbbbbb",
        "bbddbbbbddbb",
        "bbbbbbbbbbbb",
        "..bddddddb..",
        ".bbbbbbbbbb.",
        "..bb....bb.."]
}

func drawMap(_ map: [String], in rect: NSRect) {
    let rows = map.count
    let cols = map[0].count
    let cell = min(rect.width / CGFloat(cols), rect.height / CGFloat(rows))
    let ox = rect.minX + (rect.width  - cell * CGFloat(cols)) / 2
    let oy = rect.minY + (rect.height - cell * CGFloat(rows)) / 2
    for (r, line) in map.enumerated() {
        for (cIdx, ch) in line.enumerated() {
            guard let color = PALETTE[ch] else { continue }
            color.setFill()
            // row 0 is the top, AppKit y grows upward -> flip
            let y = oy + CGFloat(rows - 1 - r) * cell
            let x = ox + CGFloat(cIdx) * cell
            NSRect(x: x, y: y, width: cell, height: cell).fill()
        }
    }
}

func buddyImage(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    drawMap(Mood.wink, in: NSRect(x: 0, y: 0, width: size, height: size))
    img.unlockFocus()
    return img
}

// MARK: - Settings

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    private func reg() {
        d.register(defaults: [
            "interval": 30,
            "startMin": 9 * 60,
            "endMin": 18 * 60,
            "days": [true, true, true, true, true, false, false], // Mon..Sun
            "placement": 0,
            "size": 50,
            "sound": true
        ])
    }
    init() { reg() }

    var interval: Int { get { d.integer(forKey: "interval") } set { d.set(newValue, forKey: "interval") } }
    var startMin: Int { get { d.integer(forKey: "startMin") } set { d.set(newValue, forKey: "startMin") } }
    var endMin: Int { get { d.integer(forKey: "endMin") } set { d.set(newValue, forKey: "endMin") } }
    var days: [Bool] {
        get { (d.array(forKey: "days") as? [Bool]) ?? [true, true, true, true, true, false, false] }
        set { d.set(newValue, forKey: "days") }
    }
    var placement: Int { get { d.integer(forKey: "placement") } set { d.set(newValue, forKey: "placement") } }
    var size: Int { get { max(40, d.integer(forKey: "size")) } set { d.set(newValue, forKey: "size") } }
    var sound: Bool { get { d.bool(forKey: "sound") } set { d.set(newValue, forKey: "sound") } }
    var hasDrop: Bool { d.bool(forKey: "hasDrop") }
    var lastDrop: NSPoint {
        get { NSPoint(x: d.double(forKey: "lastDropX"), y: d.double(forKey: "lastDropY")) }
        set {
            d.set(newValue.x, forKey: "lastDropX")
            d.set(newValue.y, forKey: "lastDropY")
            d.set(true, forKey: "hasDrop")
        }
    }

    // Weekday: Calendar uses 1=Sun..7=Sat. Our array is 0=Mon..6=Sun.
    func isActiveDay(_ date: Date) -> Bool {
        let wd = Calendar.current.component(.weekday, from: date) // 1=Sun
        let idx = (wd + 5) % 7 // Sun(1)->6, Mon(2)->0 ... Sat(7)->5
        return days[idx]
    }
    func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    func isActiveNow(_ date: Date = Date()) -> Bool {
        guard isActiveDay(date) else { return false }
        let m = minutesOfDay(date)
        if startMin <= endMin { return m >= startMin && m < endMin }
        return m >= startMin || m < endMin // overnight window
    }
}

// MARK: - Buddy view + window

final class BuddyView: NSView {
    var mood: [String] = Mood.idle
    var onClick: (() -> Void)?
    private var downScreen: NSPoint = .zero
    private var originAtDown: NSPoint = .zero
    private var dragDistance: CGFloat = 0
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        drawMap(mood, in: bounds)
    }
    override func mouseDown(with event: NSEvent) {
        downScreen = NSEvent.mouseLocation
        originAtDown = window?.frame.origin ?? .zero
        dragDistance = 0
        NSCursor.closedHand.set()
    }
    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - downScreen.x
        let dy = now.y - downScreen.y
        dragDistance = max(dragDistance, hypot(dx, dy))
        win.setFrameOrigin(NSPoint(x: originAtDown.x + dx, y: originAtDown.y + dy))
    }
    override func mouseUp(with event: NSEvent) {
        NSCursor.openHand.set()
        if dragDistance < 4 {
            onClick?()                       // a real click → dismiss
        } else if let win = window {
            // dragged → remember the spot and make it stick on future appearances
            Settings.shared.lastDrop = win.frame.origin
            Settings.shared.placement = 3
        }
    }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}

final class BuddyController {
    private var window: NSWindow?
    private var view: BuddyView?
    var isVisible: Bool { window?.isVisible ?? false }
    var onDismiss: (() -> Void)?

    func show() {
        if isVisible { return }
        let s = CGFloat(Settings.shared.size)
        let frame = targetFrame(size: s)

        let win = NSWindow(contentRect: frame, styleMask: .borderless,
                           backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .floating
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let v = BuddyView(frame: NSRect(origin: .zero, size: frame.size))
        v.onClick = { [weak self] in self?.dismiss(happy: true) }
        win.contentView = v
        self.view = v
        self.window = win

        // Pop-in: fade + slide up
        win.alphaValue = 0
        var start = frame
        start.origin.y -= 14
        win.setFrame(start, display: false)
        win.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            win.animator().alphaValue = 1
            win.animator().setFrame(frame, display: true)
        }
        if Settings.shared.sound { NSSound(named: "Pop")?.play() }
    }

    private func dismiss(happy: Bool) {
        guard let win = window, let v = view else { return }
        v.mood = Mood.happy
        v.needsDisplay = true
        if Settings.shared.sound { NSSound(named: "Pop")?.play() }
        // brief happy beat, then poof + fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            v.mood = Mood.poof
            v.needsDisplay = true
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.42
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                win.animator().alphaValue = 0
            }, completionHandler: {
                win.orderOut(nil)
                self?.window = nil
                self?.view = nil
                self?.onDismiss?()
            })
        }
    }

    func hideImmediately() {
        window?.orderOut(nil)
        window = nil
        view = nil
    }

    private func targetFrame(size: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let vf = screen.visibleFrame
        let margin: CGFloat = 24
        func rand(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + CGFloat(Double.random(in: 0...1)) * (b - a) }
        func clamp(_ p: NSPoint) -> NSRect {
            let x = min(max(vf.minX + margin, p.x), vf.maxX - size - margin)
            let y = min(max(vf.minY + margin, p.y), vf.maxY - size - margin)
            return NSRect(x: x, y: y, width: size, height: size)
        }
        switch Settings.shared.placement {
        case 3: // where I last left it
            if Settings.shared.hasDrop { return clamp(Settings.shared.lastDrop) }
            return clamp(NSPoint(x: vf.maxX - size - margin, y: vf.minY + margin))
        case 1: // random spot
            let x = rand(vf.minX + margin, vf.maxX - size - margin)
            let y = rand(vf.minY + margin, vf.maxY - size - margin)
            return NSRect(x: x, y: y, width: size, height: size)
        case 2: // near cursor
            let p = NSEvent.mouseLocation
            var x = p.x + 18, y = p.y - size - 18
            x = min(max(vf.minX + margin, x), vf.maxX - size - margin)
            y = min(max(vf.minY + margin, y), vf.maxY - size - margin)
            return NSRect(x: x, y: y, width: size, height: size)
        default: // bottom-right with jitter
            let x = vf.maxX - size - margin - rand(0, 40)
            let y = vf.minY + margin + rand(0, 40)
            return NSRect(x: x, y: y, width: size, height: size)
        }
    }
}

// MARK: - Preferences window

final class PreferencesController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var sizeLabel: NSTextField?
    private let dayTitles = ["M", "T", "W", "T", "F", "S", "S"]
    private var dayButtons: [NSButton] = []

    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    private func label(_ text: String, _ frame: NSRect) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.frame = frame
        l.textColor = .secondaryLabelColor
        return l
    }

    private func build() {
        let w: CGFloat = 400, h: CGFloat = 320
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                           styleMask: [.titled, .closable],
                           backing: .buffered, defer: false)
        win.title = "Worklog Buddy — Preferences"
        win.isReleasedWhenClosed = false
        win.delegate = self
        let c = win.contentView!
        let s = Settings.shared

        func rowY(_ i: Int) -> CGFloat { h - 44 - CGFloat(i) * 42 }
        let labelX: CGFloat = 22, labelW: CGFloat = 118, ctrlX: CGFloat = 148

        // Remind me every
        c.addSubview(label("Remind me every", NSRect(x: labelX, y: rowY(0), width: labelW, height: 22)))
        let intervalPop = NSPopUpButton(frame: NSRect(x: ctrlX, y: rowY(0) - 3, width: 140, height: 26))
        let intervals = [20, 30, 45, 60]
        intervalPop.addItems(withTitles: intervals.map { $0 == 60 ? "1 hour" : "\($0) minutes" })
        intervalPop.selectItem(at: intervals.firstIndex(of: s.interval) ?? 1)
        intervalPop.target = self; intervalPop.action = #selector(intervalChanged(_:))
        c.addSubview(intervalPop)

        // Active hours
        c.addSubview(label("Active hours", NSRect(x: labelX, y: rowY(1), width: labelW, height: 22)))
        let startPicker = timePicker(min: s.startMin, x: ctrlX, y: rowY(1) - 3, tag: 1)
        let toLabel = label("to", NSRect(x: ctrlX + 86, y: rowY(1), width: 22, height: 22))
        let endPicker = timePicker(min: s.endMin, x: ctrlX + 110, y: rowY(1) - 3, tag: 2)
        c.addSubview(startPicker); c.addSubview(toLabel); c.addSubview(endPicker)

        // Active days
        c.addSubview(label("Active days", NSRect(x: labelX, y: rowY(2), width: labelW, height: 22)))
        for i in 0..<7 {
            let b = NSButton(frame: NSRect(x: ctrlX + CGFloat(i) * 32, y: rowY(2) - 4, width: 30, height: 30))
            b.setButtonType(.pushOnPushOff)
            b.bezelStyle = .rounded
            b.title = dayTitles[i]
            b.state = s.days[i] ? .on : .off
            b.tag = i
            b.target = self; b.action = #selector(dayToggled(_:))
            dayButtons.append(b)
            c.addSubview(b)
        }

        // Appears
        c.addSubview(label("Appears", NSRect(x: labelX, y: rowY(3), width: labelW, height: 22)))
        let placePop = NSPopUpButton(frame: NSRect(x: ctrlX, y: rowY(3) - 3, width: 180, height: 26))
        placePop.addItems(withTitles: ["Bottom-right corner", "Random spot", "Near the cursor", "Where I last left it"])
        placePop.selectItem(at: s.placement)
        placePop.target = self; placePop.action = #selector(placeChanged(_:))
        c.addSubview(placePop)

        // Buddy size
        c.addSubview(label("Buddy size", NSRect(x: labelX, y: rowY(4), width: labelW, height: 22)))
        let slider = NSSlider(frame: NSRect(x: ctrlX, y: rowY(4) - 2, width: 150, height: 24))
        slider.minValue = 40; slider.maxValue = 80; slider.doubleValue = Double(s.size)
        slider.target = self; slider.action = #selector(sizeChanged(_:))
        c.addSubview(slider)
        let sl = label("\(s.size)px", NSRect(x: ctrlX + 158, y: rowY(4), width: 50, height: 22))
        sizeLabel = sl; c.addSubview(sl)

        // Sound
        let soundBox = NSButton(checkboxWithTitle: "Blip sound when it appears", target: self, action: #selector(soundToggled(_:)))
        soundBox.frame = NSRect(x: ctrlX, y: rowY(5) - 2, width: 240, height: 22)
        soundBox.state = s.sound ? .on : .off
        c.addSubview(soundBox)

        self.window = win
    }

    private func timePicker(min: Int, x: CGFloat, y: CGFloat, tag: Int) -> NSDatePicker {
        let p = NSDatePicker(frame: NSRect(x: x, y: y, width: 80, height: 26))
        p.datePickerStyle = .textFieldAndStepper
        p.datePickerElements = .hourMinute
        var comp = DateComponents(); comp.hour = min / 60; comp.minute = min % 60
        p.dateValue = Calendar.current.date(from: comp) ?? Date()
        p.tag = tag
        p.target = self; p.action = #selector(timeChanged(_:))
        return p
    }

    @objc private func intervalChanged(_ s: NSPopUpButton) {
        let intervals = [20, 30, 45, 60]
        Settings.shared.interval = intervals[s.indexOfSelectedItem]
        AppState.shared?.rescheduleFromNow()
    }
    @objc private func timeChanged(_ p: NSDatePicker) {
        let m = Settings.shared.minutesOfDay(p.dateValue)
        if p.tag == 1 { Settings.shared.startMin = m } else { Settings.shared.endMin = m }
    }
    @objc private func dayToggled(_ b: NSButton) {
        var d = Settings.shared.days
        d[b.tag] = (b.state == .on)
        Settings.shared.days = d
    }
    @objc private func placeChanged(_ s: NSPopUpButton) { Settings.shared.placement = s.indexOfSelectedItem }
    @objc private func sizeChanged(_ s: NSSlider) {
        Settings.shared.size = Int(s.doubleValue.rounded())
        sizeLabel?.stringValue = "\(Settings.shared.size)px"
    }
    @objc private func soundToggled(_ b: NSButton) { Settings.shared.sound = (b.state == .on) }
}

// MARK: - App

final class AppState {
    static var shared: AppDelegate?
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let buddy = BuddyController()
    private let prefs = PreferencesController()
    private var ticker: Timer?
    private var menuTimer: Timer?
    private var nextNudge = Date().addingTimeInterval(3)   // first appearance ~3s after launch
    private var pausedUntil: Date?
    private var statusLine: NSMenuItem!

    func applicationDidFinishLaunching(_ note: Notification) {
        AppState.shared = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            let img = buddyImage(size: 18)
            img.isTemplate = false
            btn.image = img
            btn.imagePosition = .imageOnly
        }
        buildMenu()
        buddy.onDismiss = { [weak self] in self?.rescheduleFromNow() }
        ticker = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(ticker!, forMode: .common)
        tick()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let title = NSMenuItem(title: "Worklog Buddy", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        statusLine = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Show buddy now", action: #selector(showNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Snooze 15 min", action: #selector(snooze), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Pause for today", action: #selector(pauseToday), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items where item.action != nil { item.target = self }
        menu.delegate = self
        statusItem.menu = menu
    }

    // Live-refresh the countdown once per second while the menu is open.
    func menuWillOpen(_ menu: NSMenu) {
        updateStatus()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.updateStatus() }
        RunLoop.main.add(t, forMode: .common)   // .common so it fires during menu tracking
        menuTimer = t
    }
    func menuDidClose(_ menu: NSMenu) {
        menuTimer?.invalidate()
        menuTimer = nil
    }

    func rescheduleFromNow() {
        nextNudge = Date().addingTimeInterval(TimeInterval(Settings.shared.interval * 60))
        updateStatus()
    }

    private func tick() {
        let now = Date()
        if let until = pausedUntil, now >= until { pausedUntil = nil }
        if pausedUntil == nil, Settings.shared.isActiveNow(now),
           now >= nextNudge, !buddy.isVisible {
            buddy.show()
            nextNudge = now.addingTimeInterval(TimeInterval(Settings.shared.interval * 60))
        }
        updateStatus()
    }

    private func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s >= 3600 { return String(format: "%dh %02dm", s / 3600, (s % 3600) / 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // The next moment the active window opens, scanning up to a week ahead.
    private func nextActiveStart(after date: Date) -> Date {
        let cal = Calendar.current
        let s = Settings.shared
        for offset in 0...8 {
            guard let day = cal.date(byAdding: .day, value: offset, to: date), s.isActiveDay(day) else { continue }
            let start = cal.startOfDay(for: day).addingTimeInterval(TimeInterval(s.startMin * 60))
            if start >= date { return start }
        }
        return date
    }

    private func updateStatus() {
        if let until = pausedUntil {
            statusLine.title = "⏸ Paused — \(clock(until.timeIntervalSinceNow)) left"
        } else if !Settings.shared.isActiveNow() {
            let when = nextActiveStart(after: Date())
            statusLine.title = "Sleeping — wakes in \(clock(when.timeIntervalSinceNow))"
        } else if buddy.isVisible {
            statusLine.title = "Buddy is on screen — click it!"
        } else {
            let remaining = nextNudge.timeIntervalSinceNow
            statusLine.title = remaining <= 0 ? "Nudging now…" : "Next buddy in \(clock(remaining))"
        }
    }

    @objc private func showNow() { buddy.show() }
    @objc private func snooze() {
        buddy.hideImmediately()
        nextNudge = Date().addingTimeInterval(15 * 60)
        updateStatus()
    }
    @objc private func pauseToday() {
        buddy.hideImmediately()
        let cal = Calendar.current
        pausedUntil = cal.startOfDay(for: Date().addingTimeInterval(86400)) // next midnight
        updateStatus()
    }
    @objc private func openPrefs() { prefs.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
