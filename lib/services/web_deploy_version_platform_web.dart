// Web-only implementation (conditionally imported).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<String?> fetchVersionJson() async {
  try {
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    return await html.HttpRequest.getString('/version.json?_=$cacheBuster');
  } catch (_) {
    return null;
  }
}

void reloadWebPage() {
  html.window.location.reload();
}
