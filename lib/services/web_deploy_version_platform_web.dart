import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';

const Duration _requestTimeout = Duration(seconds: 10);

Future<String?> fetchVersionJson() async {
  final abortController = AbortController();
  final timer = Timer(_requestTimeout, abortController.abort);

  try {
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final response = await window
        .fetch(
          '/version.json?_=$cacheBuster'.toJS,
          RequestInit(signal: abortController.signal),
        )
        .toDart;

    if (!response.ok) {
      return null;
    }

    return (await response.text().toDart).toDart;
  } catch (_) {
    return null;
  } finally {
    timer.cancel();
  }
}

void reloadWebPage() {
  window.location.reload();
}
