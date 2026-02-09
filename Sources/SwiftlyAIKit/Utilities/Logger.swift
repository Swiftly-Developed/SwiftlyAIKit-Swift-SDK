import Foundation
#if canImport(OSLog)
import OSLog
#endif

// MARK: - Log Level

/// Logging severity levels for SwiftlyAIKit
///
/// ## Topics
///
/// ### Levels
/// - ``debug``
/// - ``info``
/// - ``warning``
/// - ``error``
///
/// ## See Also
/// - <doc:MonitoringAndDebugging>
public enum LogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var symbol: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }
}

// MARK: - Log Context

/// Context for correlating related log entries across a request lifecycle
public struct LogContext: Sendable {
    /// Unique identifier for this request (8-character hex string)
    public let requestId: String

    /// The AI provider being used (e.g., "anthropic", "openai")
    public let provider: String?

    /// The model being used (e.g., "claude-sonnet-4-5")
    public let model: String?

    /// The operation being performed (e.g., "sendMessage", "streamMessage")
    public let operation: String

    /// When this context was created
    public let startTime: Date

    public init(
        requestId: String = String(UUID().uuidString.prefix(8)).lowercased(),
        provider: String? = nil,
        model: String? = nil,
        operation: String
    ) {
        self.requestId = requestId
        self.provider = provider
        self.model = model
        self.operation = operation
        self.startTime = Date()
    }

    /// Time elapsed since context creation
    public var elapsed: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    /// Formatted elapsed time string (e.g., "123.45ms")
    public var elapsedFormatted: String {
        String(format: "%.2fms", elapsed * 1000)
    }

    /// Create a child context with the same request ID but different operation
    public func child(operation: String) -> Self {
        Self(
            requestId: requestId,
            provider: provider,
            model: model,
            operation: operation
        )
    }
}

// MARK: - Log Entry

/// A single log entry with all associated metadata
public struct LogEntry: Sendable {
    public let level: LogLevel
    public let message: String
    public let context: LogContext?
    public let metadata: [String: String]
    public let timestamp: Date
    public let file: String
    public let function: String
    public let line: Int

    public init(
        level: LogLevel,
        message: String,
        context: LogContext? = nil,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.level = level
        self.message = message
        self.context = context
        self.metadata = metadata
        self.timestamp = Date()
        self.file = file
        self.function = function
        self.line = line
    }

    /// Source file name without path
    public var fileName: String {
        (file as NSString).lastPathComponent
    }
}

// MARK: - Logger Protocol

/// Protocol for log output implementations
public protocol AILogger: Sendable {
    func log(_ entry: LogEntry)
}

// MARK: - OSLog Logger (Apple platforms)

#if canImport(OSLog)
/// Logger that outputs to Apple's unified logging system (Console.app)
public final class OSLogLogger: AILogger, @unchecked Sendable {
    private let logger: os.Logger

    public init(subsystem: String = "com.swiftlyai", category: String = "AIKit") {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    public func log(_ entry: LogEntry) {
        let contextInfo = entry.context.map { "[\($0.requestId)] " } ?? ""
        let elapsedInfo = entry.context.map { " (\($0.elapsedFormatted))" } ?? ""
        let metadataInfo = formatMetadata(entry.metadata)
        let message = "\(contextInfo)\(entry.message)\(elapsedInfo)\(metadataInfo)"

        switch entry.level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }

    private func formatMetadata(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty else { return "" }
        let pairs = metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        return " | \(pairs)"
    }
}
#endif

// MARK: - Print Logger (Linux/fallback)

/// Logger that outputs to stdout using print()
public final class PrintLogger: AILogger, @unchecked Sendable {
    public static let shared = PrintLogger()

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public init() {}

    public func log(_ entry: LogEntry) {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let contextInfo = entry.context.map { "[\($0.requestId)] " } ?? ""
        let elapsedInfo = entry.context.map { " (\($0.elapsedFormatted))" } ?? ""
        let metadataInfo = formatMetadata(entry.metadata)

        print("\(entry.level.symbol) [\(timestamp)] [SwiftlyAI] \(contextInfo)\(entry.message)\(elapsedInfo)\(metadataInfo)")
    }

    private func formatMetadata(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty else { return "" }
        let pairs = metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        return "\n  metadata: {\(pairs)}"
    }
}

// MARK: - Logging Manager

/// Thread-safe logging manager for SwiftlyAIKit
public actor LoggingManager {
    /// Shared instance for global logging
    public static let shared = LoggingManager()

    private var logger: AILogger?
    private var minimumLevel: LogLevel = .debug
    private var isEnabled: Bool = false

    /// Configure the logging system
    /// - Parameters:
    ///   - logger: The logger implementation to use
    ///   - minimumLevel: Minimum log level to output (default: .debug)
    ///   - enabled: Whether logging is enabled (default: true)
    public func configure(logger: AILogger, minimumLevel: LogLevel = .debug, enabled: Bool = true) {
        self.logger = logger
        self.minimumLevel = minimumLevel
        self.isEnabled = enabled
    }

    /// Log a message with the given level and context
    public func log(
        _ level: LogLevel,
        _ message: String,
        context: LogContext? = nil,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled, level >= minimumLevel, let logger = logger else { return }

        let entry = LogEntry(
            level: level,
            message: message,
            context: context,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        logger.log(entry)
    }

    /// Check if logging is currently enabled
    public var loggingEnabled: Bool {
        isEnabled && logger != nil
    }
}

// MARK: - Convenience Logging Functions

/// Log a message asynchronously through the shared LoggingManager
/// - Parameters:
///   - level: The severity level of the log
///   - message: The log message
///   - context: Optional context for request correlation
///   - metadata: Additional key-value metadata
public func aiLog(
    _ level: LogLevel,
    _ message: String,
    context: LogContext? = nil,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) async {
    await LoggingManager.shared.log(
        level,
        message,
        context: context,
        metadata: metadata,
        file: file,
        function: function,
        line: line
    )
}

/// Convenience functions for common log levels
public func aiDebug(
    _ message: String,
    context: LogContext? = nil,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) async {
    await aiLog(.debug, message, context: context, metadata: metadata, file: file, function: function, line: line)
}

public func aiInfo(
    _ message: String,
    context: LogContext? = nil,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) async {
    await aiLog(.info, message, context: context, metadata: metadata, file: file, function: function, line: line)
}

public func aiWarning(
    _ message: String,
    context: LogContext? = nil,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) async {
    await aiLog(.warning, message, context: context, metadata: metadata, file: file, function: function, line: line)
}

public func aiError(
    _ message: String,
    context: LogContext? = nil,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) async {
    await aiLog(.error, message, context: context, metadata: metadata, file: file, function: function, line: line)
}
