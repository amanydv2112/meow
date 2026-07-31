import Foundation
import MeowCore

@main
@MainActor
struct MeowRecorderSmokeTests {
    static func main() async {
        do {
            let granted: Bool
            switch PermissionsManager.microphoneState() {
            case .granted:
                granted = true
            case .notDetermined:
                granted = await PermissionsManager.requestMicrophone()
            case .denied:
                granted = false
            }

            guard granted else {
                print("MeowRecorderSmokeTests skipped: microphone permission is not granted for this terminal/app.")
                return
            }

            let recorder = AudioRecorder()
            let url = try recorder.start()
            try await Task.sleep(nanoseconds: 800_000_000)
            let result = try recorder.stop(minimumDuration: 0.1)
            try? FileManager.default.removeItem(at: url)

            guard result.duration >= 0.1, result.byteCount > 0 else {
                fatalError("Recorder produced an empty or too-short file.")
            }

            print("MeowRecorderSmokeTests passed: recorded \(result.byteCount) bytes for \(String(format: "%.2f", result.duration))s")
        } catch {
            fatalError("MeowRecorderSmokeTests failed: \(error.localizedDescription)")
        }
    }
}
