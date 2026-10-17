import 'dart:convert';

import 'package:duanju_app/app_build.dart';
import 'package:duanju_app/core_bridge.dart';
import 'package:duanju_app/local_profiles.dart';
import 'package:duanju_app/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const red = FixtureRepository.free;
  const other = FixtureRepository.vip;

  test('edition sources include DSD only in the all-source build', () async {
    SharedPreferences.setMockInitialValues({
      'source': 'huangdou',
      'sourceGateEnabled': false,
      'sourceGateOff': false,
    });
    final store = testStore(await SharedPreferences.getInstance());
    expect(appSlug, allSourcesEnabled ? 'zhenguojian' : 'hongguojian');
    // Ĭ��ֻ��ʾ�������СȦ����մ�Ԫ������վԴ��Ҫ���������
    expect(store.sources.length, allSourcesEnabled ? 3 : 1);
    expect(
      SourceSite.values.any((source) => source.id == 'dsd'),
      allSourcesEnabled,
    );
    expect(SourceSite.isAvailable('dsd'), allSourcesEnabled);
    expect(SourceSite.isKnown('dsd'), isTrue);
    expect(SourceSite.isKnown('guipian'), isTrue);
    expect(SourceSite.isAvailable('guipian'), isFalse);
    expect(store.allowsSource('guipian'), isFalse);
    expect(SourceSite.byId('dsd').name, '�۹�');
    expect(store.allowsSource('dsd'), isFalse);
    expect(store.source, 'hongguo');
    await store.enableSourceGate('666666');
    expect(store.sourcesUnlocked, isTrue);
    expect(store.sources.length, allSourcesEnabled ? 10 : 1);
    expect(store.allowsSource('dsd'), allSourcesEnabled);
    store.dispose();
  });

  test(
    'edition filtering preserves favorites and history through backup restore',
    () async {
      final history = [
        for (final drama in [red, other])
          WatchEntry(
            drama: drama,
            episode: 1,
            position: 12,
            duration: 60,
            updatedAt: DateTime(2026, 9, 19),
          ).toJson(),
      ];
      SharedPreferences.setMockInitialValues({
        'source': 'huangdou',
        'favorites': jsonEncode([red.toJson(), other.toJson()]),
        'history': jsonEncode(history),
      });
      final store = testStore(await SharedPreferences.getInstance());
      // ����ԱĬ�Ͽɼ�ȫ��վԴ����������ʽ��������������֤���ú���Ϊһ�¡�
      await store.enableSourceGate('666666');
      expect(store.favorites.length, allSourcesEnabled ? 2 : 1);
      expect(store.history.length, allSourcesEnabled ? 2 : 1);
      expect(store.isFavorite(other.id), allSourcesEnabled);
      expect(store.watched(other.id) != null, allSourcesEnabled);
      await store.toggleFavorite(red);
      final backup = await store.exportBackup();
      final library =
          (jsonDecode(backup)['libraries'] as Map)['default'] as Map;
      expect((library['favorites'] as List).map((row) => (row as Map)['id']), [
        other.id,
      ]);
      expect(library['history'], hasLength(2));
      await store.importBackup(backup);
      await store.enableSourceGate('666666');
      expect(store.preferences.getString('source'), 'huangdou');
      expect(store.history, hasLength(allSourcesEnabled ? 2 : 1));
      expect(
        store.favorites.map((drama) => drama.id),
        allSourcesEnabled ? [other.id] : <String>[],
      );
      store.dispose();
    },
  );

  test(
    'a restored foreign-source profile keeps its identity and permissions',
    () async {
      SharedPreferences.setMockInitialValues({
        ...await gatePreferences(),
        'profiles': jsonEncode([
          LocalProfile(
            id: 'default',
            name: '����Ա',
            admin: true,
            salt: '0' * 32,
            pinHash: '1' * 64,
          ).toJson(),
          const LocalProfile(
            id: 'viewer',
            name: '�����û�',
            sources: ['huangdou'],
            download: false,
          ).toJson(),
        ]),
        'activeProfile': 'viewer',
        'profile.viewer.source': 'huangdou',
      });
      final store = testStore(await SharedPreferences.getInstance());
      await unlockGate(store);
      expect(store.profile.id, 'viewer');
      expect(store.profile.admin, isFalse);
      expect(store.profile.sources, ['huangdou']);
      expect(store.canDownload, isFalse);
      expect(store.source, allSourcesEnabled ? 'huangdou' : '');
      expect(store.allowsSource('hongguo'), isFalse);
      expect(store.allowsSource('huangdou'), allSourcesEnabled);
      store.dispose();
    },
  );

  test('restored DSD profile data follows edition availability', () async {
    SharedPreferences.setMockInitialValues({
      ...await gatePreferences(),
      'profiles': jsonEncode([
        LocalProfile(
          id: 'default',
          name: '����Ա',
          admin: true,
          salt: '0' * 32,
          pinHash: '1' * 64,
        ).toJson(),
        const LocalProfile(
          id: 'viewer',
          name: '�۹����û�',
          sources: ['dsd'],
          download: false,
        ).toJson(),
      ]),
      'activeProfile': 'viewer',
      'profile.viewer.source': 'dsd',
    });
    final store = testStore(await SharedPreferences.getInstance());
    await unlockGate(store);
    expect(store.configurationError, isNull);
    expect(store.profile.sources, ['dsd']);
    expect(
      store.sources.map((source) => source.id),
      allSourcesEnabled ? ['dsd'] : [],
    );
    expect(store.source, allSourcesEnabled ? 'dsd' : '');
    expect(store.allowsSource('dsd'), allSourcesEnabled);
    store.dispose();
  });

  test('removed Guipian source keeps existing profile readable', () async {
    SharedPreferences.setMockInitialValues({
      'profiles': jsonEncode([
        LocalProfile(
          id: 'default',
          name: '����Ա',
          admin: true,
          salt: '0' * 32,
          pinHash: '1' * 64,
        ).toJson(),
        const LocalProfile(
          id: 'viewer',
          name: '���û�',
          sources: ['guipian'],
        ).toJson(),
      ]),
      'activeProfile': 'viewer',
      'profile.viewer.source': 'guipian',
    });
    final store = testStore(await SharedPreferences.getInstance());
    expect(store.configurationError, isNull);
    expect(store.profile.sources, ['guipian']);
    expect(store.sources, isEmpty);
    expect(store.source, isEmpty);
    store.dispose();
  });

  test(
    'background requests reject unavailable sources before native I/O',
    () async {
      final repository = NativeRepository(background: true);
      final denied = [
        ...SourceSite.allValues
            .where((source) => !SourceSite.isAvailable(source.id))
            .map((source) => source.id),
        'unknown',
        'guipian',
      ];
      for (final source in denied) {
        final drama = Drama(id: '$source:123', source: source, title: '�ϳ�����');
        final episode = Episode({'id': '1'}, 1);
        for (final request in [
          () => repository.catalog(source),
          () => repository.cached(source),
          () => repository.sourceStatus(source),
          () => repository.startSourceJob(source, 'update'),
          () => repository.cancelSourceJob(source),
          () => repository.detail(drama),
          () => repository.cover(drama),
          () => repository.resolve(drama, episode),
          () => repository.resolveOnline(drama, episode),
          () => repository.enqueueDownloads(DramaDetail(drama, [episode]), [
            episode,
          ]),
          () => repository.localPlayback(drama, episode),
        ]) {
          await expectLater(
            request(),
            throwsA(
              isA<AppFailure>().having(
                (error) => error.message,
                'message',
                '��ǰ�汾��������վԴ',
              ),
            ),
          );
        }
      }
    },
  );
}
