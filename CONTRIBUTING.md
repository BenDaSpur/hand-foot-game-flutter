# Contributing to Hand & Foot

Thanks for helping improve this open-source Hand & Foot Flutter game.

## Ways to contribute

- Report bugs or request features via [GitHub Issues](https://github.com/BenDaSpur/hand-foot-game-flutter/issues) <!-- pragma: allowlist secret -->
- Improve docs (rules, testing, deployment)
- Fix bugs or polish gameplay/UI
- Improve bot AI and tests

Please read the [Code of Conduct](CODE_OF_CONDUCT.md). For security vulnerabilities, follow [SECURITY.md](SECURITY.md) — do not open a public issue.

## Development setup

### Prerequisites

- Flutter SDK **3.44.6** (Dart 3.12.2)
- Git

### Clone and run

Fork or clone this repository from GitHub, then:

```bash
cd hand_foot_game_flutter
flutter pub get
flutter run
```

Solo play works without Firebase. Online multiplayer needs real Firebase config (see `scripts/setup_local_firebase.sh` and the docs). Never commit `.env`, service account JSON, or API keys — this is a **public** repository.

### Quality checks (required before opening a PR)

```bash
./format_and_test.sh
```

Or individually:

```bash
dart format .
flutter analyze   # must be zero issues
flutter test
```

CI runs `dart format --set-exit-if-changed .` and will fail on unformatted Dart.

## Pull request process

1. Fork the repo (or use a branch if you have write access)
2. Create a focused branch (for example `fix/discard-tooltip` or `docs/contributing`)
3. Make your changes with tests when behavior changes
4. Run format / analyze / test locally
5. Open a pull request and fill in the PR template

### Style notes

- Use curly braces for all control-flow statements (even single-line `if`/`for`)
- Prefer `const` constructors when possible
- Prefer trailing commas for multi-line argument lists
- Game logic must not throw exceptions that crash a live session — degrade gracefully and log instead

More architecture detail lives in [CLAUDE.md](CLAUDE.md) and [docs/](docs/).

## Useful docs

- [docs/TESTING.md](docs/TESTING.md) — unit and E2E testing
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) — web/release deployment
- [docs/family_hand_and_foot_full_rules.md](docs/family_hand_and_foot_full_rules.md) — full game rules
- [AGENTS.md](AGENTS.md) — notes for AI/Cloud agents working in this repo

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
