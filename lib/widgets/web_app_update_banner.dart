import 'package:flutter/material.dart';

import '../services/web_deploy_version_service.dart';
import '../theme/balatro_theme.dart';

/// Banner shown when a newer web deploy is available.
class WebAppUpdateBanner extends StatelessWidget {
  const WebAppUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: BalatroTheme.cardBackground,
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: BalatroTheme.lightPurple.withValues(alpha: 0.6),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.system_update_alt,
                    color: BalatroTheme.lightPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'A new version is available.',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: reloadForNewDeploy,
                    style: FilledButton.styleFrom(
                      backgroundColor: BalatroTheme.lightPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reload'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
