# meow

Open-source Wispr Flow alternative for macOS with bring-your-own API key speech-to-text.

meow is a native macOS menu bar app for push-to-talk dictation. Hold `fn`, speak, release, and meow transcribes the audio, optionally cleans up punctuation/casing, then pastes the text into the active app.

Transcription runs through one of two engines, switchable in Settings:

- **On-device (Apple)** — the default. Uses Apple's `SpeechAnalyzer` on macOS 26+. No API key, no network, no per-minute cost, and audio never leaves the Mac. The language model is downloaded and shared by the system, so it adds nothing to the app bundle.
- **OpenAI-compatible** — bring your own key and point it at any `/v1/audio/transcriptions` endpoint.

> v0.1.0 is unsigned/ad-hoc signed and not notarized. macOS may block the first launch until you choose **Open Anyway** in System Settings.

meow is not affiliated with Wispr Flow.

## Demo

Screenshot and short demo GIF coming with the first GitHub release.

## Features

- Native macOS menu bar app with a cat glyph that stays out of your way.
- Status shown by the cat's own face rather than words: ears up and eyes wide while listening, eyes shut and ears twitching while transcribing, curled up asleep when paused.
- Dark waveform pill just above the Dock while you speak.
- Press-and-hold `fn` dictation.
- Fully offline transcription on macOS 26+ through Apple's on-device speech models.
- Bring your own OpenAI-compatible STT provider as an alternative.
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
6. Open meow settings from the menu bar icon and pick a **Transcription engine**.
  - With **On-device (Apple)** there is nothing else to configure. Choose a language or leave it on system default, and meow downloads the model on first launch. No extra permission is needed beyond Microphone.
  - With **OpenAI-compatible**, fill in the provider fields described in [Provider Setup](#provider-setup).
7. Click **Save** in Settings, then hold `fn`, speak, and release to test dictation.

## Build From Source

Requirements:

- macOS 14 or newer, or macOS 26 or newer for the on-device engine.
- Xcode Command Line Tools with the macOS 26 SDK.
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

The menu bar cat is posed from a single `Expression`, which controls how far the head sits down the canvas, where the ear tips point, and whether the eyes are open ovals or closed slits. Dropping the head is what makes room for the tall listening ears, since the neutral pose already reaches near the top of the design space.

Regenerate `Resources/meow.icns` after editing the artwork:

```bash
swift run MeowIconGen
```

## On-Device Engine

Selected by default. Requires macOS 26 or later; on older systems meow reports this and you should switch to the OpenAI-compatible engine.

- Uses Apple's `SpeechAnalyzer` with the `.transcription` preset on a completed recording.
- Language models are installed by the system and shared across apps, so they do not ship in `meow.app` and do not count against the app's memory.
- meow checks for the model at launch and downloads it if missing, so the first dictation is not interrupted by a download. The download needs network access; everything after that is offline.
- Holding `fn` also preloads the model, so releasing the key does not pay for a cold start.
- Language is chosen from the list macOS reports as supported. Leave it on system default to follow your Mac's locale.
- Only Microphone permission is required. `SpeechAnalyzer` never sends audio to Apple, so it does not need the Speech Recognition permission that the older `SFSpeechRecognizer` API required.

Measured on an M1 with a 6 second clip: 0.5s cold, 0.2s once the model is warm.

## Provider Setup

Only used when the engine is set to **OpenAI-compatible**.

- **Base URL:** `https://api.openai.com/v1` for OpenAI, or your provider URL.
- **API key:** your provider key. meow uses a BYOK model, so no key is bundled.
- **STT model:** `gpt-4o-mini-transcribe` for OpenAI, or your provider's transcription model name.
- **Language code:** optional, for example `en`. Leave blank for auto-detect when supported.
- **Provider prompt:** optional vocabulary/context hints.
- **Response format:** keep `text` unless your provider requires `json`.
- Endpoint used: `POST /v1/audio/transcriptions`. Max recorded file size: 24 MB.

Cleanup uses the same base URL and API key through `/v1/chat/completions`. It is designed to preserve meaning, fix punctuation/casing, and avoid answering dictated questions. Cleanup is a network call regardless of the transcription engine, so pairing the on-device engine with cleanup enabled still needs an API key. Without one, meow skips cleanup and pastes the raw transcript.

Turn it off from the menu bar with **Clean Up Text**, or in **Settings > Provider > Cleanup**. With cleanup off, the transcript is pasted exactly as the speech-to-text provider returned it and no second API call is made, which is also the faster and cheaper path.

## Privacy Model

- With the on-device engine and cleanup off, meow makes no network calls at all and audio never leaves the Mac.
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
- **On-device engine reports the model is unavailable:** the language has no on-device model, or you are below macOS 26. Pick another language or switch to the OpenAI-compatible engine.
- **First on-device dictation is slow:** the language model downloads on first use. meow starts this at launch, but it needs network access once. Later dictations are offline.
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
- Realtime streaming transcription by feeding live audio into `SpeechAnalyzer` instead of transcribing the finished recording.
- Shortcut recorder UI instead of numeric key code entry.
- Better retry UI for failed transcriptions.

## Release Notes

The first public release target is `v0.1.0`, published as `meow-macOS-arm64.zip`.

See [CHANGELOG.md](CHANGELOG.md) for release history.

## GitHub Topics

Suggested repo topics: `macos`, `swift`, `dictation`, `speech-to-text`, `voice-input`, `openai`, `byok`, `menu-bar-app`.

## License

MIT. See [LICENSE](LICENSE).