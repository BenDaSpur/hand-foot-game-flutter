import 'dart:io';

import 'ads_service.dart';
import 'ads_service_mobile.dart';

AdsService createAdsService() {
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileAdsService();
  }
  return NoOpAdsService();
}
