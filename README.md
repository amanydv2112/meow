# meow

Open-source Wispr Flow alternative for macOS with bring-your-own API key speech-to-text.

meow is a native macOS menu bar app for push-to-talk dictation. Hold `fn`, speak, release, and meow transcribes with an OpenAI-compatible speech-to-text endpoint, optionally cleans up punctuation/casing, then pastes the text into the active app.

> v0.1.0 is unsigned/ad-hoc signed and not notarized. macOS may block the first launch until you choose **Open Anyway** in System Settings.

meow is not affiliated with Wispr Flow.

## Demo

Screenshot and short demo GIF coming with the first GitHub release.

## Features

- Native macOS menu bar app with a cat glyph that stays out of your way.
- Status shown as a small mark beside the cat rather than words: a dot while recording, animated dots while transcribing, pause bars when paused.
- Dark waveform pill just above the Dock while you speak.
- Press-and-hold `fn` dictation.
- Bring your own OpenAI-compatible STT provider.
- Default STT model: `gpt-4o-mini-transcribe`.
- Optional cleanup through an OpenAI-compatible chat endpoint, switchable from the menu bar or Settings.
- Automatic paste into the active app, with clipboard restoration when possible.
- Local SQLite transcript history that can be disabled or cleared.
- No accounts, telemetry, sync, billing, or cloud storage by meow.

## Install From Release ZIP

1. Download `meow-macOS-arm64.zip` from the GitHub Releases page.
2. Unzip it and move `meow.app` to `/Applications`.
3. Launch meow. If macOS blocks it, open **System Settings > Privacy & Security** and choose **Open Anyway**.
4. Grant Microphone permission for recording.
5. Grant Accessibility permission so meow can listen for the global shortcut and paste into other apps.
6. Open meow settings from the menu bar icon and add your provider details:
   - **Base URL:** use `https://api.openai.com/v1` for OpenAI, or your OpenAI-compatible provider URL.
   - **API key:** paste your provider API key. meow uses a BYOK model, so no key is bundled.
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
swift run meow
```

Build the `.app` bundle and release ZIP:

```bash
./scripts/build-app.sh
open dist/meow.app
```

The script creates:

- `dist/meow.app`
- `dist/meow-macOS-arm64.zip`
- `dist/meow-macOS-arm64.zip.sha256`

## Icon

The cat is drawn as a vector in [Sources/MeowCore/CatIcon.swift](Sources/MeowCore/CatIcon.swift) and shared by both places it appears, so they can never drift apart:

- The menu bar uses it as a template image, so macOS tints it white in dark mode and black in light mode.
- The app icon puts a white cat on an indigo rounded-square tile.

Regenerate `Resources/meow.icns` after editing the artwork:

```bash
swift run MeowIconGen
```

## Provider Setup

Default transcription settings:

- Base URL: `https://api.openai.com/v1`
- Endpoint: `POST /v1/audio/transcriptions`
- Model: `gpt-4o-mini-transcribe`
- Response format: `text`
- Max recorded file size: 24 MB

Cleanup uses the same base URL and API key through `/v1/chat/completions`. It is designed to preserve meaning, fix punctuation/casing, and avoid answering dictated questions.

Turn it off from the menu bar with **Clean Up Text**, or in **Settings > Provider > Cleanup**. With cleanup off, the transcript is pasted exactly as the speech-to-text provider returned it and no second API call is made, which is also the faster and cheaper path.

## Privacy Model

- Your API key is stored in local macOS app settings.
- Audio is written to a temporary WAV file only while processing and is deleted afterward.
- Transcript history is stored locally in Application Support when enabled.
- meow does not include telemetry, analytics, accounts, sync, billing, or hosted storage.
- Your selected provider may receive audio/text according to that provider's policies.

## Verification

Run core smoke tests:

```bash
swift run MeowCoreSmokeTests
```

Run recorder smoke test:

```bash
swift run MeowRecorderSmokeTests
```

If microphone permission is not granted to Terminal, the recorder smoke test skips with a clear message.

Run notifier smoke test:

```bash
swift run meow --notify-smoke-test
```

## Troubleshooting

- **Nothing records:** grant Microphone permission to the app or Terminal that launched it.
- **Shortcut does nothing:** grant Accessibility permission, then restart meow.
- **Text is copied but not pasted:** Accessibility permission is missing or the target app blocks synthetic paste.
- **macOS says the app is damaged/unidentified:** v0.1.0 is not notarized. Use **Open Anyway** after downloading from Releases.
- **API calls fail:** confirm the base URL, API key, model name, and network access.
- **Dictation changes meaning:** turn off **Clean Up Text** in the menu bar, or use a cleanup model that follows rewrite-only instructions reliably.
- **Upgrading from EchoType:** meow uses a new bundle identifier, so macOS treats it as a new app. Grant Microphone and Accessibility permission again, remove the stale EchoType entries in System Settings, and re-enter your API key in Settings.

## Roadmap

- Notarized releases.
- Homebrew Cask.
- Sparkle auto-update.
- Local Whisper provider.
- Realtime streaming transcription.
- Shortcut recorder UI instead of numeric key code entry.
- Better retry UI for failed transcriptions.

## Release Notes

The first public release target is `v0.1.0`, published as `meow-macOS-arm64.zip`.

See [CHANGELOG.md](CHANGELOG.md) for release history.

## GitHub Topics

Suggested repo topics: `macos`, `swift`, `dictation`, `speech-to-text`, `voice-input`, `openai`, `byok`, `menu-bar-app`.

## License

MIT. See [LICENSE](LICENSE).
