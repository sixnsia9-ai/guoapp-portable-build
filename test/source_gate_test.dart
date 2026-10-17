import 'package:duanju_app/app_build.dart';
import 'package:duanju_app/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy source password does not hide compiled sources', () async {
    SharedPreferences.setMockInitialValues(legacyGatePreferences);
    final store = testStore(await SharedPreferences.getInstance());
    addTearDown(store.dispose);
    expect(store.configurationError, isNull);
    expect(store.sources, SourceSite.values);
    expect(store.sources.length, allSourcesEnabled ? 10 : 1);
    expect(store.allowsSource('guipian'), isFalse);
  });
}
