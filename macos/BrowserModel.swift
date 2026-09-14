import Foundation

struct Entry: Codable {
    var value: String
    var application: Bool
    var enabled: Bool = true
    // Optional so lists saved by 0.1 remain compatible.
    var exact: Bool? = nil
}
struct BrowserRequest: Codable { let method: String; let url: String }
enum BrowserModel {
    static let origin = "chrome-extension://dibbmpledhimhagdgbebcjbphdikbcck/"
    static var directory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Squeak") }
    static var inbox: URL { directory.appendingPathComponent("browser-inbox") }
    static func parse(_ value: String) -> URLComponents? {
        guard value.utf8.count <= 8192, !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let url = URLComponents(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, host.contains("."), url.user == nil, url.password == nil else { return nil }
        return url
    }
    static func entry(_ request: BrowserRequest) -> Entry? {
        guard var url = parse(request.url), ["add-site", "add-page"].contains(request.method) else { return nil }
        if request.method == "add-site" { url.path = ""; url.query = nil; url.fragment = nil }
        guard let value = url.string else { return nil }
        return Entry(value: value, application: false, exact: request.method == "add-page")
    }
    static func matches(_ current: String, _ expected: String, exact: Bool = false) -> Bool {
        guard let a = parse(current), let b = parse(expected), let ah = a.host, let bh = b.host else { return false }
        func host(_ s: String) -> String { let lower = s.lowercased(); return lower.hasPrefix("www.") ? String(lower.dropFirst(4)) : lower }
        guard (exact ? ah.lowercased() == bh.lowercased() : host(ah) == host(bh)), a.port == b.port else { return false }
        if exact { return a.percentEncodedPath == b.percentEncodedPath && a.percentEncodedQuery == b.percentEncodedQuery && a.percentEncodedFragment == b.percentEncodedFragment }
        let path = b.percentEncodedPath == "/" ? "" : b.percentEncodedPath
        return (path.isEmpty || a.percentEncodedPath == path || a.percentEncodedPath.hasPrefix(path + "/")) && (b.query == nil || b.percentEncodedQuery == a.percentEncodedQuery) && (b.fragment == nil || b.percentEncodedFragment == a.percentEncodedFragment)
    }
    static func status(_ url: String, _ entries: [Entry]) -> [String: Any] {
        let matching = entries.filter { !$0.application && matches(url, $0.value, exact: $0.exact == true) }
        let site = matching.contains { $0.exact != true && (parse($0.value)?.path ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty && parse($0.value)?.query == nil && parse($0.value)?.fragment == nil }
        return ["ok": true, "covered": !matching.isEmpty, "enabled": matching.contains { $0.enabled }, "siteAdded": site, "pageAdded": matching.contains { $0.exact == true }]
    }
}
