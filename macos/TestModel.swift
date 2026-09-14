import Foundation
func check(_ ok: Bool, _ name: String) { if !ok { fatalError(name) } }
let site = BrowserModel.entry(BrowserRequest(method: "add-site", url: "https://www.example.com/Page?a=1#part"))!
let page = BrowserModel.entry(BrowserRequest(method: "add-page", url: "https://www.example.com/Page?a=1#part"))!
check(site.value == "https://www.example.com", "site excludes path")
check(page.exact == true, "page stores exact flag")
check(BrowserModel.matches("https://example.com/other", site.value), "www site alias")
check(!BrowserModel.matches("https://www.example.com/Page?a=2#part", page.value, exact: true), "exact query")
check(!BrowserModel.matches("https://www.example.com/page?a=1#part", page.value, exact: true), "exact case")
check(!BrowserModel.matches("https://example.com.evil.org", site.value), "host suffix attack")
check(BrowserModel.parse("file:///tmp/test") == nil, "scheme")
check(BrowserModel.parse("https://user:pass@example.com") == nil, "credentials")
check(BrowserModel.entry(BrowserRequest(method: "delete", url: "https://example.com")) == nil, "method")
let old = try JSONDecoder().decode([Entry].self, from: Data("[{\"value\":\"https://example.com\",\"application\":false,\"enabled\":false}]".utf8))
check(old[0].exact == nil, "legacy migration")
let status = BrowserModel.status("https://example.com/a", old)
check(status["covered"] as? Bool == true && status["enabled"] as? Bool == false, "disabled status")
print("PASS: browser URL model and legacy settings")
