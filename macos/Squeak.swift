import Cocoa
import ApplicationServices

final class Squeak: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var rows = NSStackView()
    var input = NSTextField()
    var status = NSTextField(labelWithString: "P + Suppr avant · Services Finder : Intégrer à Squeak")
    var entries: [Entry] = []
    var pDown = false
    var closing = false
    var globalMonitor: Any?
    var localMonitor: Any?
    var tray: NSStatusItem!
    let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Squeak/items.json")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let data = try? Data(contentsOf: config), let saved = try? JSONDecoder().decode([Entry].self, from: data) { entries = saved }
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 560), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Squeak"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 1)
        window.minSize = NSSize(width: 650, height: 420)
        let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 18; stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24), stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -24)])
        let title = NSTextField(labelWithString: "SQUEAK")
        title.font = .boldSystemFont(ofSize: 32); title.textColor = NSColor(calibratedRed: 0.83, green: 0.64, blue: 0.31, alpha: 1)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(NSTextField(labelWithString: "Applications et sites à fermer"))
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.translatesAutoresizingMaskIntoConstraints = false
        rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 10; rows.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = rows
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        rows.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        let add = NSStackView(); add.orientation = .horizontal
        input.placeholderString = "instagram.com ou chemin vers une application .app"
        add.addArrangedSubview(input); add.addArrangedSubview(button("Ajouter", #selector(addInput)))
        stack.addArrangedSubview(add); add.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let actions = NSStackView(views: [button("Fermer maintenant", #selector(closeNow)), button("Autoriser le raccourci", #selector(requestAccess))])
        stack.addArrangedSubview(actions)
        status.lineBreakMode = .byWordWrapping; status.maximumNumberOfLines = 3; stack.addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        tray = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        tray.button?.title = "S"
        let menu = NSMenu(); menu.addItem(withTitle: "Ouvrir Squeak", action: #selector(show), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quitter Squeak", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        tray.menu = menu
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] in self?.key($0) }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in self?.key(event); return event }
        render(); window.center(); show()
    }
    func button(_ title: String, _ action: Selector) -> NSButton { let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; return b }
    @objc func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func requestAccess() { let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary; _ = AXIsProcessTrustedWithOptions(options); status.stringValue = "Autorise Squeak dans Réglages système > Confidentialité > Accessibilité, puis relance Squeak." }
    func key(_ e: NSEvent) {
        if e.keyCode == 35 { pDown = e.type == .keyDown }
        if e.keyCode == 117 && e.type == .keyDown && pDown && !e.isARepeat { closeNow() }
    }
    @discardableResult func save() -> Bool {
        do { try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(entries).write(to: config, options: .atomic); return true }
        catch { status.stringValue = "Sauvegarde impossible : \(error.localizedDescription)"; return false }
    }
    func render() {
        rows.arrangedSubviews.forEach { rows.removeArrangedSubview($0); $0.removeFromSuperview() }
        for (index, entry) in entries.enumerated() {
            let label = entry.application ? URL(fileURLWithPath: entry.value).deletingPathExtension().lastPathComponent : entry.value
            let check = NSButton(checkboxWithTitle: label + (entry.exact == true ? " (page exacte)" : ""), target: self, action: #selector(toggle(_:))); check.tag = index; check.state = entry.enabled ? .on : .off
            let remove = button("Retirer", #selector(removeEntry(_:))); remove.tag = index
            rows.addArrangedSubview(NSStackView(views: [check, remove]))
        }
    }
    @objc func toggle(_ b: NSButton) { entries[b.tag].enabled = b.state == .on; save() }
    @objc func removeEntry(_ b: NSButton) { entries.remove(at: b.tag); save(); render() }
    @objc func addInput() { if add(input.stringValue) { input.stringValue = "" } }
    @discardableResult func add(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let file = URL(fileURLWithPath: (value as NSString).expandingTildeInPath)
        var entry: Entry
        if file.pathExtension.lowercased() == "app", FileManager.default.fileExists(atPath: file.path) { entry = Entry(value: file.path, application: true) }
        else if file.pathExtension.lowercased() == "webloc", let data = try? Data(contentsOf: file), let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any], let url = plist["URL"] as? String { return add(url) }
        else {
            guard let url = URL(string: value.contains("://") ? value : "https://" + value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, host.contains("."), url.user == nil, url.password == nil else { status.stringValue = "Choisis une application .app ou une adresse web valide."; return false }
            entry = Entry(value: url.absoluteString, application: false)
        }
        if !entries.contains(where: { $0.value == entry.value }) { entries.append(entry); save(); render() }
        status.stringValue = "Intégré à Squeak."; return true
    }
    func browserRequest(_ path: String) {
        let file = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        guard file.deletingLastPathComponent() == BrowserModel.inbox.standardizedFileURL.resolvingSymlinksInPath(), file.pathExtension == "squeakrequest",
              UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil else { return }
        var result: [String: Any] = ["ok": false, "error": "Ajout refusé."]
        if let data = try? Data(contentsOf: file), data.count <= 32768,
           let request = try? JSONDecoder().decode(BrowserRequest.self, from: data), let entry = BrowserModel.entry(request) {
            let previous = entries
            if !entries.contains(where: { !$0.application && $0.value == entry.value && ($0.exact == true) == (entry.exact == true) }) { entries.append(entry) }
            if save() { render(); result = BrowserModel.status(request.url, entries); status.stringValue = "Ajout reçu du navigateur." }
            else { entries = previous; result = ["ok": false, "error": "Sauvegarde impossible dans Squeak."] }
        }
        if let data = try? JSONSerialization.data(withJSONObject: result) { try? data.write(to: file.appendingPathExtension("reply"), options: .atomic) }
    }
    @objc func integrate(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        for url in urls { add(url.path) }; show()
        if urls.isEmpty { error.pointee = "Aucun fichier compatible reçu." }
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) { for file in filenames { if URL(fileURLWithPath: file).pathExtension == "squeakrequest" { browserRequest(file) } else { add(file) } }; show(); sender.reply(toOpenOrPrint: .success) }
    func matches(_ current: String, _ expected: String) -> Bool {
        guard let a = URLComponents(string: current), let b = URLComponents(string: expected), let ah = a.host, let bh = b.host else { return false }
        func host(_ s: String) -> String { let lower = s.lowercased(); return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower }
        guard host(ah) == host(bh), a.port == b.port else { return false }
        let path = b.path == "/" ? "" : b.path
        return (path.isEmpty || a.path == path || a.path.hasPrefix(path + "/")) && (b.query == nil || b.query == a.query) && (b.fragment == nil || b.fragment == a.fragment)
    }
    @objc func closeNow() {
        guard !closing else { return }; closing = true; defer { closing = false }
        var messages: [String] = []
        let selected = entries.filter { $0.enabled }
        let sites = selected.filter { !$0.application }
        if !sites.isEmpty, let front = NSWorkspace.shared.frontmostApplication, let id = front.bundleIdentifier {
            let browser = ["com.apple.Safari", "com.google.Chrome", "com.microsoft.edgemac"].contains(id)
            if browser {
                let tab = id == "com.apple.Safari" ? "current tab of front window" : "active tab of front window"
                var err: NSDictionary?
                let address = NSAppleScript(source: "tell application id \"\(id)\" to get URL of \(tab)")?.executeAndReturnError(&err).stringValue
                if let address = address, sites.contains(where: { BrowserModel.matches(address, $0.value, exact: $0.exact == true) }), NSWorkspace.shared.frontmostApplication?.processIdentifier == front.processIdentifier {
                    // Recheck the URL in the same script that closes to avoid closing a changed tab.
                    let escaped = address.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    _ = NSAppleScript(source: "tell application id \"\(id)\"\nif URL of \(tab) is \"\(escaped)\" then close \(tab)\nend tell")?.executeAndReturnError(&err)
                    messages.append(err == nil ? "Fermeture de l’onglet demandée." : "Autorisation navigateur nécessaire.")
                } else { messages.append(err == nil ? "Aucun site correspondant." : "Autorise l’automatisation du navigateur dans les réglages macOS.") }
            } else { messages.append("Place le site au premier plan avant P + Suppr avant.") }
        }
        for entry in selected where entry.application {
            let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.path == entry.value && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            for app in apps { _ = app.terminate() }
            messages.append(apps.isEmpty ? "Application absente." : "Fermeture demandée ; les confirmations de sauvegarde restent actives.")
        }
        status.stringValue = messages.isEmpty ? "Coche un élément à fermer." : messages.joined(separator: " ")
    }
}
let app = NSApplication.shared
let delegate = Squeak()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
