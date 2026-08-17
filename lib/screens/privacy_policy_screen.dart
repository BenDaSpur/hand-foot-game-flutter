import 'package:flutter/material.dart';
import '../legal/privacy_policy_content.dart';
import '../theme/balatro_theme.dart';

/// In-app Privacy Policy. The same policy is published at
/// https://playhandfoot.com/privacy.html for crawlers and external listings.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BalatroTheme.deepPurple,
      appBar: AppBar(
        backgroundColor: BalatroTheme.darkPurple,
        elevation: 0,
        title: Text(
          PrivacyPolicyContent.title,
          style: const TextStyle(
            color: BalatroTheme.neonBlue,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: BalatroTheme.glowColor),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a0d2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: SelectionArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                  children: [
                    Text(
                      PrivacyPolicyContent.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: BalatroTheme.neonBlue,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${PrivacyPolicyContent.lastUpdated}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      PrivacyPolicyContent.website,
                      style: const TextStyle(
                        color: BalatroTheme.neonPink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      PrivacyPolicyContent.intro,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final section in PrivacyPolicyContent.sections) ...[
                      Text(
                        section.title,
                        style: const TextStyle(
                          color: BalatroTheme.neonPink,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section.body,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
