import 'package:flutter/material.dart';

import 'ads_service.dart';

/// Anchored menu banner. Shrinks to nothing on web/desktop or before consent.
class AdsBanner extends StatelessWidget {
  const AdsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdsService.instance,
      builder: (context, _) {
        if (!AdsService.instance.isBannerAvailable) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AdsService.instance.buildBanner(context),
          ),
        );
      },
    );
  }
}
