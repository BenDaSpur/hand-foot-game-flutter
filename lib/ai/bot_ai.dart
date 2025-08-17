import 'dart:math';
import '../models/card.dart';
import '../models/player.dart';
import '../models/game_state.dart';
import '../game/game_controller.dart';

class BotDecision {
  final String action;
  final dynamic data;
  
  BotDecision({required this.action, this.data});
}

class BotAI {
  
  BotDecision makeDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;
    
    switch (gameState.turnPhase) {
      case TurnPhase.draw:
        return _makeDrawDecision(bot, controller);
      case TurnPhase.meld:
        return _makeMeldDecision(bot, controller);
      case TurnPhase.discard:
        return _makeDiscardDecision(bot, controller);
    }
  }

  BotDecision _makeDrawDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;
    
    // Check if we can unlock the discard pile
    if (gameState.canDrawFromDiscard) {
      final topDiscard = gameState.topDiscard!;
      
      // Count how many matching natural cards we have
      final matchingNaturals = bot.currentHand
          .where((card) => card.rank == topDiscard.rank && !card.isWild)
          .length;
      
      if (matchingNaturals >= 2) {
        final discardPileValue = _calculateDiscardPileValue(gameState.discardPile);
        final discardPileSize = gameState.discardPile.length;
        
        // More aggressive if we have many matching cards or valuable pile
        if (matchingNaturals >= 3 || discardPileValue > 60 || discardPileSize > 4) {
          return BotDecision(action: 'drawFromDiscard');
        }
        
        // On foot pile, be more willing to take smaller piles
        if (bot.hasPickedUpFoot && (discardPileValue > 30 || discardPileSize > 2)) {
          return BotDecision(action: 'drawFromDiscard');
        }
        
        // Conservative threshold for hand pile (save unlocking for better opportunities)
        if (!bot.hasPickedUpFoot && (discardPileValue > 80 || discardPileSize > 5)) {
          return BotDecision(action: 'drawFromDiscard');
        }
      }
    }
    
    return BotDecision(action: 'drawFromDeck');
  }

  BotDecision _makeMeldDecision(Player bot, GameController controller) {
    final gameState = controller.gameState;
    final possibleMelds = controller.findPossibleMelds(bot);
    
    // If player hasn't played down yet, filter melds by play-down requirement
    if (!bot.hasPlayedDown) {
      final playDownRequirement = gameState.playDownRequirement;
      final validMelds = possibleMelds.where((meld) {
        final cardPointValue = meld.fold<int>(0, (sum, card) => sum + card.pointValue);
        return cardPointValue >= playDownRequirement;
      }).toList();
      
      if (validMelds.isNotEmpty) {
        final bestMeld = _chooseBestMeld(validMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    } else {
      // Already played down - be more strategic about melding
      if (_shouldMeldAfterPlayDown(bot, controller, possibleMelds)) {
        final bestMeld = _chooseBestMeld(possibleMelds);
        return BotDecision(action: 'createMeld', data: bestMeld);
      }
    }
    
    final cardsToAddToMelds = _findCardsToAddToExistingMelds(bot);
    if (cardsToAddToMelds.isNotEmpty) {
      final cardToAdd = cardsToAddToMelds.first;
      return BotDecision(action: 'addToMeld', data: cardToAdd);
    }
    
    // No melds to make, proceed to discard
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  BotDecision _makeDiscardDecision(Player bot, GameController controller) {
    final hand = bot.currentHand;
    if (hand.isEmpty) {
      return BotDecision(action: 'error');
    }
    
    final cardToDiscard = _chooseCardToDiscard(bot);
    return BotDecision(action: 'discard', data: cardToDiscard);
  }

  List<PlayingCard> _chooseBestMeld(List<List<PlayingCard>> possibleMelds) {
    possibleMelds.sort((a, b) {
      final scoreA = _calculateMeldScore(a);
      final scoreB = _calculateMeldScore(b);
      return scoreB.compareTo(scoreA);
    });
    
    return possibleMelds.first;
  }

  int _calculateMeldScore(List<PlayingCard> cards) {
    int score = 0;
    for (final card in cards) {
      score += card.pointValue;
    }
    
    final naturalCards = cards.where((c) => !c.isWild).length;
    final wildCards = cards.where((c) => c.isWild).length;
    
    if (wildCards == 0 && cards.length >= 7) {
      score += 500;
    } else if (wildCards > 0 && wildCards < naturalCards && cards.length >= 7) {
      score += 300;
    } else if (wildCards >= 3 && naturalCards == 0 && cards.length >= 7) {
      score += 1000;
    }
    
    return score;
  }


  int _calculateDiscardPileValue(List<PlayingCard> discardPile) {
    int value = 0;
    for (final card in discardPile) {
      value += card.pointValue;
    }
    return value;
  }

  List<Map<String, dynamic>> _findCardsToAddToExistingMelds(Player bot) {
    final cardsToAdd = <Map<String, dynamic>>[];
    
    for (int i = 0; i < bot.melds.length; i++) {
      final meld = bot.melds[i];
      for (final card in bot.currentHand) {
        if (meld.canAddCard(card)) {
          cardsToAdd.add({
            'meldIndex': i,
            'card': card,
            'priority': card.pointValue,
          });
        }
      }
    }
    
    cardsToAdd.sort((a, b) => b['priority'].compareTo(a['priority']));
    return cardsToAdd;
  }

  PlayingCard _chooseCardToDiscard(Player bot) {
    final hand = List<PlayingCard>.from(bot.currentHand);
    
    // Separate wild cards and natural cards
    final wildCards = hand.where((c) => c.isWild).toList();
    final naturalCards = hand.where((c) => !c.isWild).toList();
    
    // Group natural cards by rank
    final cardsByRank = <CardRank, List<PlayingCard>>{};
    for (final card in naturalCards) {
      cardsByRank.putIfAbsent(card.rank, () => []).add(card);
    }
    
    // Priority 1: Discard 3s strategically
    final threeCards = naturalCards.where((c) => c.rank == CardRank.three).toList();
    if (threeCards.isNotEmpty) {
      // If we're preparing to go to foot (hand is small), keep 3s as easy discards
      if (bot.hasPickedUpFoot || bot.currentHand.length <= 4) {
        // Sort by point value - discard red 3s first (more negative)
        threeCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return threeCards.first;
      }
      // Otherwise, discard 3s early to avoid penalties
      else {
        threeCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
        return threeCards.first;
      }
    }
    
    // Priority 2: Discard singletons, but consider unlock potential
    final singletons = <PlayingCard>[];
    final pairs = <PlayingCard>[];
    final triples = <PlayingCard>[];
    
    for (final entry in cardsByRank.entries) {
      if (entry.key == CardRank.three) continue; // Already handled 3s
      
      if (entry.value.length == 1) {
        singletons.addAll(entry.value);
      } else if (entry.value.length == 2) {
        pairs.addAll(entry.value);
      } else if (entry.value.length >= 3) {
        triples.addAll(entry.value);
      }
    }
    
    if (singletons.isNotEmpty) {
      // Sort by point value, prioritize low point cards
      singletons.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return singletons.first;
    }
    
    // Priority 3: Break up pairs strategically
    if (pairs.isNotEmpty) {
      // Sort pairs by point value
      pairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      
      // If we haven't picked up foot yet, be very careful with pairs (unlock potential)
      if (!bot.hasPickedUpFoot && bot.hasPlayedDown) {
        // Only break up very low-value pairs (4-8 points)
        final veryLowValuePairs = pairs.where((c) => c.pointValue <= 5).toList();
        if (veryLowValuePairs.isNotEmpty) {
          return veryLowValuePairs.first;
        }
        // Otherwise, don't break up pairs if we're still on hand pile
      } else {
        // On foot pile or haven't played down - normal pair breaking logic
        final lowValuePairs = pairs.where((c) => c.pointValue < 10).toList();
        if (lowValuePairs.isNotEmpty) {
          return lowValuePairs.first;
        }
        
        if (pairs.isNotEmpty && _shouldBreakUpHighValuePair()) {
          return pairs.first;
        }
      }
    }
    
    // Priority 4: Discard from triples+ (keeping the meld potential)
    if (triples.isNotEmpty) {
      triples.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return triples.first;
    }
    
    // Priority 5: If we must break up high-value pairs
    if (pairs.isNotEmpty) {
      pairs.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return pairs.first;
    }
    
    // Last resort: discard wild cards (should rarely happen)
    if (wildCards.isNotEmpty) {
      wildCards.sort((a, b) => a.pointValue.compareTo(b.pointValue));
      return wildCards.first;
    }
    
    // Fallback (should never happen)
    return hand.first;
  }
  
  bool _shouldBreakUpHighValuePair() {
    // 30% chance to break up high-value pairs when no other options
    return Random().nextDouble() < 0.3;
  }
  
  bool _shouldMeldAfterPlayDown(Player bot, GameController controller, List<List<PlayingCard>> possibleMelds) {
    if (possibleMelds.isEmpty) return false;
    
    // If we're close to running out of hand (3 or fewer cards), be aggressive
    if (bot.currentHand.length <= 3) {
      return true;
    }
    
    // If we haven't picked up our foot yet, be more conservative to keep unlock options
    if (!bot.hasPickedUpFoot) {
      // Only meld if we have 4+ of the same rank (keep some for unlocking)
      for (final meld in possibleMelds) {
        final naturalCards = meld.where((c) => !c.isWild).toList();
        if (naturalCards.isEmpty) continue;
        
        final rank = naturalCards.first.rank;
        final totalOfThisRank = bot.currentHand
            .where((c) => c.rank == rank && !c.isWild)
            .length;
        
        // Only meld if we have 5+ of this rank (keep 2 for potential unlock)
        if (totalOfThisRank >= 5) {
          return true;
        }
      }
      return false;
    }
    
    // On foot pile - more aggressive, but still strategic
    // Meld if we have high-value melds or many cards in hand
    final bestMeld = _chooseBestMeld(possibleMelds);
    final meldValue = _calculateMeldScore(bestMeld);
    
    return meldValue >= 50 || bot.currentHand.length > 8;
  }
}