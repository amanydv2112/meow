import AVFoundation
import Foundation

public struct RecordingResult: Equatable, Sendable {
    public var fileURL: URL
    public var duration: TimeInterval
    public var byteCount: Int64

    public init(fileURL: URL, duration: TimeInterval, byteCount: Int64) {
        self.fileURL = fileURL
        self.duration = duration
        self.byteCount = byteCount
    }
}

public final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let levelMeter = AudioLevelMeter()
    private var audioSink: AudioFileSink?
    private var recordingURL: URL?
    private var startedAt: Date?

    public private(set) var isRecording = false

    public init() {}

    public func setLevelHandler(_ handler: AudioLevelHandler?) {
        levelMeter.setHandler(handler)
    }

    public func start() throws -> URL {
        guard !isRecording else {
            return recordingURL ?? temporaryRecordingURL()
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let url = temporaryRecordingURL()
        let sink = try AudioFileSink(url: url, settings: format.settings)
        audioSink = sink
        recordingURL = url
        startedAt = Date()

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            sink.write(buffer)
            self.levelMeter.process(buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
        return url
    }

    public func stop(minimumDuration: TimeInterval = 0.3) throws -> RecordingResult {
        guard isRecording, let recordingURL else {
            throw FlowError.recordingTooShort
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioSink?.close()
        audioSink = nil
        isRecording = false

        let duration = Date().timeIntervalSince(startedAt ?? Date())
        startedAt = nil
        self.recordingURL = nil

        guard duration >= minimumDuration else {
            try? FileManager.default.removeItem(at: recordingURL)
            throw FlowError.recordingTooShort
        }

        let values = try recordingURL.resourceValues(forKeys: [.fileSizeKey])
        return RecordingResult(
            fileURL: recordingURL,
            duration: duration,
            byteCount: Int64(values.fileSize ?? 0)
        )
    }

    private func temporaryRecordingURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("echotype-\(UUID().uuidString)")
            .appendingPathExtension("wav")
    }
}

public typealias AudioLevelHandler = @Sendable (Double) -> Void

private final class AudioLevelMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: AudioLevelHandler?
    private var lastEmitNanoseconds: UInt64 = 0

    func setHandler(_ handler: AudioLevelHandler?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        let now = DispatchTime.now().uptimeNanoseconds
        let localHandler: AudioLevelHandler?

        lock.lock()
        guard handler != nil, now - lastEmitNanoseconds >= 33_000_000 else {
            lock.unlock()
            return
        }
        lastEmitNanoseconds = now
        localHandler = handler
        lock.unlock()

        localHandler?(Self.normalizedLevel(from: buffer))
    }

    private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameLength > 0, channelCount > 0 else { return 0 }

        var squareSum = 0.0
        var sampleCount = 0

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = Double(samples[frame])
                squareSum += sample * sample
            }
            sampleCount += frameLength
        }

        guard sampleCount > 0 else { return 0 }

        let rms = sqrt(squareSum / Double(sampleCount))
        guard rms > 0 else { return 0 }

        let decibels = 20 * log10(rms)
        let normalized = min(max((decibels + 55) / 55, 0), 1)
        return pow(normalized, 0.75)
    }
}

private final class AudioFileSink: @unchecked Sendable {
    private let lock = NSLock()
    private var audioFile: AVAudioFile?

    init(url: URL, settings: [String: Any]) throws {
        audioFile = try AVAudioFile(forWriting: url, settings: settings)
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        do {
            try audioFile?.write(from: buffer)
        } catch {
            NSLog("EchoType audio write failed: \(error.localizedDescription)")
        }
    }

    func close() {
        lock.lock()
        audioFile = nil
        lock.unlock()
    }
}
