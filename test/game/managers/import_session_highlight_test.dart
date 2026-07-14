import 'package:flutter_test/flutter_test.dart';
import 'package:hand_foot_game_flutter/game/game_controller.dart';
import 'package:hand_foot_game_flutter/models/card.dart';

void main() {
  // Exact export from session_17840009637893789 (user paste).
  const export =
      'eyJ2IjozLCJzIjo3OTE1OTEsImciOnsicCI6MSwidCI6MSwiciI6MiwiYyI6MCwiZiI6dHJ1ZSwiZCI6dHJ1ZSwibSI6ZmFsc2UsInEiOjkwfSwicGxheWVycyI6W3siaWQiOiIxIiwibiI6IllvdSIsInQiOjAsInNjIjoyODQwLCJwZCI6ZmFsc2UsImZ0IjpmYWxzZSwibWVsZHMiOltdLCJoIjpbIjQsMCIsIjQsMyIsIjUsMCIsIjUsMyIsIjUsMyIsIjUsMiIsIjcsMCIsIjcsMSIsIjEwLDAiLCIxMCwxIiwiMTEsMSIsIjExLDMiLCIxMSwwIiwiMTIsMSIsIjEyLDIiLCIxMiwwIiwiMCwxIiwiMSwyIiwiMSwzIiwiMSwwIl0sImYiOlsiOSwyIiwiOCwxIiwiMCwxIiwiMTAsMCIsIjEsMiIsIjEyLDIiLCI4LDAiLCIzLDEiLCI2LDAiLCIzLDIiLCIxMiwwIl0sInJzaCI6W3siciI6MSwiY3AiOjU0MCwiY2IiOjMsImRiIjoyLCJwcCI6MCwiZ2IiOjEwMCwidHMiOjI3NDB9XX0seyJpZCI6IjIiLCJuIjoiU3VlIiwidCI6MSwic2MiOjE2MzAsInBkIjpmYWxzZSwiZnQiOmZhbHNlLCJtZWxkcyI6W10sImgiOlsiNCwwIiwiNSwyIiwiNSwzIiwiNSwwIiwiNSwxIiwiNiwyIiwiNywxIiwiNywxIiwiNywzIiwiOCwyIiwiOSwzIiwiOSwyIiwiOSwyIiwiMTAsMyIsIjExLDEiLCIxMSwwIiwiMTIsMyIsIjAsMCJdLCJmIjpbIjEsMCIsIjEwLDIiLCIxMSwyIiwiMTMsIiwiNywzIiwiMTMsIiwiOSwyIiwiNywwIiwiNCwzIiwiMSwyIiwiMTEsMSJdLCJyc2giOlt7InIiOjEsImNwIjo1NTAsImNiIjoxLCJkYiI6MiwicHAiOjIwLCJnYiI6MCwidHMiOjE2MzB9XX0seyJpZCI6IjMiLCJuIjoiQ2xhcmEiLCJ0IjoxLCJzYyI6MTgwNSwicGQiOnRydWUsImZ0IjpmYWxzZSwibWVsZHMiOlt7InQiOjEsImMiOlsiNCwzIiwiNCwyIiwiMSwzIl19LHsidCI6MCwiYyI6WyIwLDEiLCIwLDMiLCIwLDAiXX0seyJ0IjoxLCJjIjpbIjEyLDIiLCIxMiwyIiwiMSwxIl19LHsidCI6MSwiYyI6WyI2LDEiLCI2LDIiLCIxLDEiLCI2LDMiXX1dLCJoIjpbIjgsMSIsIjksMyIsIjksMyIsIjExLDMiLCIxMSwyIl0sImYiOlsiMTMsIiwiNCwyIiwiMTMsIiwiNywwIiwiMSwzIiwiMiwyIiwiMTIsMyIsIjEsMSIsIjUsMSIsIjAsMyIsIjQsMSJdLCJyc2giOlt7InIiOjEsImNwIjo1NDAsImNiIjoyLCJkYiI6MSwicHAiOjM1LCJnYiI6MCwidHMiOjE4MDV9XX1dLCJkZWNrIjp7InN6IjoxMDUsInMiOjc5MTU5MSwidG9wIjoiMCwzIn0sImRwIjpbIjEsMyIsIjIsMiIsIjIsMyIsIjUsMiIsIjMsMCIsIjcsMSIsIjIsMCIsIjgsMyIsIjMsMiIsIjMsMiIsIjIsMyIsIjUsMSIsIjIsMSIsIjYsMyIsIjIsMSIsIjMsMyIsIjYsMCIsIjMsMyIsIjMsMSIsIjksMSIsIjQsMSIsIjcsMCJdLCJyYSI6W3sibSI6IuKPre+4jyBjaG9zZSBub3QgdG8gbWVsZCIsInAiOiJTdWUiLCJ0IjoxNzg0MDAyNjg0ODUyfSx7Im0iOiLwn5eR77iPIGRpc2NhcmRlZCAzIOKZpiIsInAiOiJTdWUiLCJ0IjoxNzg0MDAyNjg3ODYyfSx7Im0iOiLwn460IGRyZXcgMiBjYXJkcyBmcm9tIGRlY2siLCJwIjoiQ2xhcmEiLCJ0IjoxNzg0MDAyNjkxMzc2fSx7Im0iOiJwbGF5ZWQgZG93biB3aXRoIDkwIHBvaW50czogbmV3IGZpdmU6IDUg4pmgLCA1IOKZoywgMiDimaA7IG5ldyBhY2U6IEEg4pmmLCBBIOKZoCwgQSDimaUiLCJwIjoiQ2xhcmEiLCJ0IjoxNzg0MDAyNjkzNjg1fSx7Im0iOiLwn5OLIGNyZWF0ZWQgbmV3IG1lbGQ6IEsg4pmjLCBLIOKZoywgMiDimaYiLCJwIjoiQ2xhcmEiLCJ0IjoxNzg0MDAyNjk0NDk0fSx7Im0iOiLwn5OLIGNyZWF0ZWQgbmV3IG1lbGQ6IDcg4pmmLCA3IOKZoywgMiDimaYiLCJwIjoiQ2xhcmEiLCJ0IjoxNzg0MDAyNjk1Mjk2fSx7Im0iOiLij63vuI8gY2hvc2Ugbm90IHRvIG1lbGQiLCJwIjoiQ2xhcmEiLCJ0IjoxNzg0MDAyNjk2MTAzfSx7Im0iOiLwn5eR77iPIGRpc2NhcmRlZCA0IOKZoCIsInAiOiJDbGFyYSIsInQiOjE3ODQwMDI2OTkxMTN9LHsibSI6IvCfjq8gZHJldzogNyDimaUsIFEg4pmgIiwicCI6IllvdSIsInQiOjE3ODQwMDI3MDk5NzV9LHsibSI6IvCfl5HvuI8gZGlzY2FyZGVkIDcg4pmlIiwicCI6IllvdSIsInQiOjE3ODQwMDI3MTg0NzR9LHsibSI6IvCfjrQgZHJldyAyIGNhcmRzIGZyb20gZGVjayIsInAiOiJTdWUiLCJ0IjoxNzg0MDAyNzE4OTc4fSx7Im0iOiJmb3JjZWQgZGlzY2FyZCBvZiBGb3Vy4pmgIiwicCI6IlN1ZSIsInQiOjE3ODQwMDI3MjEyODh9LHsibSI6IvCfjrQgZHJldyAyIGNhcmRzIGZyb20gZGVjayIsInAiOiJDbGFyYSIsInQiOjE3ODQwMDI3MjE3OTh9LHsibSI6IuKPre+4jyBjaG9zZSBub3QgdG8gbWVsZCIsInAiOiJDbGFyYSIsInQiOjE3ODQwMDI3MjQxMDl9LHsibSI6IvCfl5HvuI8gZGlzY2FyZGVkIDQg4pmmIiwicCI6IkNsYXJhIiwidCI6MTc4NDAwMjcyNzExM30seyJtIjoi8J+OryBkcmV3OiA2IOKZoywgSyDimaUiLCJwIjoiWW91IiwidCI6MTc4NDAwMjc0NDg3Nn0seyJtIjoi8J+Xke+4jyBkaXNjYXJkZWQgMTAg4pmmIiwicCI6IllvdSIsInQiOjE3ODQwMDI3NjE1MDh9LHsibSI6IvCfjrQgZHJldyAyIGNhcmRzIGZyb20gZGVjayIsInAiOiJTdWUiLCJ0IjoxNzg0MDAyNzYyMDE3fSx7Im0iOiJmb3JjZWQgZGlzY2FyZCBvZiBGaXZl4pmmIiwicCI6IlN1ZSIsInQiOjE3ODQwMDI3NjQzMjd9LHsibSI6IvCfjrQgZHJldyAyIGNhcmRzIGZyb20gZGVjayIsInAiOiJDbGFyYSIsInQiOjE3ODQwMDI3NjQ4MzF9LHsibSI6IuKelSBhZGRlZCA3IOKZoCB0byBleGlzdGluZyBtZWxkIiwicCI6IkNsYXJhIiwidCI6MTc4NDAwMjc2NzE0Mn0seyJtIjoi4o+t77iPIGNob3NlIG5vdCB0byBtZWxkIiwicCI6IkNsYXJhIiwidCI6MTc4NDAwMjc2Nzk0NH0seyJtIjoi8J+Xke+4jyBkaXNjYXJkZWQgOCDimaUiLCJwIjoiQ2xhcmEiLCJ0IjoxNzg0MDAyNzcwOTU1fSx7Im0iOiLwn46vIGRyZXc6IEEg4pmmLCBRIOKZpSIsInAiOiJZb3UiLCJ0IjoxNzg0MDAyNzg4MjYwfV0sImJwIjp7IjIiOiJCb3RQZXJzb25hbGl0eS5hZGFwdGl2ZSIsIjMiOiJCb3RQZXJzb25hbGl0eS5jb25zZXJ2YXRpdmUifX0=';

  test(
    'imported session: Jacks/5s/8s playable with wilds via contains and indices',
    () {
      final result = GameController.fromExportJson(export);
      expect(result, isNotNull);
      final gc = result!.controller;
      final human = gc.gameState.players.first;

      final melds = gc.findPossibleMelds(human);

      final jackIndices = <int>[];
      for (var i = 0; i < human.currentHand.length; i++) {
        if (human.currentHand[i].rank == CardRank.jack) {
          jackIndices.add(i);
        }
      }
      expect(jackIndices, hasLength(2));

      for (final i in jackIndices) {
        final card = human.currentHand[i];
        final viaContains = melds.any((m) => m.contains(card));
        expect(
          viaContains,
          isTrue,
          reason: 'Jack at $i must be in findPossibleMelds (old UI check)',
        );
      }

      final indices = gc.getPlayableCardIndices(human);
      for (final i in jackIndices) {
        expect(indices.contains(i), isTrue, reason: 'Jack index $i playable');
      }
      // First two cards are 5s; indices 6-7 are 8s in this export.
      expect(indices.contains(0), isTrue);
      expect(indices.contains(6), isTrue);
      expect(indices.contains(7), isTrue);
    },
    tags: ['regression'],
  );
}
