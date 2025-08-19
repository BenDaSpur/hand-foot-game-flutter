import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/meld.dart';
import '../widgets/playing_card_widget.dart';

// Constants for advanced meld selector
class _AdvancedMeldSelectorConstants {
  static const int minNaturalCardsForMeld = 2;
  static const int minTotalCardsForMeld = 3;
  // Responsive grid cross axis count based on screen size
  static int getGridCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 8; // Desktop
    if (screenWidth > 800) return 7; // Tablet landscape
    if (screenWidth > 600) return 6; // Tablet portrait
    return 5; // Mobile
  }

  static const double cardAspectRatio = 0.7;
  static const double cardSpacing = 8.0;

  // Responsive card dimensions based on screen size
  static double getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = getGridCrossAxisCount(context);
    final availableWidth = screenWidth * 0.9 - 40; // Modal width minus padding
    final cardWidthFromGrid =
        (availableWidth - (cardSpacing * (crossAxisCount - 1))) /
        crossAxisCount;

    // Clamp between reasonable min/max values
    return cardWidthFromGrid.clamp(40.0, 65.0);
  }

  static double getCardHeight(BuildContext context) {
    return getCardWidth(context) / cardAspectRatio;
  }
}

/// Advanced meld selection widget for multi-meld play-downs with wild card assignment control
/// This version uses indices to avoid card object reference issues
class AdvancedMeldSelector extends StatefulWidget {
  final Player player;
  final int playDownRequirement;
  final VoidCallback onCancel;
  final Function(List<List<int>>) onConfirm;

  const AdvancedMeldSelector({
    super.key,
    required this.player,
    required this.playDownRequirement,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  State<AdvancedMeldSelector> createState() => _AdvancedMeldSelectorState();
}

class _AdvancedMeldSelectorState extends State<AdvancedMeldSelector> {
  // Track proposed melds being built (as original hand indices)
  List<List<int>> proposedMeldIndices = [];

  // Track available card indices (not yet assigned to melds)
  List<int> availableCardIndices = [];

  // Track selected cards in available cards (for adding to melds)
  Set<int> selectedAvailableIndices = {};

  @override
  void initState() {
    super.initState();
    _refreshAvailableCards();
  }

  void _refreshAvailableCards() {
    // Always refresh with current hand state and clean up invalid indices
    final currentHandSize = widget.player.currentHand.length;

    // Remove any stale indices that are now out of bounds
    availableCardIndices.removeWhere(
      (index) => index >= currentHandSize || index < 0,
    );

    // Generate fresh indices for current hand size
    availableCardIndices = List.generate(currentHandSize, (index) => index);
    selectedAvailableIndices.clear();
  }

  @override
  Widget build(BuildContext context) {
    final totalPoints = _calculateTotalPoints();
    final meetsRequirement =
        widget.player.hasPlayedDown ||
        totalPoints >= widget.playDownRequirement;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A0B2E).withValues(alpha: 0.95),
              const Color(0xFF16213E).withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with point info
            _buildHeader(totalPoints, meetsRequirement),
            const SizedBox(height: 20),

            // Proposed melds section
            _buildProposedMeldsSection(),
            const SizedBox(height: 20),

            // Available cards section
            _buildAvailableCardsSection(),
            const SizedBox(height: 20),

            // Action buttons
            _buildActionButtons(meetsRequirement),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalPoints, bool meetsRequirement) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.player.hasPlayedDown
                ? 'Multi-Meld Manager'
                : 'Multi-Meld Play-Down',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: meetsRequirement
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color:
                      (meetsRequirement
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.player.hasPlayedDown
                    ? '$totalPoints pts'
                    : '$totalPoints / ${widget.playDownRequirement} pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProposedMeldsSection() {
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Proposed Melds (${proposedMeldIndices.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _canCreateNewMeld() ? _createNewMeld : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Meld'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: proposedMeldIndices.isEmpty
                ? Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'No melds created yet\nSelect cards and click "New Meld"',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: proposedMeldIndices.length,
                    itemBuilder: (context, index) => _buildMeldCard(index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeldCard(int meldIndex) {
    final meldIndices = proposedMeldIndices[meldIndex];
    final meldCards = meldIndices
        .map((i) => widget.player.currentHand[i])
        .toList();
    final points = meldCards.fold<int>(0, (sum, card) => sum + card.pointValue);
    final isValid = Meld.createMeld(meldCards) != null;

    // Check if this would add to an existing meld
    final willAddToExisting =
        isValid &&
        meldCards.isNotEmpty &&
        widget.player.findMeldByRank(meldCards.first.rank) != -1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1F2937).withValues(alpha: 0.8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isValid
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meld ${meldIndex + 1} (${meldCards.length} cards)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    if (willAddToExisting)
                      Text(
                        'Will add to existing ${meldCards.isNotEmpty ? meldCards.first.rank.name : ''} meld',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isValid
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isValid ? '$points pts' : 'Invalid',
                        style: TextStyle(
                          color: isValid
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeMeld(meldIndex),
                      icon: Icon(
                        Icons.delete,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: meldIndices.asMap().entries.map((entry) {
                final cardIndex = entry.key;
                final handIndex = entry.value;
                final card = widget.player.currentHand[handIndex];
                return _buildMeldCardChip(meldIndex, cardIndex, card);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeldCardChip(int meldIndex, int cardIndex, PlayingCard card) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      child: Stack(
        children: [
          PlayingCardWidget(
            card: card,
            width: 40,
            height: 56,
            isSelected: false,
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: () => _removeCardFromMeld(meldIndex, cardIndex),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableCardsSection() {
    return Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Cards (${availableCardIndices.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.custom(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    _AdvancedMeldSelectorConstants.getGridCrossAxisCount(
                      context,
                    ),
                childAspectRatio:
                    _AdvancedMeldSelectorConstants.cardAspectRatio,
                crossAxisSpacing: _AdvancedMeldSelectorConstants.cardSpacing,
                mainAxisSpacing: _AdvancedMeldSelectorConstants.cardSpacing,
              ),
              childrenDelegate: SliverChildBuilderDelegate(
                (context, index) {
                  final handIndex = availableCardIndices[index];

                  // Validate index to prevent out-of-bounds errors (shouldn't happen now with proper cleanup)
                  if (handIndex >= widget.player.currentHand.length ||
                      handIndex < 0) {
                    // Trigger refresh to clean up stale state
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _refreshAvailableCards();
                        });
                      }
                    });
                    return const SizedBox.shrink();
                  }

                  final card = widget.player.currentHand[handIndex];
                  final isSelected = selectedAvailableIndices.contains(index);

                  return _AvailableCardWidget(
                    key: ValueKey('card_${handIndex}_$isSelected'),
                    card: card,
                    isSelected: isSelected,
                    onTap: () => _toggleCardSelection(index),
                  );
                },
                childCount: availableCardIndices.length,
                findChildIndexCallback: (Key key) {
                  // Optimize rebuilds by providing stable keys
                  if (key is ValueKey<String>) {
                    final keyString = key.value;
                    if (keyString.startsWith('card_')) {
                      final parts = keyString.split('_');
                      if (parts.length >= 2) {
                        final handIndex = int.tryParse(parts[1]);
                        if (handIndex != null) {
                          return availableCardIndices.indexOf(handIndex);
                        }
                      }
                    }
                  }
                  return null;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool meetsRequirement) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: widget.onCancel,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Cancel', style: TextStyle(fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: meetsRequirement ? _confirmMelds : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: meetsRequirement
                ? const Color(0xFF10B981)
                : const Color(0xFF6B7280),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor:
                (meetsRequirement
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6B7280))
                    .withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              meetsRequirement
                  ? (widget.player.hasPlayedDown
                        ? 'Confirm Melds'
                        : 'Confirm Play-Down')
                  : (widget.player.hasPlayedDown
                        ? 'Select Cards'
                        : 'Need ${widget.playDownRequirement - _calculateTotalPoints()} more'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  bool _canCreateNewMeld() {
    return selectedAvailableIndices.length >=
        _AdvancedMeldSelectorConstants.minNaturalCardsForMeld;
  }

  void _createNewMeld() {
    final selectedHandIndices = selectedAvailableIndices
        .map((index) => availableCardIndices[index])
        .toList();

    final selectedCards = selectedHandIndices
        .map((index) => widget.player.currentHand[index])
        .toList();

    // Validate meld creation
    final naturalCards = selectedCards.where((card) => !card.isWild).toList();
    final wildCards = selectedCards.where((card) => card.isWild).toList();

    if (naturalCards.length <
            _AdvancedMeldSelectorConstants.minNaturalCardsForMeld &&
        (naturalCards.length + wildCards.length) <
            _AdvancedMeldSelectorConstants.minTotalCardsForMeld) {
      _showError(
        'Need at least ${_AdvancedMeldSelectorConstants.minNaturalCardsForMeld} natural cards or ${_AdvancedMeldSelectorConstants.minTotalCardsForMeld} total cards for a meld',
      );
      return;
    }

    if (naturalCards.isNotEmpty) {
      final rank = naturalCards.first.rank;
      if (!naturalCards.every((card) => card.rank == rank)) {
        _showError('All natural cards must be the same rank');
        return;
      }
    }

    // Create the meld
    setState(() {
      proposedMeldIndices.add(selectedHandIndices);

      // Remove cards from available cards (in reverse order to maintain indices)
      final sortedIndices = selectedAvailableIndices.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final index in sortedIndices) {
        availableCardIndices.removeAt(index);
      }

      selectedAvailableIndices.clear();
    });
  }

  void _toggleCardSelection(int availableIndex) {
    setState(() {
      if (selectedAvailableIndices.contains(availableIndex)) {
        selectedAvailableIndices.remove(availableIndex);
      } else {
        selectedAvailableIndices.add(availableIndex);
      }
    });
  }

  void _removeMeld(int meldIndex) {
    setState(() {
      final meldIndices = proposedMeldIndices.removeAt(meldIndex);
      availableCardIndices.addAll(meldIndices);
      // Sort available cards for better UX
      _sortAvailableCardIndices();
    });
  }

  void _removeCardFromMeld(int meldIndex, int cardIndex) {
    setState(() {
      final handIndex = proposedMeldIndices[meldIndex].removeAt(cardIndex);
      availableCardIndices.add(handIndex);
      _sortAvailableCardIndices();

      // Remove empty melds
      if (proposedMeldIndices[meldIndex].isEmpty) {
        proposedMeldIndices.removeAt(meldIndex);
      }
    });
  }

  void _sortAvailableCardIndices() {
    availableCardIndices.sort((a, b) {
      final cardA = widget.player.currentHand[a];
      final cardB = widget.player.currentHand[b];

      if (cardA.isWild && !cardB.isWild) return 1;
      if (!cardA.isWild && cardB.isWild) return -1;
      return cardA.rank.index.compareTo(cardB.rank.index);
    });
  }

  int _calculateTotalPoints() {
    return proposedMeldIndices
        .expand(
          (meldIndices) => meldIndices.map((i) => widget.player.currentHand[i]),
        )
        .fold<int>(0, (sum, card) => sum + card.pointValue);
  }

  void _confirmMelds() {
    // Final validation
    final validMeldIndices = <List<int>>[];

    for (final meldIndices in proposedMeldIndices) {
      final meldCards = meldIndices
          .map((i) => widget.player.currentHand[i])
          .toList();
      if (Meld.createMeld(meldCards) != null) {
        validMeldIndices.add(meldIndices);
      }
    }

    if (validMeldIndices.isEmpty) {
      _showError('No valid melds created');
      return;
    }

    final totalPoints = validMeldIndices
        .expand(
          (meldIndices) => meldIndices.map((i) => widget.player.currentHand[i]),
        )
        .fold<int>(0, (sum, card) => sum + card.pointValue);

    if (totalPoints < widget.playDownRequirement) {
      _showError(
        'Total points ($totalPoints) do not meet requirement (${widget.playDownRequirement})',
      );
      return;
    }

    widget.onConfirm(validMeldIndices);
  }

  void _showError(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: theme.colorScheme.error,
      ),
    );
  }
}

/// Optimized card widget for available cards section with const constructor
class _AvailableCardWidget extends StatelessWidget {
  const _AvailableCardWidget({
    super.key,
    required this.card,
    required this.isSelected,
    required this.onTap,
  });

  final PlayingCard card;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                ],
              )
            : null,
        child: PlayingCardWidget(
          card: card,
          width: _AdvancedMeldSelectorConstants.getCardWidth(context),
          height: _AdvancedMeldSelectorConstants.getCardHeight(context),
          isSelected: isSelected,
        ),
      ),
    );
  }
}
