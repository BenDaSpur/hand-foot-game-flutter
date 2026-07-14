import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tutorial/learn_to_play_session.dart';
import 'game_screen.dart';

/// Learn to Play entry — runs the guided lesson on the real [GameScreen] UI.
class LearnToPlayScreen extends StatefulWidget {
  const LearnToPlayScreen({super.key});

  @override
  State<LearnToPlayScreen> createState() => _LearnToPlayScreenState();
}

class _LearnToPlayScreenState extends State<LearnToPlayScreen> {
  late final LearnToPlaySession _session = LearnToPlaySession.create();

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: GameScreen(
        gameController: _session.controller,
        learnToPlaySession: _session,
      ),
    );
  }
}
