import 'dart:async';
import 'package:flutter/material.dart';
import '../models/card.dart';
import '../models/player.dart';
import '../models/meld.dart';
import '../widgets/playing_card_widget.dart';
import '../game/game_config.dart';

// Helper class for responsive UI calculations
class _ResponsiveHelper {
  static int getGridCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > GameConfig.desktopBreakpoint) {
      return GameConfig.gridCrossAxisCounts['desktop']!;
    }
    if (screenWidth > GameConfig.tabletLandscapeBreakpoint) {
      return GameConfig.gridCrossAxisCounts['tablet_landscape']!;
    }
    if (screenWidth > GameConfig.tabletPortraitBreakpoint) {
      return GameConfig.gridCrossAxisCounts['tablet_portrait']!;
    }
    return GameConfig.gridCrossAxisCounts['mobile']!;
  }

  static double getCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = getGridCrossAxisCount(context);
    final availableWidth = screenWidth * GameConfig.modalWidthRatio - 40;
    final cardWidthFromGrid =
        (availableWidth - (GameConfig.cardSpacing * (crossAxisCount - 1))) /
        crossAxisCount;

    return cardWidthFromGrid.clamp(
      GameConfig.minCardWidth,
      GameConfig.maxCardWidth,
    );
  }

  static double getCardHeight(BuildContext context) {
    return getCardWidth(context) / GameConfig.cardAspectRatio;
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

  // Debouncing for state refresh
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshAvailableCards(immediate: true);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshAvailableCards({bool immediate = false}) {
    if (immediate) {
      _refreshTimer?.cancel();
      _performRefresh();
    } else {
      // Debounce rapid refresh calls
      _refreshTimer?.cancel();
      _refreshTimer = Timer(GameConfig.debounceDelay, _performRefresh);
    }
  }

  void _performRefresh() {
    if (!mounted) return;

    final currentHandSize = widget.player.currentHand.length;

    // Remove any stale indices that are now out of bounds
    availableCardIndices.removeWhere(
      (index) => index >= currentHandSize || index < 0,
    );

    // Generate fresh indices for current hand size
    availableCardIndices = List.generate(currentHandSize, (index) => index);
    selectedAvailableIndices.clear();

    if (mounted) {
      setState(() {});
    }
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
        width: MediaQuery.of(context).size.width * GameConfig.modalWidthRatio,
        height:
            MediaQuery.of(context).size.height * GameConfig.modalHeightRatio,
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            height:
                MediaQuery.of(context).size.height *
                    GameConfig.modalHeightRatio -
                40,
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
    final meldData = _getMeldData(meldIndex);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1F2937).withValues(alpha: 0.8),
      elevation: 4,
      shape: _getMeldCardShape(meldData.isValid),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMeldHeader(meldIndex, meldData),
            const SizedBox(height: 8),
            _buildMeldCardChips(meldIndex, meldData.meldIndices),
          ],
        ),
      ),
    );
  }

  _MeldData _getMeldData(int meldIndex) {
    final meldIndices = proposedMeldIndices[meldIndex];
    final meldCards = meldIndices
        .map((i) => widget.player.currentHand[i])
        .toList();
    final points = meldCards.fold<int>(0, (sum, card) => sum + card.pointValue);
    final isValid = Meld.createMeld(meldCards) != null;
    final willAddToExisting =
        isValid &&
        meldCards.isNotEmpty &&
        widget.player.findMeldByRank(meldCards.first.rank) != -1;

    return _MeldData(
      meldIndices: meldIndices,
      meldCards: meldCards,
      points: points,
      isValid: isValid,
      willAddToExisting: willAddToExisting,
    );
  }

  ShapeBorder _getMeldCardShape(bool isValid) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: isValid
            ? const Color(0xFF10B981).withValues(alpha: 0.3)
            : const Color(0xFFEF4444).withValues(alpha: 0.3),
        width: 1,
      ),
    );
  }

  Widget _buildMeldHeader(int meldIndex, _MeldData meldData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMeldInfo(meldIndex, meldData),
        _buildMeldActions(meldIndex, meldData),
      ],
    );
  }

  Widget _buildMeldInfo(int meldIndex, _MeldData meldData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meld ${meldIndex + 1} (${meldData.meldCards.length} cards)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        if (meldData.willAddToExisting)
          Text(
            'Will add to existing ${meldData.meldCards.isNotEmpty ? meldData.meldCards.first.rank.name : ''} meld',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildMeldActions(int meldIndex, _MeldData meldData) {
    return Row(
      children: [
        _buildPointsChip(meldData),
        const SizedBox(width: 8),
        _buildDeleteButton(meldIndex),
      ],
    );
  }

  Widget _buildPointsChip(_MeldData meldData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: meldData.isValid
            ? const Color(0xFF10B981).withValues(alpha: 0.2)
            : const Color(0xFFEF4444).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        meldData.isValid ? '${meldData.points} pts' : 'Invalid',
        style: TextStyle(
          color: meldData.isValid
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDeleteButton(int meldIndex) {
    return IconButton(
      onPressed: () => _removeMeld(meldIndex),
      icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
      constraints: const BoxConstraints(),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildMeldCardChips(int meldIndex, List<int> meldIndices) {
    return Wrap(
      spacing: 4,
      children: meldIndices.asMap().entries.map((entry) {
        final cardIndex = entry.key;
        final handIndex = entry.value;
        final card = widget.player.currentHand[handIndex];
        return _buildMeldCardChip(meldIndex, cardIndex, card);
      }).toList(),
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
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _ResponsiveHelper.getGridCrossAxisCount(
                  context,
                ),
                childAspectRatio: GameConfig.cardAspectRatio,
                crossAxisSpacing: GameConfig.cardSpacing,
                mainAxisSpacing: GameConfig.cardSpacing,
              ),
              itemCount: availableCardIndices.length,
              itemBuilder: (context, index) {
                final handIndex = availableCardIndices[index];

                // Validate index to prevent out-of-bounds errors
                if (handIndex >= widget.player.currentHand.length ||
                    handIndex < 0) {
                  // Trigger immediate refresh to clean up stale state
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _refreshAvailableCards(immediate: true);
                  });
                  return const SizedBox.shrink();
                }

                final card = widget.player.currentHand[handIndex];
                final isSelected = selectedAvailableIndices.contains(index);

                return _MobileCardWidget(
                  key: ValueKey('mobile_card_$handIndex'),
                  card: card,
                  isSelected: isSelected,
                  onTap: () => _toggleCardSelection(index),
                );
              },
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
    return selectedAvailableIndices.length >= GameConfig.minTotalCardsForMeld;
  }

  void _createNewMeld() {
    // Convert selected available indices to hand indices first
    final selectedHandIndices = selectedAvailableIndices
        .map((availableIndex) => availableCardIndices[availableIndex])
        .toList();

    final selectedCards = selectedHandIndices
        .map((handIndex) => widget.player.currentHand[handIndex])
        .toList();

    // Validate meld creation using the same logic as Meld.createMeld
    final naturalCards = selectedCards.where((card) => !card.isWild).toList();
    final wildCards = selectedCards.where((card) => card.isWild).toList();

    // Check for 3s (cannot be melded)
    if (selectedCards.any((card) => card.isThree)) {
      _showError('3s cannot be melded');
      return;
    }

    // Must have at least 3 total cards
    if (selectedCards.length < GameConfig.minTotalCardsForMeld) {
      _showError(
        'Need at least ${GameConfig.minTotalCardsForMeld} total cards for a meld',
      );
      return;
    }

    // Must have at least 2 natural cards (wilds alone cannot form a meld)
    if (naturalCards.length < GameConfig.minNaturalCardsForMeld) {
      _showError(
        'Need at least ${GameConfig.minNaturalCardsForMeld} natural cards of the same rank',
      );
      return;
    }

    // All natural cards must be the same rank
    final rank = naturalCards.first.rank;
    if (!naturalCards.every((card) => card.rank == rank)) {
      _showError('All natural cards must be the same rank');
      return;
    }

    // Wild cards cannot exceed natural cards
    if (wildCards.length > naturalCards.length) {
      _showError('Wild cards cannot outnumber natural cards in a meld');
      return;
    }

    // Create the meld with proper state management
    setState(() {
      // Add the meld
      proposedMeldIndices.add(selectedHandIndices);

      // Remove selected hand indices from available cards
      // Sort hand indices in descending order to avoid index shifting issues
      final sortedHandIndices = selectedHandIndices.toList()
        ..sort((a, b) => b.compareTo(a));

      for (final handIndex in sortedHandIndices) {
        availableCardIndices.remove(handIndex);
      }

      // Clear selection completely and regenerate available indices
      selectedAvailableIndices.clear();

      // Force refresh to ensure consistent state
      _sortAvailableCardIndices();
    });
  }

  void _toggleCardSelection(int availableIndex) {
    // Validate bounds to prevent crashes
    if (availableIndex < 0 || availableIndex >= availableCardIndices.length) {
      // Force immediate refresh if we encounter invalid state
      _refreshAvailableCards(immediate: true);
      return;
    }

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

    // Only check point requirement if player hasn't played down yet
    if (!widget.player.hasPlayedDown) {
      final totalPoints = validMeldIndices
          .expand(
            (meldIndices) =>
                meldIndices.map((i) => widget.player.currentHand[i]),
          )
          .fold<int>(0, (sum, card) => sum + card.pointValue);

      if (totalPoints < widget.playDownRequirement) {
        _showError(
          'Total points ($totalPoints) do not meet requirement (${widget.playDownRequirement})',
        );
        return;
      }
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

/// Data class to hold meld information
class _MeldData {
  final List<int> meldIndices;
  final List<PlayingCard> meldCards;
  final int points;
  final bool isValid;
  final bool willAddToExisting;

  const _MeldData({
    required this.meldIndices,
    required this.meldCards,
    required this.points,
    required this.isValid,
    required this.willAddToExisting,
  });
}

/// Mobile-optimized card widget for better touch and scroll performance
class _MobileCardWidget extends StatelessWidget {
  const _MobileCardWidget({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
            width: _ResponsiveHelper.getCardWidth(context),
            height: _ResponsiveHelper.getCardHeight(context),
            isSelected: isSelected,
          ),
        ),
      ),
    );
  }
}
