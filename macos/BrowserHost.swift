import Foundation

enum HostError: Error { case invalid }
func readExactly(_ count: Int) throws -> Data {
    var result = Data()
    while result.count < count {
        let next = FileHandle.standardInput.readData(ofLength: count - result.count)
        if next.isEmpty { throw HostError.invalid }; result.append(next)
    }
    return result
}
func response(_ value: [String: Any]) {
    guard let bytes = try? JSONSerialization.data(withJSONObject: value) else { return }
    let n = UInt32(bytes.count)
    let header = Data([UInt8(n & 255), UInt8((n >> 8) & 255), UInt8((n >> 16) & 255), UInt8((n >> 24) & 255)])
    FileHandle.standardOutput.write(header + bytes)
}
func request() throws -> [String: Any] {
    guard CommandLine.arguments.dropFirst().first == BrowserModel.origin else { throw HostError.invalid }
    let header = try readExactly(4)
    let n = header.enumerated().reduce(UInt32(0)) { $0 | (UInt32($1.element) << ($1.offset * 8)) }
    guard n > 0 && n <= 32768 else { throw HostError.invalid }
    let message = try JSONDecoder().decode(BrowserRequest.self, from: readExactly(Int(n)))
    guard BrowserModel.parse(message.url) != nil, ["status", "add-site", "add-page"].contains(message.method) else { throw HostError.invalid }
    if message.method == "status" {
        let file = BrowserModel.directory.appendingPathComponent("items.json")
        let entries = FileManager.default.fileExists(atPath: file.path) ? try JSONDecoder().decode([Entry].self, from: Data(contentsOf: file)) : []
        return BrowserModel.status(message.url, entries)
    }
    try FileManager.default.createDirectory(at: BrowserModel.inbox, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let file = BrowserModel.inbox.appendingPathComponent(UUID().uuidString + ".squeakrequest")
    let reply = file.appendingPathExtension("reply")
    defer { try? FileManager.default.removeItem(at: file); try? FileManager.default.removeItem(at: reply) }
    try JSONEncoder().encode(message).write(to: file, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard app.pathExtension == "app" else { throw HostError.invalid }
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-a", app.path, file.path]
    process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
    try process.run(); process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw HostError.invalid }
    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
        if let data = try? Data(contentsOf: reply), let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] { return result }
        Thread.sleep(forTimeInterval: 0.05)
    }
    return ["ok": false, "error": "Squeak n’a pas confirmé l’ajout. Ouvrez l’application puis réessayez."]
}
do { response(try request()) }
catch { response(["ok": false, "error": "Requête invalide ou liaison macOS indisponible."]) }
