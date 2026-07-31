# Changelog

All notable changes to meow will be documented in this file.

## [Unreleased]

- Renamed the app from EchoType to meow, including the `com.amanyadav.meow` bundle identifier.
- Added a cat app icon and a cat menu bar glyph in place of the plain text title.
- Replaced the menu bar status words with small marks beside the cat: a dot while recording, animated dots while transcribing, pause bars, and an exclamation when attention is needed.
- Added a Clean Up Text toggle to the menu bar so post-processing can be switched without opening Settings, and explained in Settings what turning it off does.
- Restyled the recording HUD as a compact dark pill with a monochrome waveform instead of a red and cyan one, and moved it from the top of the screen to just above the Dock.
- Notarization, Homebrew Cask, Sparkle updates, local Whisper, and realtime streaming are planned future work.

## [0.1.0] - 2026-07-19

- Initial macOS menu bar app.
- Added press-and-hold `Option + Space` dictation.
- Added OpenAI-compatible speech-to-text provider settings.
- Added optional OpenAI-compatible cleanup before paste.
- Added clipboard-based paste insertion with restore support.
- Added local SQLite transcript history.
- Added release ZIP build script for Apple Silicon macOS.
