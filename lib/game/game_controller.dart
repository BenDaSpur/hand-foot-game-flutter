import '../models/card.dart';
import '../models/deck.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../models/meld.dart';

class GameController {
  final GameState _gameState;
  
  GameController({required List<Player> players})
      : _gameState = GameState(
          players: players,
          deck: Deck.createHandAndFootDeck(players.length),
        );

  GameState get gameState => _gameState;
  
  void initializeGame() {
    _gameState.deck.shuffle();
    _gameState.dealCards();
    _gameState.startRound();
  }

  bool drawFromDeck() {
    return _gameState.drawFromDeck();
  }

  bool drawFromDiscardPile() {
    return _gameState.drawFromDiscard();
  }

  bool unlockDiscardPile() {
    return _gameState.unlockDiscard();
  }

  bool canUnlockDiscard() {
    return _gameState.canUnlockDiscard();
  }

  bool createMeld(List<PlayingCard> cards) {
    return _gameState.playMeld(cards);
  }

  bool createMeldByIndices(List<int> cardIndices) {
    final humanPlayer = _gameState.players.firstWhere(
      (p) => p.type == PlayerType.human,
    );
    
    // Get the actual cards at these indices
    final cards = cardIndices
        .where((index) => index < humanPlayer.currentHand.length)
        .map((index) => humanPlayer.currentHand[index])
        .toList();
    
    final meld = Meld.createMeld(cards);
    if (meld != null) {
      // Check play down requirement if player hasn't played down yet
      if (!humanPlayer.hasPlayedDown) {
        final cardPointValue = cards.fold<int>(0, (sum, card) => sum + card.pointValue);
        if (cardPointValue < _gameState.playDownRequirement) {
          return false;
        }
      }
      
      // Remove cards by indices (this handles duplicates correctly)
      humanPlayer.removeCardsByIndices(cardIndices);
      humanPlayer.melds.add(meld);
      humanPlayer.hasPlayedDown = true;
      
      return true;
    }
    return false;
  }

  bool addCardToMeld(int meldIndex, PlayingCard card) {
    return _gameState.addToMeld(meldIndex, card);
  }

  bool discardCard(PlayingCard card) {
    return _gameState.discard(card);
  }

  bool canPlayerGoOut() {
    final player = _gameState.currentPlayer;
    return player.canGoOut && player.hasBook();
  }

  List<List<PlayingCard>> findPossibleMelds(Player player) {
    final possibleMelds = <List<PlayingCard>>[];
    final hand = List<PlayingCard>.from(player.currentHand);
    
    final cardsByRank = <CardRank, List<PlayingCard>>{};
    final wildCards = <PlayingCard>[];
    
    for (final card in hand) {
      if (card.isWild) {
        wildCards.add(card);
      } else {
        cardsByRank.putIfAbsent(card.rank, () => []).add(card);
      }
    }
    
    for (final entry in cardsByRank.entries) {
      final naturalCards = entry.value;
      if (naturalCards.length >= 3) {
        possibleMelds.add(naturalCards);
      } else if (naturalCards.length >= 2 && wildCards.isNotEmpty) {
        final meldCards = List<PlayingCard>.from(naturalCards);
        final wildsNeeded = 3 - naturalCards.length;
        final availableWilds = wildCards.take(wildsNeeded).toList();
        if (availableWilds.length == wildsNeeded) {
          meldCards.addAll(availableWilds);
          possibleMelds.add(meldCards);
        }
      }
    }
    
    if (wildCards.length >= 3) {
      possibleMelds.add(wildCards.take(3).toList());
    }
    
    return possibleMelds;
  }

  List<PlayingCard> getPlayableCards() {
    final player = _gameState.currentPlayer;
    final playableCards = <PlayingCard>[];
    
    if (_gameState.turnPhase == TurnPhase.meld) {
      final possibleMelds = findPossibleMelds(player);
      for (final meld in possibleMelds) {
        playableCards.addAll(meld);
      }
      
      for (int i = 0; i < player.melds.length; i++) {
        for (final card in player.currentHand) {
          if (player.melds[i].canAddCard(card)) {
            playableCards.add(card);
          }
        }
      }
    }
    
    return playableCards.toSet().toList();
  }

  void nextRound() {
    if (_gameState.phase == GamePhase.roundEnd) {
      _gameState.resetForNewRound();
    }
  }

  bool get isGameOver => _gameState.phase == GamePhase.gameEnd;
  
  Player? get winner => _gameState.winner;
  
  int get currentRound => _gameState.round;
  
  List<Player> get leaderboard {
    final sortedPlayers = List<Player>.from(_gameState.players);
    sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
    return sortedPlayers;
  }

  Map<String, dynamic> getGameStatus() {
    return {
      'phase': _gameState.phase.name,
      'turnPhase': _gameState.turnPhase.name,
      'currentPlayer': _gameState.currentPlayer.name,
      'round': _gameState.round,
      'deckSize': _gameState.deck.size,
      'discardPileSize': _gameState.discardPile.length,
      'topDiscard': _gameState.topDiscard?.displayName,
      'canDrawFromDiscard': _gameState.canDrawFromDiscard,
      'discardPileFrozen': _gameState.discardPileFrozen,
    };
  }
}