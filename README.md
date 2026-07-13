# Hand & Foot Card Game

![CI Status](https://github.com/BenDaSpur/hand-foot-game-flutter/workflows/CI/badge.svg)

A beautiful Flutter implementation of the classic Hand & Foot card game featuring intelligent AI opponents and a stunning Balatro-inspired neon aesthetic.

🎮 **[Play Now](https://playhandfoot.com)** | 📥 **[Download](https://github.com/BenDaSpur/hand-foot-game-flutter/releases/latest)**

## ✨ Features

- **Complete Hand & Foot Rules** with smart AI opponents
- **Balatro-Inspired Theme** - neon colors, glow effects, holographic wild cards
- **Progressive Gameplay** - increasing difficulty across rounds
- **Game State Export/Import** - save/load games for debugging
- **Privacy-Aware Logging** - see your draws, not the bots'

## 🎯 Game Rules Summary

- **Players**: You vs 2 AI opponents
- **Decks**: Uses 3 decks (players + 1) with Jokers
- **Starting Hand**: 11 cards in hand + 11 card foot pile
- **Play Down**: Must meet point requirements to start melding (Round 1: 60 points)
- **Wild Cards**: 2s (20 pts) and Jokers (50 pts) - cannot exceed natural cards in melds
- **Books**: Need both clean (no wilds) and dirty (with wilds) books of 7+ cards to go out
- **Scoring**: Positive points from melds, negative from cards left in hand

## 📱 Download & Play

**[📥 Download Latest Release](https://github.com/BenDaSpur/hand-foot-game-flutter/releases/latest)**

Available for: **Web** ([playhandfoot.com](https://playhandfoot.com)) | Android (APK) | Windows | macOS | Linux

## 🚀 Development Setup

### Prerequisites

- Flutter SDK 3.12.0 or higher (Flutter 3.44.6 recommended)
- Dart SDK

### Build from Source

```bash
# Clone the repository
git clone https://github.com/BenDaSpur/hand-foot-game-flutter.git
cd hand_foot_game_flutter

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Development Commands

```bash
# Format code and run tests (recommended)
./format_and_test.sh

# Individual commands
dart format .            # Format all Dart files
flutter test             # Run tests
flutter analyze          # Static analysis

# Build for release
flutter build apk        # Android
flutter build web        # Web
flutter build windows    # Windows
flutter build macos      # macOS
flutter build linux      # Linux
```

### Testing & Quality

- **161+ comprehensive tests** (161 unit + E2E)
- **Multi-platform CI/CD** - Ubuntu (unit tests) + macOS (E2E tests)
- **Branch protection** - all checks must pass to merge
- **Pre-commit hooks** for formatting
- **CI enforces `dart format`** — run `dart format .` (or `./format_and_test.sh`) after every code change before pushing

> **Public repo:** This project is open source on GitHub. Do not commit secrets, credentials, or `.env` files.

## 🎪 How to Play

1. **Draw Phase**: Draw 2 cards from deck or unlock discard pile
2. **Meld Phase**: Create melds (3+ same rank) or add to existing ones
3. **Discard Phase**: Discard one card to end turn
4. **Going to Foot**: When hand is empty, automatically pick up foot pile
5. **Going Out**: Empty your foot while having both clean and dirty books

### Tips

- **Double-tap cards** to select all of the same rank
- **Click "Select X" on melds** to auto-select compatible cards from your hand
- **Tap player names** to view their melds on the table
- **Use the menu** (top-right) to start a new game, copy seed, or export/load games

### 🛠️ Debug Features

- **Copy Seed** - reproducible games
- **Export/Load Game** - save complete game states

## 📁 Project Structure

```
lib/
├── ai/              # Bot AI decision-making logic
├── game/            # Game controller and coordination
├── models/          # Core game entities (cards, players, melds)
├── screens/         # UI screens
├── theme/           # Balatro-inspired visual theme
└── widgets/         # Reusable UI components
```

## 🛠️ Technical Highlights

- **Index-Based Selection** - handles multiple identical cards
- **Dynamic Book Detection** - real-time status updates  
- **Centralized State Management** with action logging
- **Responsive Design** - adapts to all screen sizes

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📜 License

This project is available for personal and educational use.
