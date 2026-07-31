import Foundation
import EchoTypeCore

@main
struct EchoTypeCoreSmokeTests {
    static func main() throws {
        try testTranscriptionRequestUsesOpenAICompatibleEndpointAndMultipartBody()
        try testParseTranscriptSupportsJSONAndPlainText()
        try testPolishRequestUsesChatCompletionEndpoint()
        try testPolishRequestForbidsAssistantStyleAnswers()
        testPolishGuardRejectsLikelyAssistantAnswer()
        try testHistoryStorePersistsAndClearsRecords()
        print("EchoTypeCoreSmokeTests passed")
    }

    private static func testTranscriptionRequestUsesOpenAICompatibleEndpointAndMultipartBody() throws {
        let config = STTProviderConfig(
            baseURL: "https://example.test/v1",
            apiKey: "test-key",
            model: "custom-transcribe",
            language: "en",
            prompt: "Use product names correctly.",
            responseFormat: "text"
        )

        let request = try OpenAICompatibleSTTProvider.makeTranscriptionRequest(
            audioFileURL: URL(fileURLWithPath: "/tmp/sample.wav"),
            fileData: Data("audio".utf8),
            config: config,
            boundary: "Boundary"
        )

        expect(request.url?.absoluteString == "https://example.test/v1/audio/transcriptions")
        expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=Boundary")

        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        expect(body.contains("name=\"model\"\r\n\r\ncustom-transcribe"))
        expect(body.contains("name=\"language\"\r\n\r\nen"))
        expect(body.contains("name=\"prompt\"\r\n\r\nUse product names correctly."))
        expect(body.contains("name=\"file\"; filename=\"sample.wav\""))
    }

    private static func testParseTranscriptSupportsJSONAndPlainText() throws {
        let json = Data(#"{"text":"Hello there."}"#.utf8)
        try expect(try OpenAICompatibleSTTProvider.parseTranscript(data: json) == "Hello there.")

        let text = Data(" Plain transcript. \n".utf8)
        try expect(try OpenAICompatibleSTTProvider.parseTranscript(data: text) == "Plain transcript.")
    }

    private static func testPolishRequestUsesChatCompletionEndpoint() throws {
        let config = PolisherConfig(
            enabled: true,
            baseURL: "https://example.test/v1",
            apiKey: "test-key",
            model: "cleanup-model"
        )

        let request = try OpenAIChatTextPolisher.makePolishRequest(
            transcript: "um hello world",
            config: config
        )

        expect(request.url?.absoluteString == "https://example.test/v1/chat/completions")
        expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        expect(json?["model"] as? String == "cleanup-model")
        expect(json?["temperature"] as? Double == 0.1)
    }

    private static func testPolishRequestForbidsAssistantStyleAnswers() throws {
        let config = PolisherConfig(
            enabled: true,
            baseURL: "https://example.test/v1",
            apiKey: "test-key",
            model: "cleanup-model"
        )

        let request = try OpenAIChatTextPolisher.makePolishRequest(
            transcript: "i want to know one plus one",
            config: config
        )

        let json = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        let messages = json?["messages"] as? [[String: String]]
        let system = messages?.first(where: { $0["role"] == "system" })?["content"] ?? ""
        let user = messages?.first(where: { $0["role"] == "user" })?["content"] ?? ""

        expect(system.contains("Do not answer questions"))
        expect(system.contains("solve math"))
        expect(system.contains("not an assistant"))
        expect(user.contains("<dictation>"))
        expect(user.contains("i want to know one plus one"))
        expect(user.contains("not a request to answer"))
    }

    private static func testPolishGuardRejectsLikelyAssistantAnswer() {
        expect(
            OpenAIChatTextPolisher.acceptsPolishedText(
                original: "i want to know one plus one",
                polished: "One plus one equals two."
            ) == false
        )
        expect(
            OpenAIChatTextPolisher.acceptsPolishedText(
                original: "um i want to know one plus one",
                polished: "I want to know one plus one."
            ) == true
        )
    }

    private static func testHistoryStorePersistsAndClearsRecords() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("echotype-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteHistoryStore(databaseURL: directory.appendingPathComponent("history.sqlite"))
        let record = HistoryRecord(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            appName: "Notes",
            bundleIdentifier: "com.apple.Notes",
            rawTranscript: "hello",
            polishedText: "Hello.",
            provider: "OpenAI-compatible",
            model: "gpt-4o-mini-transcribe",
            duration: 1.2,
            status: .succeeded
        )

        try store.insert(record)
        let records = try store.recent(limit: 10)

        expect(records.count == 1)
        expect(records.first?.polishedText == "Hello.")
        expect(records.first?.appName == "Notes")

        try store.deleteAll()
        try expect(try store.recent(limit: 10).isEmpty)
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, file: StaticString = #file, line: UInt = #line) rethrows {
        guard try condition() else {
            fatalError("Expectation failed at \(file):\(line)")
        }
    }
}
