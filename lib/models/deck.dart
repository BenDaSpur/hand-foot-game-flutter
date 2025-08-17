import 'dart:math';
import 'card.dart';

class Deck {
  List<PlayingCard> _cards = [];
  final int? _seed;

  Deck({int? seed}) : _seed = seed {
    _initializeStandardDeck();
  }

  Deck.fromCards(List<PlayingCard> cards, {int? seed}) : _seed = seed {
    _cards = List.from(cards);
  }

  void _initializeStandardDeck() {
    _cards.clear();
    
    for (Suit suit in Suit.values) {
      for (CardRank rank in CardRank.values) {
        if (rank != CardRank.joker) {
          _cards.add(PlayingCard(suit: suit, rank: rank));
        }
      }
    }
    
    _cards.add(const PlayingCard(rank: CardRank.joker));
    _cards.add(const PlayingCard(rank: CardRank.joker));
  }

  static Deck createHandAndFootDeck(int playerCount, {int? seed}) {
    final deck = Deck(seed: seed);
    final allCards = <PlayingCard>[];
    
    final deckCount = playerCount + 1;
    for (int i = 0; i < deckCount; i++) {
      allCards.addAll(deck._cards);
    }
    
    return Deck.fromCards(allCards, seed: seed);
  }

  void shuffle() {
    final random = _seed != null ? Random(_seed) : Random();
    for (int i = _cards.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = _cards[i];
      _cards[i] = _cards[j];
      _cards[j] = temp;
    }
  }

  PlayingCard? drawCard() {
    if (_cards.isEmpty) return null;
    return _cards.removeLast();
  }

  List<PlayingCard> drawCards(int count) {
    final drawnCards = <PlayingCard>[];
    for (int i = 0; i < count && _cards.isNotEmpty; i++) {
      final card = drawCard();
      if (card != null) {
        drawnCards.add(card);
      }
    }
    return drawnCards;
  }

  void addCard(PlayingCard card) {
    _cards.add(card);
  }

  void addCards(List<PlayingCard> cards) {
    _cards.addAll(cards);
  }

  PlayingCard? get topCard => _cards.isEmpty ? null : _cards.last;
  
  int get size => _cards.length;
  
  bool get isEmpty => _cards.isEmpty;
  
  List<PlayingCard> get cards => List.unmodifiable(_cards);
  
  int? get seed => _seed;
  
  // For game state restoration - replaces the entire deck with new cards
  void replaceCards(List<PlayingCard> newCards) {
    _cards.clear();
    _cards.addAll(newCards);
  }
}