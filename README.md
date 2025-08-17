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

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK

### Installation
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

## 📜 License

This project is available for personal and educational use.
