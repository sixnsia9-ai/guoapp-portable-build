import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

class _PortablePaths extends PathProviderWindows {
  _PortablePaths(this.root);

  final String root;

  @override
  Future<String> getApplicationSupportPath() async => root;

  @override
  Future<String> getApplicationCachePath() async =>
      (await Directory(path.join(root, 'cache')).create(recursive: true)).path;
}

Future<void> configurePortableStorage() async {
  if (!Platform.isWindows) return;
  final bundle = File(Platform.resolvedExecutable).parent;
  if (!await File(path.join(bundle.path, 'portable.flag')).exists()) return;
  final root = (await Directory(
    path.join(bundle.path, 'user_data'),
  ).create(recursive: true)).path;
  final provider = _PortablePaths(root);
  PathProviderPlatform.instance = provider;
  SharedPreferencesWindows.registerWith();
  final preferences =
      SharedPreferencesStorePlatform.instance as SharedPreferencesWindows;
  // shortcut: shared_preferences_windows exposes this hook for tests; replace when it offers a public path API.
  // ignore: invalid_use_of_visible_for_testing_member
  preferences.pathProvider = provider;
}
