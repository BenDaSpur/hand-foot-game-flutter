// Conditional export based on platform
export 'web_llm_service_stub.dart'
    if (dart.library.js_interop) 'web_llm_service_web.dart';
