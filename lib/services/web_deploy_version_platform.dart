import 'web_deploy_version_platform_stub.dart'
    if (dart.library.html) 'web_deploy_version_platform_web.dart'
    as platform;

Future<String?> fetchDeployVersionJson() => platform.fetchVersionJson();

void reloadDeployWebPage() => platform.reloadWebPage();
