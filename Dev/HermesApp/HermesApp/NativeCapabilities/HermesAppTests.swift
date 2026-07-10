#if canImport(Testing)
import Testing
import Foundation

@Suite("Helper validations")
struct HelperValidationTests {

    // Simple URL validation similar to SetupView.connect()
    func isValidHTTPURL(_ string: String) -> Bool {
        guard let url = URL(string: string), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    @Test("Valid HTTP URL")
    func validHTTPURL() async throws {
        #expect(isValidHTTPURL("https://example.com"))
        #expect(isValidHTTPURL("http://localhost:9119"))
    }

    @Test("Invalid URL inputs")
    func invalidURLs() async throws {
        #expect(isValidHTTPURL("" ) == false)
        #expect(isValidHTTPURL("ftp://example.com") == false)
        #expect(isValidHTTPURL("not a url") == false)
    }
}

@Suite("Header composition")
struct HeaderCompositionTests {

    func buildHeaders(token: String?, cfId: String?, cfSecret: String?) -> [String: String] {
        var headers: [String: String] = [:]
        if let token, !token.isEmpty { headers["Authorization"] = "Bearer \(token)" }
        if let cfId, !cfId.isEmpty {
            headers["CF-Access-Client-Id"] = cfId
            headers["CF-Access-Client-Secret"] = cfSecret ?? ""
        }
        return headers
    }

    @Test("No headers when empty")
    func noHeaders() async throws {
        let h = buildHeaders(token: nil, cfId: nil, cfSecret: nil)
        #expect(h.isEmpty)
    }

    @Test("Auth only")
    func authOnly() async throws {
        let h = buildHeaders(token: "abc", cfId: nil, cfSecret: nil)
        #expect(h["Authorization"] == "Bearer abc")
        #expect(h["CF-Access-Client-Id"] == nil)
    }

    @Test("Cloudflare and auth")
    func cloudflareAndAuth() async throws {
        let h = buildHeaders(token: "tok", cfId: "id", cfSecret: "sec")
        #expect(h["Authorization"] == "Bearer tok")
        #expect(h["CF-Access-Client-Id"] == "id")
        #expect(h["CF-Access-Client-Secret"] == "sec")
    }
}

@Suite("Configuration semantics")
struct ConfigSemanticsTests {
    struct MockConfig { var serverURL: String = ""; var isConfigured: Bool { !serverURL.isEmpty } }

    @Test("isConfigured toggles with serverURL")
    func configuredToggle() async throws {
        var cfg = MockConfig()
        #expect(cfg.isConfigured == false)
        cfg.serverURL = "https://example.com"
        #expect(cfg.isConfigured == true)
    }
}
#endif
