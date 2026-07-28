# EchoType

Open-source Wispr Flow alternative for macOS with bring-your-own API key speech-to-text.

EchoType is a native macOS menu bar app for push-to-talk dictation. Hold `fn`, speak, release, and EchoType transcribes with an OpenAI-compatible speech-to-text endpoint, optionally cleans up punctuation/casing, then pastes the text into the active app.

> v0.1.0 is unsigned/ad-hoc signed and not notarized. macOS may block the first launch until you choose **Open Anyway** in System Settings.

EchoType is not affiliated with Wispr Flow.

## Demo

Screenshot and short demo GIF coming with the first GitHub release.

## Features

- Native macOS menu bar app.
- Press-and-hold `fn` dictation.
- Bring your own OpenAI-compatible STT provider.
- Default STT model: `gpt-4o-mini-transcribe`.
- Optional cleanup through an OpenAI-compatible chat endpoint.
- Automatic paste into the active app, with clipboard restoration when possible.
- Local SQLite transcript history that can be disabled or cleared.
- No accounts, telemetry, sync, billing, or cloud storage by EchoType.

## Install From Release ZIP

1. Download `EchoType-macOS-arm64.zip` from the GitHub Releases page.
2. Unzip it and move `EchoType.app` to `/Applications`.
3. Launch EchoType. If macOS blocks it, open **System Settings > Privacy & Security** and choose **Open Anyway**.
4. Grant Microphone permission for recording.
5. Grant Accessibility permission so EchoType can listen for the global shortcut and paste into other apps.
6. Open EchoType settings from the menu bar icon and add your provider details:
   - **Base URL:** use `https://api.openai.com/v1` for OpenAI, or your OpenAI-compatible provider URL.
   - **API key:** paste your provider API key. EchoType uses a BYOK model, so no key is bundled.
   - **STT model:** use `gpt-4o-mini-transcribe` for OpenAI, or the transcription model name from your provider.
   - **Language code:** optional, for example `en`. Leave blank for auto-detect when supported.
   - **Provider prompt:** optional vocabulary/context hints for transcription.
   - **Response format:** keep `text` unless your provider requires `json`.
   - **Cleanup model:** optional OpenAI-compatible chat model used to fix punctuation/casing before paste.
7. Click **Save** in Settings, then hold `fn`, speak, and release to test dictation.

## Build From Source

Requirements:

- macOS 14 or newer.
- Xcode Command Line Tools.
- Apple Silicon Mac for the default `arm64` release artifact.

Build:

```bash
swift build
```

Run during development:

```bash
swift run EchoType
```

Build the `.app` bundle and release ZIP:

```bash
./scripts/build-app.sh
open dist/EchoType.app
```

The script creates:

- `dist/EchoType.app`
- `dist/EchoType-macOS-arm64.zip`
- `dist/EchoType-macOS-arm64.zip.sha256`

## Provider Setup

Default transcription settings:

- Base URL: `https://api.openai.com/v1`
- Endpoint: `POST /v1/audio/transcriptions`
- Model: `gpt-4o-mini-transcribe`
- Response format: `text`
- Max recorded file size: 24 MB

Cleanup uses the same base URL and API key through `/v1/chat/completions`. It is designed to preserve meaning, fix punctuation/casing, and avoid answering dictated questions.

## Privacy Model

- Your API key is stored in local macOS app settings.
- Audio is written to a temporary WAV file only while processing and is deleted afterward.
- Transcript history is stored locally in Application Support when enabled.
- EchoType does not include telemetry, analytics, accounts, sync, billing, or hosted storage.
- Your selected provider may receive audio/text according to that provider's policies.

## Verification

Run core smoke tests:

```bash
swift run EchoTypeCoreSmokeTests
```

Run recorder smoke test:

```bash
swift run EchoTypeRecorderSmokeTests
```

If microphone permission is not granted to Terminal, the recorder smoke test skips with a clear message.

Run notifier smoke test:

```bash
swift run EchoType --notify-smoke-test
```

## Troubleshooting

- **Nothing records:** grant Microphone permission to the app or Terminal that launched it.
- **Shortcut does nothing:** grant Accessibility permission, then restart EchoType.
- **Text is copied but not pasted:** Accessibility permission is missing or the target app blocks synthetic paste.
- **macOS says the app is damaged/unidentified:** v0.1.0 is not notarized. Use **Open Anyway** after downloading from Releases.
- **API calls fail:** confirm the base URL, API key, model name, and network access.
- **Dictation changes meaning:** disable cleanup in Settings, or use a cleanup model that follows rewrite-only instructions reliably.

## Roadmap

- Notarized releases.
- Homebrew Cask.
- Sparkle auto-update.
- Local Whisper provider.
- Realtime streaming transcription.
- Shortcut recorder UI instead of numeric key code entry.
- Better retry UI for failed transcriptions.

## Release Notes

The first public release target is `v0.1.0`, published as `EchoType-macOS-arm64.zip`.

See [CHANGELOG.md](CHANGELOG.md) for release history.

## GitHub Topics

Suggested repo topics: `macos`, `swift`, `dictation`, `speech-to-text`, `voice-input`, `openai`, `byok`, `menu-bar-app`.

## License

MIT. See [LICENSE](LICENSE).
