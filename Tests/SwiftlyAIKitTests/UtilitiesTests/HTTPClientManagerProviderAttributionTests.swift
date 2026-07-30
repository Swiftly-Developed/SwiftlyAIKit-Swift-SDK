import Testing
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
@testable import SwiftlyAIKit

/// Regression coverage for HTTP-level provider attribution.
///
/// `HTTPClientManager` is provider-agnostic — it has no way to infer a vendor from a URL.
/// Before this fix, both `performRequest` (used by `post` and `get`) and `streamPost`
/// called `mapHTTPError(status:message:provider:)` with a hardcoded `provider: .anthropic`,
/// so **every** HTTP-level failure from **every** provider was labelled "Anthropic":
/// a 404 from `api.openai.com` surfaced as `"Resource not found: endpoint (Anthropic)"`.
///
/// 8 of the 9 `mapHTTPError` arms carry the provider label (400 and 413 do not), so these
/// tests sweep all 8 rather than only the 404 that was originally reported.
///
/// These tests drive a real local HTTP server through the real `post` / `get` / `streamPost`
/// code path, so they fail against the pre-fix implementation and pass after it.
@Suite("HTTPClientManager provider attribution")
struct HTTPClientManagerProviderAttributionTests {

    // MARK: - The 8 provider-carrying status codes

    /// Every status whose `AIError` arm carries a `provider:` label.
    ///
    /// 400 (`.invalidRequest`) and 413 (`.requestTooLarge`) are deliberately excluded —
    /// those cases have no provider field, so there is nothing to mislabel.
    static let providerCarryingStatuses: [(code: UInt, name: String)] = [
        (401, "invalidAPIKey"),
        (403, "permissionDenied"),
        (404, "notFound"),
        (429, "rateLimitExceeded"),
        (500, "internalError"),
        (503, "serviceUnavailable"),
        (529, "overloaded"),
        (502, "providerError (default arm)")
    ]

    // MARK: - post()

    @Test(
        "post() attributes HTTP errors to the calling provider, not Anthropic",
        arguments: providerCarryingStatuses
    )
    func postAttributesErrorToCallingProvider(status: (code: UInt, name: String)) async throws {
        // Given a stub endpoint that fails with a provider-carrying status.
        // maxRetries: 0 so retryable statuses (429/5xx) don't incur exponential backoff.
        let manager = HTTPClientManager(maxRetries: 0)

        // When a NON-Anthropic provider makes the request.
        let thrown = try await withStubServer(statusCode: status.code) { server in
            await captureAIError {
                _ = try await manager.post(
                    provider: .openai,
                    url: server.url,
                    headers: [("Content-Type", "application/json")],
                    body: Data("{}".utf8)
                )
            }
        }

        // Then the error is attributed to that provider.
        let error = try #require(thrown, "expected an AIError for status \(status.code)")
        let attributed = try #require(
            attributedProvider(of: error),
            "status \(status.code) should map to a provider-carrying AIError (\(status.name)), got \(error)"
        )
        #expect(
            attributed == .openai,
            """
            status \(status.code) (\(status.name)) was attributed to \(attributed.displayName), \
            expected OpenAI. Rendered: \(error.localizedDescription)
            """
        )
        #expect(attributed != .anthropic, "provider must not fall back to the hardcoded .anthropic")
    }

    // MARK: - get()
    //
    // `get` shares `performRequest` with `post`, so it carried the identical defect.
    // This is the path `listModels` uses on every provider.

    @Test(
        "get() attributes HTTP errors to the calling provider, not Anthropic",
        arguments: providerCarryingStatuses
    )
    func getAttributesErrorToCallingProvider(status: (code: UInt, name: String)) async throws {
        let manager = HTTPClientManager(maxRetries: 0)

        let thrown = try await withStubServer(statusCode: status.code) { server in
            await captureAIError {
                _ = try await manager.get(
                    provider: .google,
                    url: server.url,
                    headers: [("Content-Type", "application/json")]
                )
            }
        }

        let error = try #require(thrown, "expected an AIError for status \(status.code)")
        let attributed = try #require(attributedProvider(of: error), "expected provider-carrying arm, got \(error)")
        #expect(
            attributed == .google,
            """
            status \(status.code) (\(status.name)) was attributed to \(attributed.displayName), \
            expected Google AI. Rendered: \(error.localizedDescription)
            """
        )
        #expect(attributed != .anthropic, "provider must not fall back to the hardcoded .anthropic")
    }

    // MARK: - streamPost()

    @Test(
        "streamPost() attributes HTTP errors to the calling provider, not Anthropic",
        arguments: providerCarryingStatuses
    )
    func streamPostAttributesErrorToCallingProvider(status: (code: UInt, name: String)) async throws {
        // streamPost does not route through executeWithRetry, so retries are irrelevant here.
        let manager = HTTPClientManager()

        let thrown = try await withStubServer(statusCode: status.code) { server in
            await captureAIError {
                let stream = manager.streamPost(
                    provider: .grok,
                    url: server.url,
                    headers: [("Content-Type", "application/json")],
                    body: Data("{}".utf8)
                )
                for try await _ in stream {}
            }
        }

        let error = try #require(thrown, "expected an AIError for status \(status.code)")
        let attributed = try #require(attributedProvider(of: error), "expected provider-carrying arm, got \(error)")
        #expect(
            attributed == .grok,
            """
            status \(status.code) (\(status.name)) was attributed to \(attributed.displayName), \
            expected xAI Grok. Rendered: \(error.localizedDescription)
            """
        )
        #expect(attributed != .anthropic, "provider must not fall back to the hardcoded .anthropic")
    }

    // MARK: - The originally reported symptom

    @Test("A 404 from a non-Anthropic provider no longer renders as \"(Anthropic)\"")
    func reportedSymptomIsFixed() async throws {
        let manager = HTTPClientManager(maxRetries: 0)

        let thrown = try await withStubServer(statusCode: 404) { server in
            await captureAIError {
                _ = try await manager.post(
                    provider: .openai,
                    url: server.url,
                    headers: [],
                    body: Data("{}".utf8)
                )
            }
        }

        let error = try #require(thrown)
        let rendered = error.localizedDescription

        // This is the exact string that misdirected a debugging session on 2026-07-23.
        #expect(!rendered.contains("(Anthropic)"), "OpenAI 404 must not be rendered as Anthropic: \(rendered)")
        #expect(rendered == "Resource not found: endpoint (OpenAI)", "unexpected rendering: \(rendered)")
    }

    @Test("Anthropic itself is still attributed correctly")
    func anthropicStillCorrect() async throws {
        let manager = HTTPClientManager(maxRetries: 0)

        let thrown = try await withStubServer(statusCode: 404) { server in
            await captureAIError {
                _ = try await manager.post(
                    provider: .anthropic,
                    url: server.url,
                    headers: [],
                    body: Data("{}".utf8)
                )
            }
        }

        let error = try #require(thrown)
        #expect(attributedProvider(of: error) == .anthropic)
        #expect(error.localizedDescription == "Resource not found: endpoint (Anthropic)")
    }

    // MARK: - Structural guard
    //
    // The behavioural tests above only cover the statuses they happen to exercise.
    // This guard is what goes red if someone reintroduces the hardcoded shortcut.

    @Test("HTTPClientManager contains no hardcoded provider literal at its mapHTTPError call sites")
    func noHardcodedProviderLiteralSurvives() throws {
        let code = try Self.httpClientManagerCode()

        // The parameter *declaration* is `provider: ProviderType = .anthropic`, which does not
        // match this substring. Any `provider: .anthropic` argument literal in real code does.
        #expect(
            !code.contains("provider: .anthropic"),
            "HTTPClientManager must not hardcode a provider literal — thread the caller's provider through instead."
        )

        // Every mapHTTPError *call* must forward the threaded parameter.
        let callSites = code
            .components(separatedBy: .newlines)
            .filter { $0.contains("mapHTTPError(") && !$0.contains("func mapHTTPError(") }
        #expect(callSites.count >= 2, "expected the post and streamPost call sites — found \(callSites.count)")
        for site in callSites {
            #expect(
                site.contains("provider: provider"),
                "a mapHTTPError call does not forward the threaded provider: \(site.trimmingCharacters(in: .whitespaces))"
            )
        }
    }

    @Test("post, get and streamPost all expose a provider parameter")
    func publicSurfaceExposesProvider() throws {
        let source = try Self.httpClientManagerCode()
        for method in ["public func post(", "public func get(", "public func streamPost("] {
            let after = try #require(source.range(of: method)).upperBound
            let signature = String(source[after...].prefix(while: { $0 != ")" }))
            #expect(
                signature.contains("provider: ProviderType"),
                "\(method) must accept a provider so HTTP errors can be attributed correctly"
            )
        }
    }

    /// `HTTPClientManager.swift` with comment lines stripped.
    ///
    /// Comments are excluded so the structural guards inspect real code only — the file's
    /// own usage example legitimately shows `provider: .anthropic` for an Anthropic URL.
    private static func httpClientManagerCode() throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // UtilitiesTests
            .deletingLastPathComponent()   // SwiftlyAIKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
        let file = repoRoot
            .appendingPathComponent("Sources/SwiftlyAIKit/Utilities/HTTPClientManager.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Runs `body` and returns the `AIError` it threw, if any.
    private func captureAIError(_ body: () async throws -> Void) async -> AIError? {
        do {
            try await body()
            return nil
        } catch let error as AIError {
            return error
        } catch {
            return nil
        }
    }

    /// Extracts the provider label from the `AIError` arms that carry one.
    ///
    /// Returns `nil` for arms without a provider field (400, 413), which is what makes
    /// the `#require` above a meaningful assertion rather than a silent pass.
    private func attributedProvider(of error: AIError) -> ProviderType? {
        switch error {
        case .invalidAPIKey(let provider, _): return provider
        case .permissionDenied(let provider, _): return provider
        case .notFound(_, let provider): return provider
        case .rateLimitExceeded(let provider, _): return provider
        case .internalError(let provider, _): return provider
        case .serviceUnavailable(let provider): return provider
        case .overloaded(let provider): return provider
        case .providerError(let provider, _, _): return provider
        default: return nil
        }
    }
}

// MARK: - Local HTTP stub server

/// A minimal single-response HTTP server used to drive real `HTTPClientManager` requests.
///
/// The repo convention is to unit-test provider helpers directly rather than inject a mock
/// HTTP client (providers take a concrete `HTTPClientManager`). Provider *attribution*,
/// however, is a property of the HTTP layer itself, so it needs a real request/response
/// round trip — hence a loopback server rather than a mock.
private struct StubHTTPServer {
    private let channel: Channel

    /// One shared group for every stub server.
    ///
    /// A per-server `MultiThreadedEventLoopGroup` plus a blocking `syncShutdownGracefully()`
    /// deadlocks: swift-testing runs these cases in parallel, and the blocking shutdown
    /// starves the cooperative thread pool. Share one group and never block on it.
    private static let sharedGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)

    var url: String {
        let port = channel.localAddress?.port ?? 0
        return "http://127.0.0.1:\(port)/v1/endpoint"
    }

    static func start(statusCode: UInt) async throws -> Self {
        let bootstrap = ServerBootstrap(group: sharedGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(FixedStatusHandler(statusCode: statusCode))
                }
            }

        let channel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()
        return Self(channel: channel)
    }

    /// Closes the listening socket without blocking the calling thread.
    func shutdown() async {
        try? await channel.close().get()
    }
}

/// Runs `body` against a stub endpoint that always fails with `statusCode`,
/// closing the listening socket afterwards on both the success and throwing paths.
private func withStubServer<T>(
    statusCode: UInt,
    _ body: (StubHTTPServer) async throws -> T
) async throws -> T {
    let server = try await StubHTTPServer.start(statusCode: statusCode)
    do {
        let result = try await body(server)
        await server.shutdown()
        return result
    } catch {
        await server.shutdown()
        throw error
    }
}

/// Responds to any request with a fixed status code and a JSON error body.
private final class FixedStatusHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let statusCode: UInt

    init(statusCode: UInt) {
        self.statusCode = statusCode
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard case .end = unwrapInboundIn(data) else { return }

        let body = context.channel.allocator.buffer(string: #"{"error":{"message":"stubbed failure"}}"#)
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        headers.add(name: "Content-Length", value: "\(body.readableBytes)")
        headers.add(name: "Connection", value: "close")

        let head = HTTPResponseHead(
            version: .http1_1,
            status: HTTPResponseStatus(statusCode: Int(statusCode)),
            headers: headers
        )

        context.write(wrapOutboundOut(.head(head)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
            context.close(promise: nil)
        }
    }
}
