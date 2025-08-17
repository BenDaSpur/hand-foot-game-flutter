# Hand & Foot Card Game

A beautiful Flutter implementation of the classic Hand & Foot card game featuring intelligent AI opponents and a stunning Balatro-inspired neon aesthetic.

## 🎮 Game Features

- **Complete Hand & Foot Rules**: Full implementation following official game rules
- **Smart AI Opponents**: Sophisticated bot players with strategic decision-making
- **Balatro-Inspired Theme**: Neon colors, glow effects, and holographic wild cards
- **Multi-Round Gameplay**: Progressive difficulty with increasing play-down requirements
- **Action Logging**: Privacy-aware game history (see your draws, not the bots')
- **Going Out Validation**: Prevents illegal endings requiring both clean and dirty books

## 🎨 Visual Design

- **Dark Neon Theme**: Deep purple gradients with bright accent colors
- **Glowing Cards**: Dynamic lighting effects for selected and playable cards
- **Holographic Wilds**: Special shimmer effects for wild cards (2s and Jokers)
- **Enhanced Visibility**: Bright suit colors and text shadows for perfect readability
- **Modern UI**: Rounded corners, elevated shadows, and smooth animations

## 🤖 AI Intelligence

The bot players feature advanced strategy including:

- **Unlock Preservation**: Keeping cards to potentially unlock the discard pile
- **Strategic 3s Management**: Using 3s as easy discards during foot transitions
- **Meld Timing**: Balancing between building melds and maintaining hand flexibility
- **Foot Transition Planning**: Different strategies for hand vs foot phases

## 🎯 Game Rules Summary

- **Players**: You vs 2 AI opponents
- **Decks**: Uses 3 decks (players + 1) with Jokers
- **Starting Hand**: 11 cards in hand + 11 card foot pile
- **Play Down**: Must meet point requirements to start melding (Round 1: 60 points)
- **Wild Cards**: 2s (20 pts) and Jokers (50 pts) - cannot exceed natural cards in melds
- **Books**: Need both clean (no wilds) and dirty (with wilds) books of 7+ cards to go out
- **Scoring**: Positive points from melds, negative from cards left in hand

## 📱 Download & Play

### 🎮 Ready-to-Play Downloads

**[📥 Download Latest Release](https://github.com/BenDaSpur/hand-foot-game-flutter/releases/latest)**

Choose your platform:

- **🤖 Android**: Download `hand-foot-android.apk`
- **🪟 Windows**: Download `hand-foot-windows.zip`
- **🍎 macOS**: Download `hand-foot-macos.tar.gz`
- **🐧 Linux**: Download `hand-foot-linux.tar.gz`
- **🌐 Web**: Download `hand-foot-web.tar.gz` (host on web server)

### Installation Instructions

- **Android**: Enable "Install from unknown sources" in settings, then install the APK
- **Windows**: Extract ZIP file and run `hand_foot_game_flutter.exe`
- **macOS**: Extract archive and run the `.app` file
- **Linux**: Extract archive and run the executable
- **Web**: Extract files and serve from any web server

## 🚀 Development Setup

### Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK

### Build from Source

```bash
# Clone the repository
git clone [your-repo-url]
cd hand_foot_game_flutter

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Development Commands

```bash
# Static analysis
flutter analyze

# Run tests
flutter test

# Build for release
flutter build apk        # Android
flutter build ios        # iOS
```

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
- **Use the menu** (top-right) to start a new game

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

- **Index-Based Selection**: Handles multiple identical cards from multiple decks
- **Dynamic Book Detection**: Real-time clean/dirty book status updates
- **State Management**: Centralized game state with action logging
- **Responsive Design**: Adapts to different screen sizes and orientations
- **Error Recovery**: Built-in systems to handle edge cases and stuck states

## 🎨 Balatro Inspiration

This game draws visual inspiration from the indie hit **Balatro**, featuring:

- Deep space purple backgrounds with neon gradients
- Glowing UI elements with colored shadows
- Holographic effects on special cards
- Bright, contrasting colors on dark themes
- Modern card game aesthetics with retro-futuristic flair

## 🚀 Releases & Updates

This project uses automated builds via GitHub Actions. Every tagged release automatically builds for:

- Android (APK + AAB)
- Windows (ZIP)
- macOS (tar.gz)
- Linux (tar.gz)
- Web (tar.gz)

### Creating a Release (for maintainers)

```bash
# Use the release script
./scripts/release.sh 1.0.0

# Or manually create a git tag
git tag v1.0.0
git push origin v1.0.0
```

The GitHub Action will automatically build all platforms and create a release with downloadable assets.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📜 License

This project is available for personal and educational use.
