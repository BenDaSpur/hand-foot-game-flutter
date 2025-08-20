# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

- **Run the app**: `flutter run`
- **Build for release**: `flutter build apk` (Android) or `flutter build ios` (iOS)
- **Static analysis**: `flutter analyze`
- **Run tests**: `flutter test test/` for unit tests, `flutter test e2e_test/ -d macos` for E2E tests (see `docs/TESTING.md` for comprehensive testing guide)
- **Hot reload**: Available when running with `flutter run` - press `r` to reload

## Architecture Overview

This is a Flutter implementation of the Hand & Foot card game with sophisticated AI opponents and a Balatro-inspired neon visual theme.

### Core Architecture

**MVC Pattern**: The app follows a Model-View-Controller architecture:
- **Models** (`lib/models/`): Pure data classes for game entities
- **Views** (`lib/screens/`, `lib/widgets/`): UI components 
- **Controller** (`lib/game/game_controller.dart`): Game logic coordination

**Game State Management**: Centralized in `GameState` class which maintains:
- Current player turn and phase (draw/meld/discard)
- All player data (hands, feet, melds, scores)
- Deck and discard pile state
- Action logging system with privacy controls

### Key Components

**Game Controller** (`lib/game/game_controller.dart`):
- Orchestrates all game actions (draw, meld, discard, unlock discard pile)
- Validates moves according to Hand & Foot rules
- Manages turn progression and round transitions

**Bot AI** (`lib/ai/bot_ai.dart`):
- Implements sophisticated decision-making for AI players
- Strategic considerations: unlock potential preservation, foot transition planning, 3s handling
- Different behavior patterns for hand vs foot phases

**Card System** (`lib/models/`):
- `PlayingCard`: Individual card with rank, suit, point values
- `Meld`: Groups of 3+ cards, tracks clean/dirty book status dynamically
- `Deck`: Multi-deck setup (players + 1 decks) with proper shuffling

**UI Theme** (`lib/theme/balatro_theme.dart`):
- Complete Balatro-inspired dark theme with neon colors
- Glow effects, gradients, and holographic wild card treatments
- Responsive design supporting different card sizes

### Game Rules Implementation

The game follows official Hand & Foot rules (documented in `docs/family_hand_and_foot_full_rules.md`):

**Play-down Requirements**: Dynamic point thresholds (Round 1: 60pts, +30 each round)
**Wild Card Limits**: Enforced rule that wilds ≤ naturals in any meld
**Going Out Validation**: Requires both clean book (no wilds) AND dirty book (with wilds)
**Discard Pile Unlocking**: Complex rules requiring 2+ matching naturals + already played down

### Index-Based Selection System

**Critical Implementation Detail**: The UI uses index-based card selection rather than object-based to handle multiple identical cards from multiple decks. This prevents bugs where selecting "King of Hearts" would select all Kings of Hearts in hand.

### Visual Polish

**Balatro Theme**: Deep purple gradients, neon accent colors, glow effects
**Card Redesign**: Holographic wild cards, improved suit visibility, shadow outlines
**Status Indicators**: Neon-colored chips for game state information
**Dynamic Book Labels**: Clean/dirty status updates in real-time as cards are added

### Error Recovery

**Going Out Prevention**: Validates book requirements before allowing final discard
**Stuck Game Recovery**: Emergency skip turn function for edge cases
**Comprehensive Validation**: Multi-step validation for complex moves like multiple meld creation

### Bot AI Sophistication

**Strategic Depth**: 
- Preserves unlock potential by avoiding premature melding
- Manages 3s as strategic discards during foot transition  
- Different aggression levels for hand vs foot phases
- Considers opponent discard pile value when deciding to unlock

**Realistic Behavior**: Bots make human-like decisions with occasional suboptimal plays for game balance.