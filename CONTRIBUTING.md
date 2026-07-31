# Contributing

Thanks for helping improve meow.

## Development Setup

Requirements:

- macOS 14 or newer.
- Xcode Command Line Tools.

Build:

```bash
swift build
```

Run:

```bash
swift run meow
```

Smoke tests:

```bash
swift run MeowCoreSmokeTests
swift run MeowRecorderSmokeTests
swift run meow --notify-smoke-test
```

Build a release artifact:

```bash
./scripts/build-app.sh
```

Regenerate the app icon after editing `Sources/MeowCore/CatIcon.swift`:

```bash
swift run MeowIconGen
```

## Pull Requests

- Keep changes focused and easy to review.
- Add or update smoke tests when behavior changes.
- Update README or CHANGELOG when user-facing behavior changes.
- Do not commit API keys, local audio, transcript history, or generated `dist/` artifacts.

## Release Notes

Public releases use semantic version tags such as `v0.1.0`.
