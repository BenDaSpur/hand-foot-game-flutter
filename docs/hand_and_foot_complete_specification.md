# Hand & Foot Card Game - Complete Technical Specification

**Version:** 1.0
**Last Updated:** 2025-12-04
**Purpose:** Source of truth for implementing Hand & Foot card game in any game engine

---

## Table of Contents

1. [Game Overview](#game-overview)
2. [Core Game Rules](#core-game-rules)
3. [Card System](#card-system)
4. [Game Setup](#game-setup)
5. [Turn Sequence](#turn-sequence)
6. [Meld System](#meld-system)
7. [Discard Pile & Unlocking](#discard-pile--unlocking)
8. [Going Out & Winning](#going-out--winning)
9. [Scoring System](#scoring-system)
10. [AI Bot Behavior](#ai-bot-behavior)
11. [Game State Management](#game-state-management)
12. [Edge Cases & Special Rules](#edge-cases--special-rules)

---

## 1. Game Overview

### Game Description
Hand & Foot is a multi-round card game where players try to form melds (sets of matching cards) and "go out" by emptying both their hand and foot piles while meeting specific book requirements.

### Key Concepts
- **Hand**: 11 cards held by player, played first
- **Foot**: 11 cards face-down, played after hand is empty
- **Meld**: 3+ cards of same rank (can include wild cards)
- **Book**: A meld of 7+ cards
- **Clean Book**: 7+ cards with NO wild cards (500 bonus points)
- **Dirty Book**: 7+ cards WITH wild cards (300 bonus points)
- **Going Out**: Emptying both hand and foot with required books

### Player Configuration
- **Minimum Players**: 2
- **Maximum Players**: 6
- **Default Setup**: 1 human + 3 AI bots
- **Deck Count**: `(number_of_players + 1)` standard 52-card decks + Jokers

---

## 2. Core Game Rules

### 2.1 Objective
- Reach **8500 points** across multiple rounds to win the game
- Each round: form melds, complete books, and go out first for bonus points

### 2.2 Wild Cards
- **Jokers**: Always wild (50 points each)
- **2s**: Always wild (20 points each)
- **Wild Card Limit**: In any meld, wild cards CANNOT exceed natural cards
  - Valid: 3 naturals + 3 wilds = OK
  - Invalid: 2 naturals + 3 wilds = REJECTED

### 2.3 Special Cards: 3s
- **CANNOT be melded** (3s are discards only)
- **Red 3s** (Hearts/Diamonds): -300 points if held at round end
- **Black 3s** (Clubs/Spades): -5 points if held at round end
- **Strategy**: Discard 3s immediately, especially red 3s

### 2.4 Play-Down Requirements
Players must lay down cards worth minimum points to start melding:

| Round | Minimum Points Required |
|-------|------------------------|
| 1     | 60                     |
| 2     | 90                     |
| 3     | 120                    |
| 4     | 150                    |
| 5     | 180                    |
| 6     | 210                    |
| 7+    | +30 per round          |

**Formula**: `60 + ((round - 1) × 30)`

**Important**:
- Only cards played THIS TURN count toward requirement
- After playing down once, no minimum for future melds
- Multiple melds in one turn count together for play-down

---

## 3. Card System

### 3.1 Card Structure
```
Card {
  rank: Rank (ace, 2-10, jack, queen, king, joker)
  suit: Suit (hearts, diamonds, clubs, spades, null for joker)
  isWild: boolean (true for 2s and jokers)
  isThree: boolean (true for 3s)
  pointValue: integer
}
```

### 3.2 Point Values

| Card | Points | Notes |
|------|--------|-------|
| Joker | 50 | Wild card |
| 2 | 20 | Wild card |
| Ace | 20 | Natural card |
| K, Q, J | 10 | Face cards |
| 9, 10 | 10 | High numbers |
| 8 | 10 | High numbers |
| 4, 5, 6, 7 | 5 | Low numbers |
| Red 3 | -300 | Penalty if held |
| Black 3 | -5 | Penalty if held |

### 3.3 Card Display Order (in hand)
Recommended sorting: `3s → 4-K → Aces → 2s → Jokers`

This groups 3s (for discard) together, then naturals by rank, then wilds.

---

## 4. Game Setup

### 4.1 Deck Creation
```
Total Decks = number_of_players + 1
Total Cards = (Total Decks × 52) + (Total Decks × 4 jokers)

Example (4 players):
- 5 decks × 52 cards = 260 cards
- 5 decks × 4 jokers = 20 jokers
- Total: 280 cards
```

### 4.2 Initial Deal
1. **Shuffle** all cards thoroughly
2. **Deal to each player**:
   - 11 cards → Hand (visible to player)
   - 11 cards → Foot (face-down, not yet playable)
3. **Draw 1 card** from deck → Discard pile (face-up)
4. **If first discard is wild**: Freeze discard pile (cannot unlock until wild is buried)

### 4.3 Starting State
```
GameState {
  round: 1
  phase: "playing"
  currentPlayerIndex: 0
  turnPhase: "draw"
  discardPileFrozen: (true if first card is wild)

  For each player:
    hand: [11 cards]
    foot: [11 cards]
    melds: []
    hasPlayedDown: false
    hasPickedUpFoot: false
    score: 0
}
```

---

## 5. Turn Sequence

### 5.1 Three Phases Per Turn

#### Phase 1: DRAW
Player MUST choose ONE:

**Option A: Draw from Deck**
- Draw exactly **2 cards** from deck
- Cards are highlighted as "newly drawn" until next turn
- If deck has < 2 cards: Attempt emergency reshuffle (see Edge Cases)

**Option B: Unlock Discard Pile** (if eligible)
Requirements:
- Player has already played down this round (`hasPlayedDown = true`)
- Top discard is NOT wild (no 2s or Jokers)
- Top discard is NOT a 3
- Player has **2+ matching natural cards** of same rank as top discard

Process:
1. Remove 2 matching cards from hand
2. Take top discard card
3. Form meld with those 3 cards (add to existing meld if rank exists)
4. Take **up to 5 additional cards** from discard pile (NOT from deck)
5. Set `hasPlayedDown = true`

**CRITICAL RULE**: Only take additional cards from discard pile. If discard pile has fewer than 5 cards below the top card, player gets fewer cards. Do NOT draw from deck.

#### Phase 2: MELD
Player MAY perform any number of these actions:

**Action 1: Create New Meld**
- Select 3+ cards from hand
- Must contain 2+ natural cards of same rank
- Wild cards ≤ natural cards
- If not yet played down: total points ≥ play-down requirement

**Action 2: Add to Existing Meld**
- Select cards from hand
- Add to player's own melds (cannot add to opponent melds)
- Must maintain wild card limit

**Action 3: Multiple Melds (Advanced)**
- Create several melds in one turn
- All melds together count toward play-down requirement

#### Phase 3: DISCARD
Player MUST:
- Discard exactly **1 card** to end turn
- If discarding wild card: Freeze discard pile
- If hand becomes empty after discard: Pick up foot automatically
- Check for going out conditions

### 5.2 Foot Pickup
**Triggered automatically when**:
- Hand becomes empty (either from melding or discarding)
- Player has not yet picked up foot (`hasPickedUpFoot = false`)

**Process**:
1. Set `hasPickedUpFoot = true`
2. Foot becomes new hand (11 cards now in play)
3. Continue playing normally

---

## 6. Meld System

### 6.1 Meld Creation Rules

**Minimum Requirements**:
- **3+ cards total**
- **2+ natural cards** of the SAME rank
- **Wild cards ≤ natural cards** at all times

**Forbidden**:
- Mixing different ranks (Kings + Queens = invalid)
- Including 3s (3s cannot be melded)
- Exceeding wild card limit

**Examples**:

✅ **Valid Melds**:
```
[K♥, K♠, K♦] = 3 kings (clean)
[K♥, K♠, 2♣] = 2 kings + 1 wild (dirty)
[K♥, K♠, K♦, 2♣, 2♥] = 3 kings + 2 wilds (dirty)
[A♥, A♠, A♦, A♣, 2♣, 2♥, Joker] = 4 aces + 3 wilds = BOOK (dirty)
```

❌ **Invalid Melds**:
```
[K♥, Q♠, J♦] = Different ranks
[K♥, 2♣, 2♥] = Only 1 natural, 2 wilds (wilds > naturals)
[3♥, 3♠, 3♦] = Cannot meld 3s
```

### 6.2 Adding to Existing Melds

**Rules**:
- Can only add to **your own** melds
- Must maintain wild card limit after addition
- Adding cards to a meld that becomes 7+ creates a book

**Clean Book Protection**:
- If meld has 0 wilds, adding wilds converts to dirty book
- Strategic AI should avoid contaminating near-complete clean books

### 6.3 Book Status (Dynamic)

Books are determined by card count:

```
if (meld.cards.length >= 7) {
  if (meld has 0 wild cards) {
    status = "Clean Book" → 500 bonus points
  } else {
    status = "Dirty Book" → 300 bonus points
  }
} else {
  status = "Incomplete Meld"
}
```

**Visual Indicators**:
- Show "Clean Book" label on 7+ card melds with no wilds
- Show "Dirty Book" label on 7+ card melds with wilds
- Update labels dynamically as cards are added

---

## 7. Discard Pile & Unlocking

### 7.1 Discard Pile State

```
DiscardPile {
  cards: [array of cards, newest on top]
  frozen: boolean

  topCard: cards[cards.length - 1]
}
```

**Frozen Conditions**:
- Initial deal has wild card on top
- Player discards wild card
- While frozen: Cannot unlock, can only draw from deck

**Unfrozen By**:
- Non-wild card discarded on top (buries the wild)

### 7.2 Unlock Requirements (Strict Validation)

```javascript
function canUnlockDiscard(player, discardPile) {
  // Must have played down already
  if (!player.hasPlayedDown) return false;

  // Discard pile must not be empty
  if (discardPile.cards.length === 0) return false;

  // Top card must not be wild
  if (discardPile.topCard.isWild) return false;

  // Top card must not be a 3
  if (discardPile.topCard.isThree) return false;

  // Count matching natural cards in hand
  const matchingNaturals = player.hand.filter(card =>
    card.rank === discardPile.topCard.rank && !card.isWild
  );

  // Must have 2+ matching naturals
  return matchingNaturals.length >= 2;
}
```

### 7.3 Unlock Process (Exact Implementation)

```javascript
function unlockDiscard(player, discardPile, deck) {
  // 1. Remove 2 matching natural cards from hand
  const topCard = discardPile.topCard;
  const matchingCards = player.hand
    .filter(card => card.rank === topCard.rank && !card.isWild)
    .slice(0, 2);

  for (const card of matchingCards) {
    player.removeFromHand(card);
  }

  // 2. Take top discard
  const topDiscard = discardPile.cards.pop();

  // 3. Create or add to meld
  const meldCards = [...matchingCards, topDiscard];
  const existingMeldIndex = player.findMeldByRank(topCard.rank);

  if (existingMeldIndex !== -1) {
    // Add to existing meld
    player.melds[existingMeldIndex].addCards(meldCards);
  } else {
    // Create new meld
    player.melds.push(new Meld(meldCards));
  }

  // 4. Take up to 5 additional cards from discard pile ONLY
  // DO NOT take from deck if discard pile runs out
  const additionalCards = [];
  for (let i = 0; i < 5 && discardPile.cards.length > 0; i++) {
    additionalCards.push(discardPile.cards.pop());
  }

  // 5. Add additional cards to hand
  for (const card of additionalCards) {
    player.addToHand(card);
  }

  // 6. Unfreeze discard pile and advance to meld phase
  discardPile.frozen = false;
  player.hasPlayedDown = true;

  return {
    success: true,
    meldedCards: meldCards,
    additionalCards: additionalCards
  };
}
```

---

## 8. Going Out & Winning

### 8.1 Going Out Requirements

**All conditions must be met**:
1. ✅ Player has picked up foot (`hasPickedUpFoot = true`)
2. ✅ Foot is completely empty (all cards melded or discarded)
3. ✅ Player has **at least 1 clean book** (7+ cards, no wilds)
4. ✅ Player has **at least 1 dirty book** (7+ cards, with wilds)

**Implementation**:
```javascript
function canGoOut(player) {
  // Must have picked up and emptied foot
  if (!player.hasPickedUpFoot) return false;
  if (player.foot.length > 0) return false;

  // Count books
  let cleanBooks = 0;
  let dirtyBooks = 0;

  for (const meld of player.melds) {
    if (meld.cards.length >= 7) {
      const hasWilds = meld.cards.some(card => card.isWild);
      if (hasWilds) {
        dirtyBooks++;
      } else {
        cleanBooks++;
      }
    }
  }

  // Must have both types of books
  return cleanBooks >= 1 && dirtyBooks >= 1;
}
```

### 8.2 Going Out Process

**When a player goes out**:
1. **Award going out bonus**: +100 points to player who went out
2. **End round immediately**
3. **Calculate all player scores** (see Scoring section)
4. **Check win condition**: If any player ≥ 8500 points → Game Over
5. **Otherwise**: Start next round

### 8.3 Preventing Invalid Going Out

**UI Validation**:
- Before allowing final discard: Check `canGoOut()`
- If `false`: Show error message explaining missing requirements
  - "Need Clean Book: 7+ cards with NO wilds"
  - "Need Dirty Book: 7+ cards WITH wilds"
  - "Must pick up and empty foot first"

---

## 9. Scoring System

### 9.1 End of Round Scoring

**For each player, calculate**:

```javascript
function calculateRoundScore(player, wentOut) {
  let score = 0;

  // 1. Meld Points (positive)
  for (const meld of player.melds) {
    // Add card point values
    for (const card of meld.cards) {
      score += card.pointValue;
    }

    // Add book bonuses
    if (meld.cards.length >= 7) {
      const hasWilds = meld.cards.some(card => card.isWild);
      if (hasWilds) {
        score += 300; // Dirty book bonus
      } else {
        score += 500; // Clean book bonus
      }
    }
  }

  // 2. Unplayed Card Penalties (negative)
  // ALL cards in hand AND foot count as negative
  const unplayedCards = [...player.hand, ...player.foot];
  for (const card of unplayedCards) {
    score -= Math.abs(card.pointValue);
  }

  // 3. Going Out Bonus
  if (wentOut) {
    score += 100;
  }

  return score;
}
```

### 9.2 Score Breakdown (Display to User)

```
Round 3 Score for Alice:
  Melds:
    Kings (Clean Book): 7 × 10 = 70 + 500 bonus = 570
    Aces (Dirty Book): 5 × 20 + 2 × 20 = 140 + 300 bonus = 440
    Queens (Incomplete): 4 × 10 = 40
  Total Meld Value: +1050

  Unplayed Cards:
    Hand: 2 cards = -15
    Foot: 5 cards = -45
  Total Penalty: -60

  Going Out Bonus: +100

  ROUND SCORE: +1090
  TOTAL SCORE: 3250
```

### 9.3 Game End Condition

```javascript
function checkGameEnd(players) {
  const highestScore = Math.max(...players.map(p => p.score));

  if (highestScore >= 8500) {
    const winners = players.filter(p => p.score === highestScore);
    return {
      gameOver: true,
      winner: winners[0], // If tie, first player wins
      finalScore: highestScore
    };
  }

  return { gameOver: false };
}
```

---

## 10. AI Bot Behavior

### 10.1 Difficulty Levels

**Easy Bot**:
- Random valid moves
- No strategic planning
- Melding: Create first valid meld found
- Discard: Random card

**Medium Bot** (Recommended Default):
- Basic strategy
- Prioritizes completing books
- Avoids contaminating clean books when close to 7 cards
- Strategic 3s discarding

**Hard Bot**:
- Advanced strategy (see detailed implementation below)
- Unlock potential preservation
- Foot transition planning
- Opponent hand size monitoring

### 10.2 Hard Bot Strategy (Detailed)

**Drawing Phase**:
```javascript
function botDecideDraw(bot, gameState) {
  // Check unlock potential
  if (canUnlockDiscard(bot, gameState.discardPile)) {
    const discardPileValue = estimateDiscardPileValue(gameState.discardPile);

    // Unlock if discard pile has 6+ cards (high value)
    if (gameState.discardPile.cards.length >= 6) {
      return "UNLOCK";
    }

    // Unlock if current hand is large (25+ cards) and need to meld
    if (bot.hand.length >= 25) {
      return "UNLOCK";
    }
  }

  // Default: draw from deck
  return "DRAW_DECK";
}
```

**Melding Phase Strategy**:

1. **Play Down Priority** (if not yet played down):
   - Find minimum cards to meet requirement
   - Prefer using cards that don't break potential melds
   - Avoid using too many wilds early

2. **Book Completion Priority**:
   - Prioritize melds with 6 cards (one away from book)
   - Complete clean books before dirty books
   - Protect clean books from contamination

3. **Wild Card Management**:
   - **Early game** (hand phase): Hoard wilds for strategic plays
   - **Mid game** (foot phase): Use wilds to complete books
   - **Never** use wild if it contaminates a 6-card clean meld

4. **Foot Transition Planning**:
   - When hand has 3-5 cards left, start aggressive melding
   - Discard 3s strategically before foot pickup

**Discard Phase Strategy**:
```javascript
function botChooseDiscard(bot, gameState) {
  const hand = bot.hand;

  // Priority 1: Red 3s (avoid -300 penalty)
  const red3s = hand.filter(card => card.isRedThree);
  if (red3s.length > 0) return red3s[0];

  // Priority 2: Black 3s (avoid -5 penalty)
  const black3s = hand.filter(card => card.isBlackThree);
  if (black3s.length > 0) return black3s[0];

  // Priority 3: Cards that don't break potential melds
  const safeDiscards = hand.filter(card => {
    const sameRank = hand.filter(c => c.rank === card.rank);
    return sameRank.length === 1; // Only 1 of this rank
  });
  if (safeDiscards.length > 0) {
    // Discard lowest value safe card
    return safeDiscards.reduce((min, card) =>
      card.pointValue < min.pointValue ? card : min
    );
  }

  // Priority 4: Least valuable card
  return hand.reduce((min, card) =>
    card.pointValue < min.pointValue ? card : min
  );
}
```

### 10.3 Bot Turn Timing

**Realistic Pacing**:
- Draw phase: 500ms delay
- Each meld action: 800ms delay
- Discard phase: 600ms delay
- Total turn time: ~2-3 seconds

**Purpose**: Makes game feel natural, gives player time to see bot actions

---

## 11. Game State Management

### 11.1 Complete Game State Structure

```javascript
GameState {
  // Game meta
  phase: "setup" | "playing" | "roundEnd" | "gameEnd"
  round: integer (1-based)
  winner: Player | null

  // Turn management
  currentPlayerIndex: integer
  turnPhase: "draw" | "meld" | "discard"
  hasDrawnFromDeck: boolean
  hasMelded: boolean

  // Card piles
  deck: Deck {
    cards: Card[]
    size: integer
    seed: integer (for deterministic shuffle)
  }
  discardPile: Card[]
  discardPileFrozen: boolean

  // Players
  players: Player[]

  // Action history
  recentActions: GameAction[] {
    message: string
    playerName: string
    timestamp: datetime
  }
}

Player {
  id: string
  name: string
  type: "human" | "bot"
  score: integer

  // Cards
  hand: Card[]
  foot: Card[]
  melds: Meld[]

  // State flags
  hasPlayedDown: boolean
  hasPickedUpFoot: boolean

  // UI helpers
  newlyDrawnCardIndices: integer[] // For highlighting
  roundScoreHistory: RoundScoreBreakdown[]
}

Meld {
  cards: Card[]
  rank: CardRank

  // Computed properties
  isBook: boolean (cards.length >= 7)
  isClean: boolean (cards.length >= 7 && no wilds)
  isDirty: boolean (cards.length >= 7 && has wilds)
}
```

### 11.2 State Transitions

**Round Start** (`phase = "playing"`):
```javascript
function startRound(gameState) {
  gameState.phase = "playing";
  gameState.currentPlayerIndex = 0;
  gameState.turnPhase = "draw";
  gameState.discardPileFrozen = false;
  gameState.hasDrawnFromDeck = false;
  gameState.hasMelded = false;

  // Reset all players
  for (const player of gameState.players) {
    player.hand = [];
    player.foot = [];
    player.melds = [];
    player.hasPlayedDown = false;
    player.hasPickedUpFoot = false;
  }

  // Clear discard pile
  gameState.discardPile = [];

  // Reshuffle deck from ALL cards
  gameState.deck.addAllCards();
  gameState.deck.shuffle();

  // Deal cards
  dealCards(gameState);
}
```

**Round End** (`phase = "roundEnd"`):
```javascript
function endRound(gameState) {
  gameState.phase = "roundEnd";

  // Find who went out
  const playerWhoWentOut = gameState.players.find(p => canGoOut(p));

  // Calculate scores for all players
  for (const player of gameState.players) {
    const wentOut = player === playerWhoWentOut;
    const roundScore = calculateRoundScore(player, wentOut);
    player.score += roundScore;
    player.recordRoundScoreBreakdown(gameState.round, roundScore, wentOut);
  }

  // Check for game end
  const gameEnd = checkGameEnd(gameState.players);
  if (gameEnd.gameOver) {
    gameState.phase = "gameEnd";
    gameState.winner = gameEnd.winner;
  } else {
    gameState.round++;
  }
}
```

### 11.3 Save/Load System

**Save Format** (JSON):
```json
{
  "version": "1.0",
  "gameSeed": 12345,
  "gameState": {
    "phase": "playing",
    "round": 2,
    "currentPlayerIndex": 1,
    "turnPhase": "meld",
    "discardPileFrozen": false
  },
  "players": [
    {
      "id": "player1",
      "name": "Alice",
      "type": "human",
      "score": 1250,
      "hand": [...],
      "foot": [...],
      "melds": [...],
      "hasPlayedDown": true,
      "hasPickedUpFoot": false
    }
  ],
  "discardPile": [...],
  "timestamp": "2025-12-04T10:30:00Z"
}
```

**Deterministic Deck Restoration**:
- Save deck seed on game creation
- On load: Recreate deck with same seed
- Remove cards in player hands/feet/melds from deck
- This ensures deck state is consistent

---

## 12. Edge Cases & Special Rules

### 12.1 Empty Deck Scenarios

**Scenario 1: Deck empty during draw**
```javascript
function drawFromDeck(gameState) {
  // Check if deck has fewer than 2 cards before drawing
  if (gameState.deck.size < 2) {
    attemptReshuffleForEmptyDeck(gameState);
  }

  // Try to draw 2 cards
  const cards = [];
  for (let i = 0; i < 2; i++) {
    const card = gameState.deck.drawCard();
    if (card === null) {
      // Still no cards after reshuffle - emergency round end
      emergencyEndRound(gameState, "Insufficient cards in deck");
      return false;
    }
    cards.push(card);
  }

  // Add to hand
  gameState.currentPlayer.addCardsToHand(cards);
  return true;
}
```

**Emergency Reshuffle**:
```javascript
function attemptReshuffleForEmptyDeck(gameState) {
  // Need at least 2 cards in discard (keep top card)
  if (gameState.discardPile.length < 2) {
    return; // Cannot reshuffle
  }

  // Keep top discard
  const topCard = gameState.discardPile.pop();

  // Reshuffle rest into deck
  const cardsToShuffle = [...gameState.discardPile];
  gameState.discardPile = [topCard];

  gameState.deck.addCards(cardsToShuffle);
  gameState.deck.shuffle();
}
```

**Emergency Round End**:
```javascript
function emergencyEndRound(gameState, reason) {
  logAction(`Emergency round end: ${reason}`);

  // Calculate scores as normal (no one went out)
  for (const player of gameState.players) {
    const roundScore = calculateRoundScore(player, false);
    player.score += roundScore;
  }

  // Advance to round end
  endRound(gameState);
}
```

### 12.2 3s Stalemate Detection

**Scenario**: Deck runs low, discard pile fills with only 3s

```javascript
function handleThreeDiscard(gameState) {
  // Check if only 3s in recent discard pile (last 10 cards)
  const recentDiscards = gameState.discardPile.slice(-10);
  const onlyThrees = recentDiscards.every(card => card.isThree);

  // Check if deck is low
  const deckLow = gameState.deck.size < 10;

  if (onlyThrees && deckLow) {
    // Track stalemate
    if (!gameState.stalemateStartPlayer) {
      gameState.stalemateStartPlayer = gameState.currentPlayerIndex;
      gameState.stalemateDiscardCount = 1;
    } else {
      gameState.stalemateDiscardCount++;

      // After 2 full rotations of all players discarding 3s
      if (gameState.stalemateDiscardCount >= gameState.players.length * 2) {
        emergencyEndRound(gameState, "3s stalemate detected");
      } else if (gameState.stalemateDiscardCount === gameState.players.length) {
        logAction("⚠️ WARNING: Only 3s in discard with low deck. Round will end if continues.");
      }
    }
  } else {
    // Reset stalemate tracking
    gameState.stalemateStartPlayer = null;
    gameState.stalemateDiscardCount = 0;
  }
}
```

### 12.3 Foot Pickup During Going Out

**Scenario**: Player melds last hand card, picks up foot, immediately goes out

```javascript
function checkFootPickupAndGoingOut(player, gameState) {
  // After melding or discarding
  if (player.hand.length === 0 && !player.hasPickedUpFoot) {
    player.pickUpFoot(); // Foot becomes new hand
    logAction(`${player.name} picked up foot`);

    // Immediately check if player can go out
    if (canGoOut(player)) {
      logAction(`${player.name} went out immediately after picking up foot!`);
      endRound(gameState);
      return true;
    }
  }
  return false;
}
```

### 12.4 Multiple Melds Causing Going Out

**Scenario**: Player creates multiple melds in advanced modal, goes out

```javascript
function createMultipleMelds(player, meldGroups, gameState) {
  // Validate all melds first
  for (const meldGroup of meldGroups) {
    if (!validateMeld(meldGroup, player)) {
      return false;
    }
  }

  // Check play-down requirement if not yet played down
  if (!player.hasPlayedDown) {
    const totalPoints = meldGroups.flat().reduce((sum, card) => sum + card.pointValue, 0);
    if (totalPoints < gameState.playDownRequirement) {
      return false;
    }
  }

  // Create all melds
  for (const meldGroup of meldGroups) {
    player.createMeld(meldGroup);
  }

  player.hasPlayedDown = true;

  // Check for foot pickup
  if (checkFootPickupAndGoingOut(player, gameState)) {
    return true;
  }

  // Check for going out (if foot already picked up)
  if (canGoOut(player)) {
    endRound(gameState);
  }

  return true;
}
```

### 12.5 Validation Error Messages

**User-Friendly Feedback**:

```javascript
function validateMeldWithFeedback(cards, player, playDownRequirement) {
  // Empty selection
  if (cards.length === 0) {
    return { valid: false, error: "Select at least 3 cards" };
  }

  // Too few cards
  if (cards.length < 3) {
    return { valid: false, error: "Melds require at least 3 cards" };
  }

  // Count naturals and wilds
  const naturals = cards.filter(c => !c.isWild && !c.isThree);
  const wilds = cards.filter(c => c.isWild);
  const threes = cards.filter(c => c.isThree);

  // Contains 3s
  if (threes.length > 0) {
    return { valid: false, error: "3s cannot be melded" };
  }

  // Not enough naturals
  if (naturals.length < 2) {
    return { valid: false, error: "Need at least 2 natural cards of same rank" };
  }

  // Check all naturals are same rank
  const ranks = new Set(naturals.map(c => c.rank));
  if (ranks.size > 1) {
    return { valid: false, error: "All natural cards must be same rank" };
  }

  // Too many wilds
  if (wilds.length > naturals.length) {
    return { valid: false, error: `Too many wild cards (${wilds.length} wilds, ${naturals.length} naturals). Wilds cannot exceed naturals.` };
  }

  // Play-down requirement not met
  if (!player.hasPlayedDown) {
    const points = cards.reduce((sum, c) => sum + c.pointValue, 0);
    if (points < playDownRequirement) {
      return { valid: false, error: `Need ${playDownRequirement} points to play down (have ${points})` };
    }
  }

  return { valid: true };
}
```

---

## 13. UI/UX Guidelines

### 13.1 Visual Theme
- **Style**: Balatro-inspired neon dark theme
- **Colors**: Deep purple background, neon accents (cyan, magenta, yellow)
- **Effects**: Glow effects, gradients, card shadows

### 13.2 Key UI Elements

**Card Rendering**:
- Cards: 60-120px width (responsive)
- Aspect ratio: 0.7 (height = width / 0.7)
- Wild cards: Holographic effect
- Newly drawn: Highlighted border (yellow glow)
- Selected for meld: Elevated + glow

**Game Board Layout**:
```
┌─────────────────────────────────────────────┐
│ Opponent Melds (top)                        │
├─────────────────────────────────────────────┤
│ Deck │ Discard Pile │ Game Info (round/pts) │
├─────────────────────────────────────────────┤
│ Player Melds (books displayed prominently)  │
├─────────────────────────────────────────────┤
│ Player Hand (cards in row, sorted)          │
└─────────────────────────────────────────────┘
```

**Action Log**:
- Bottom-right corner
- Last 10 actions visible
- Auto-scroll on new action
- Format: `[PlayerName] action details`

### 13.3 Interactive Elements

**Card Selection**:
- Click card in hand → Toggle selected state
- Selected cards: Move up 20px + glow
- Right-click or long-press → Quick discard

**Action Buttons**:
- "Draw from Deck" (2 cards icon)
- "Unlock Discard" (enabled only when valid)
- "Create Meld" (enabled when 3+ selected)
- "Add to Meld [Rank]" (enabled when valid)
- "Discard" (enabled in discard phase)
- "Advanced Melding" (modal for multiple melds)

**Modal Dialogs**:
- Round end summary (scores, winner)
- Going out prevention (explain missing requirements)
- Advanced meld selector (multi-meld creation)
- Settings/pause menu

### 13.4 Accessibility

- **Keyboard shortcuts**: Space = draw, Enter = confirm action, 1-9 = select cards
- **Screen reader support**: Announce turn phase, card selections
- **Color blind mode**: Use patterns in addition to colors
- **Scalable UI**: Support 800x600 to 4K resolutions

---

## 14. Testing & Validation

### 14.1 Critical Test Cases

**Meld Validation**:
- [ ] 3 naturals creates valid meld
- [ ] 2 naturals + 1 wild creates valid meld
- [ ] 1 natural + 2 wilds rejected
- [ ] Mixed ranks rejected
- [ ] 3s in meld rejected

**Going Out**:
- [ ] Cannot go out without clean book
- [ ] Cannot go out without dirty book
- [ ] Cannot go out before picking up foot
- [ ] Can go out with 1 clean + 1 dirty book + empty foot

**Discard Unlock**:
- [ ] Cannot unlock before playing down
- [ ] Cannot unlock with wild on top
- [ ] Cannot unlock with 3 on top
- [ ] Cannot unlock with only 1 matching natural
- [ ] Takes up to 5 cards from discard (NOT deck)
- [ ] Unlocking with 2 cards in discard takes only 2 (not from deck)

**Scoring**:
- [ ] Clean book awards 500 bonus
- [ ] Dirty book awards 300 bonus
- [ ] Going out awards 100 bonus
- [ ] Red 3s penalty -300 if held
- [ ] Black 3s penalty -5 if held
- [ ] Unplayed cards count as negative

**Edge Cases**:
- [ ] Empty deck triggers reshuffle
- [ ] Completely empty deck triggers emergency round end
- [ ] 3s stalemate ends round after 2 rotations
- [ ] Foot pickup during meld works correctly

### 14.2 Performance Benchmarks

- Game start to deal: < 500ms
- Turn transition: < 100ms
- Card animation: 60 FPS
- AI turn decision: < 2 seconds

---

## 15. Implementation Checklist

### Phase 1: Core Systems
- [ ] Card class with all properties
- [ ] Deck class with shuffle/draw/reshuffle
- [ ] Player class with hand/foot/melds
- [ ] GameState class with full state management
- [ ] Meld validation logic
- [ ] Play-down requirement validation

### Phase 2: Turn Flow
- [ ] Draw phase (deck + unlock)
- [ ] Meld phase (create + add)
- [ ] Discard phase
- [ ] Turn transition
- [ ] Foot pickup automation

### Phase 3: Game Flow
- [ ] Round start/end
- [ ] Scoring calculation
- [ ] Going out validation
- [ ] Win condition check

### Phase 4: AI Bots
- [ ] Easy bot (random)
- [ ] Medium bot (basic strategy)
- [ ] Hard bot (advanced strategy)
- [ ] Bot turn timing/pacing

### Phase 5: UI/UX
- [ ] Card rendering
- [ ] Game board layout
- [ ] Action buttons
- [ ] Modal dialogs
- [ ] Action log
- [ ] Animations

### Phase 6: Polish
- [ ] Save/load system
- [ ] Settings menu
- [ ] Sound effects
- [ ] Tutorial/help
- [ ] Testing & bug fixes

---

## Appendix A: Quick Reference

### Card Point Values
```
Joker: 50 | 2: 20 | Ace: 20 | K/Q/J: 10 | 9/10/8: 10 | 4-7: 5 | Red 3: -300 | Black 3: -5
```

### Play-Down Requirements
```
Round 1: 60 | Round 2: 90 | Round 3: 120 | Round 4: 150 | +30 each round
```

### Meld Rules
```
Min 3 cards | Min 2 naturals same rank | Wilds ≤ Naturals | No 3s
```

### Going Out
```
✓ Picked up foot | ✓ Foot empty | ✓ 1+ clean book | ✓ 1+ dirty book
```

### Unlock Discard
```
✓ Played down | ✓ Not wild | ✓ Not 3 | ✓ 2+ matching naturals → Take top + up to 5 more from discard
```

---

## Appendix B: Common Pitfalls

### ❌ Don't Do This
1. **Allow drawing from deck during unlock** - Only take from discard pile
2. **Count hand cards toward play-down before melding** - Only melded cards count
3. **Allow going out without both book types** - Need clean AND dirty
4. **Let wilds exceed naturals in meld** - Wilds must be ≤ naturals
5. **Forget to check foot is empty for going out** - Must have picked up AND emptied

### ✅ Do This
1. **Validate melds before creating** - Prevent invalid states
2. **Update book status dynamically** - Recalculate on card add
3. **Show clear error messages** - Tell player why action failed
4. **Auto-sort player hand** - By rank for easier meld finding
5. **Highlight newly drawn cards** - Better UX, prevents confusion

---

**End of Specification**

*This document represents the complete, authoritative specification for Hand & Foot card game. All implementations should follow these rules exactly to ensure consistent gameplay.*
