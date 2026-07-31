# Changelog

All notable changes to meow will be documented in this file.

## [Unreleased]

- Added an on-device transcription engine built on Apple's `SpeechAnalyzer`, now the default. It needs macOS 26, no API key, and no network, and its language models are installed and shared by the system rather than bundled with meow.
- Added a transcription engine picker in Settings, with on-device language selection, model install status, and a download button. Provider fields are hidden when the on-device engine is active.
- meow now checks for the on-device model at launch and preloads it while you hold the shortcut, so the first transcript is not delayed by a download or cold start.
- Transcript history now records the engine that produced each entry instead of always attributing it to the OpenAI-compatible provider.
- Cleanup is skipped instead of attempted when it is enabled without an API key, which previously produced a failure notification on every dictation.
- Renamed the app from EchoType to meow, including the `com.amanyadav.meow` bundle identifier.
- Added a cat app icon and a cat menu bar glyph in place of the plain text title.
- Replaced the menu bar status words with the cat's own expression: ears up and eyes wide while listening, eyes shut with twitching ears while transcribing, ears folded while paused, and an exclamation when attention is needed.
- Added a Clean Up Text toggle to the menu bar so post-processing can be switched without opening Settings, and explained in Settings what turning it off does.
- Restyled the recording HUD as a compact dark pill with a monochrome waveform instead of a red and cyan one, and moved it from the top of the screen to just above the Dock.
- Notarization, Homebrew Cask, Sparkle updates, and realtime streaming transcription are planned future work.

## [0.1.0] - 2026-07-19

- Initial macOS menu bar app.
- Added press-and-hold `Option + Space` dictation.
- Added OpenAI-compatible speech-to-text provider settings.
- Added optional OpenAI-compatible cleanup before paste.
- Added clipboard-based paste insertion with restore support.
- Added local SQLite transcript history.
- Added release ZIP build script for Apple Silicon macOS.
