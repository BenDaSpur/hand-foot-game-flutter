# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

- **Run the app**: `flutter run`
- **Build for release**: `flutter build apk` (Android) or `flutter build ios` (iOS)
- **Static analysis**: `flutter analyze`
- **Run tests**: `flutter test test/` for unit tests, `flutter test e2e/ -d macos` for e2e integration tests
- **Hot reload**: Available when running with `flutter run` - press `r` to reload
- **Clean build**: `flutter clean && flutter pub get` to resolve dependency issues

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

**Multiplayer Architecture** (`lib/game/`):
- **DRY Architecture**: Shared game logic between singleplayer and multiplayer
- **GameInterface**: Common interface for all game controllers
- **NetworkAdapter**: Abstraction for different multiplayer backends (Firebase, WebRTC, etc.)
- **EnhancedMultiplayerController**: Multiplayer implementation that delegates to GameController
- **GameControllerFactory**: Factory pattern for creating appropriate controllers
- See `docs/multiplayer_architecture.md` for detailed architecture guide

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

#### Meld Creation Rules (Advanced Modal)

**Minimum Requirements**: 
- Melds must contain at least 3 cards total
- Must have minimum 2 natural cards of the same rank
- Wild cards (2s and Jokers) can substitute for naturals

**Valid Meld Types**:
- Clean melds: All natural cards of same rank (no wilds)
- Dirty melds: Natural cards + wilds, but wilds ≤ naturals
- Books: 7+ cards (clean book = 500 bonus, dirty book = 300 bonus)

**Forbidden Cards**:
- 3s cannot be melded (red 3s = +100pts, black 3s = -100pts when held)
- Different ranks cannot be mixed (Kings + Queens = invalid)
- Cannot exceed wild card limit (more wilds than naturals)

**Point Validation**:
- First play-down must meet round requirement (only checked if !hasPlayedDown)
- Subsequent melds after playing down have no point restrictions
- Multiple melds in advanced modal are validated together for initial play-down

### Index-Based Selection System

**Critical Implementation Detail**: The UI uses index-based card selection rather than object-based to handle multiple identical cards from multiple decks. This prevents bugs where selecting "King of Hearts" would select all Kings of Hearts in hand.

### Visual Polish

**Balatro Theme**: Deep purple gradients, neon accent colors, glow effects
**Card Redesign**: Holographic wild cards, improved suit visibility, shadow outlines
**Status Indicators**: Neon-colored chips for game state information
**Dynamic Book Labels**: Clean/dirty status updates in real-time as cards are added

### Error Recovery

**Going Out Prevention**: Validates book requirements before allowing final discard
**Emergency Round End**: Automatically ends rounds when deck becomes insufficient for gameplay, preventing game freezing
**Stuck Game Recovery**: Emergency skip turn function for edge cases
**Comprehensive Validation**: Multi-step validation for complex moves like multiple meld creation

### Bot AI Sophistication

**Strategic Depth**: 
- Preserves unlock potential by avoiding premature melding
- Manages 3s as strategic discards during foot transition  
- Different aggression levels for hand vs foot phases
- Considers opponent discard pile value when deciding to unlock

**Realistic Behavior**: Bots make human-like decisions with occasional suboptimal plays for game balance.

### Performance Optimizations

**Advanced Meld Modal**: 
- Debounced state refresh (300ms) to prevent excessive updates during rapid interactions
- Responsive card sizing and grid layout based on screen dimensions
- Memory leak prevention with proper Timer disposal

**Mobile Browser Compatibility**:
- Replaced GridView.custom with GridView.builder for better touch handling
- Added BouncingScrollPhysics for smooth mobile scrolling
- Removed AutomaticKeepAliveClientMixin to prevent touch event interference
- Wrapped content in SingleChildScrollView for reliable mobile interaction

**Configuration Management**: Centralized game constants in GameConfig class for maintainability

**Code Quality**: 
- Modular component design with extracted sub-methods
- Shared UI components to eliminate duplication (e.g., `EmergencyRoundEndDialog`)
- Comprehensive test coverage: 175+ unit tests plus e2e integration tests
- Static analysis compliance with zero issues

## Game Configuration Constants

Key constants defined in `GameConfig`:
- `minTotalCardsForMeld: 3` - Minimum cards needed for any meld
- `minNaturalCardsForMeld: 2` - Minimum natural cards of same rank required
- `maxWildCardsInMeld` - Wild cards cannot exceed natural cards
- `cleanBookBonus: 500` - Points for 7+ cards with no wilds
- `dirtyBookBonus: 300` - Points for 7+ cards with wilds
- `basePlayDownRequirement: 60` - Round 1 requirement (+30 per round)

## Development Workflows

**Mobile Browser Testing**: Always test on actual mobile browsers, not just desktop responsive mode. Common issues:
- Touch events not registering → Use GridView.builder over GridView.custom
- Scroll performance → Add BouncingScrollPhysics
- Card selection frozen → Remove AutomaticKeepAliveClientMixin

**Meld Validation Debugging**: When meld creation fails:
1. Check if player has played down (`hasPlayedDown`)
2. Verify minimum natural cards of same rank
3. Ensure wild card count ≤ natural card count
4. Confirm no 3s are included in meld selection

**Insufficient Cards Handling**: When deck becomes empty:
- System automatically triggers emergency round end via `_emergencyEndRoundInsufficientCards()`
- Shows user-friendly dialog explaining early round termination
- Calculates scores and advances to next round seamlessly

**Git Workflow**: 
- Branch naming: `bs/feature-description` (developer-initials/description)
- Always run `flutter analyze` before committing
- Commit only lib/ changes unless specifically adding tests