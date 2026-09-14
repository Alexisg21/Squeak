import Foundation
guard CommandLine.arguments.count == 2 else { exit(1) }
let app = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let host = app.appendingPathComponent("Contents/MacOS/SqueakBrowserHost")
guard FileManager.default.isExecutableFile(atPath: host.path) else { exit(1) }
let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
let manifest: [String: Any] = ["name": "com.squeak.desktop", "description": "Connexion locale à Squeak", "path": host.path, "type": "stdio", "allowed_origins": [BrowserModel.origin]]
do {
    let bytes = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    for browser in ["Google/Chrome", "Microsoft Edge"] {
        let folder = support.appendingPathComponent(browser).appendingPathComponent("NativeMessagingHosts")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try bytes.write(to: folder.appendingPathComponent("com.squeak.desktop.json"), options: .atomic)
    }
    print("Liaison Chrome et Edge installée pour ce compte macOS.")
} catch { fputs("Installation navigateur impossible : \(error)\n", stderr); exit(1) }
