import 'dart:math';
import 'card.dart';

class Deck {
  List<PlayingCard> _cards = [];

  Deck() {
    _initializeStandardDeck();
  }

  Deck.fromCards(List<PlayingCard> cards) {
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

  static Deck createHandAndFootDeck(int playerCount) {
    final deck = Deck();
    final allCards = <PlayingCard>[];
    
    final deckCount = playerCount + 1;
    for (int i = 0; i < deckCount; i++) {
      allCards.addAll(deck._cards);
    }
    
    return Deck.fromCards(allCards);
  }

  void shuffle() {
    final random = Random();
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
}