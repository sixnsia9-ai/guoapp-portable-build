import 'package:duanju_app/library_updater.dart';
import 'package:duanju_app/models.dart';
import 'package:duanju_app/source_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

class AutoUpdateRepository extends FixtureRepository {
  final statuses = <String, SourceStatus>{};
  final operations = <String>[];

  @override
  bool get supportsSourceManagement => true;

  @override
  Future<SourceStatus> sourceStatus(String source) async => statuses[source]!;

  @override
  Future<SourceStatus> startSourceJob(
    String source,
    String operation, {
    Drama? drama,
  }) async {
    operations.add('$source:$operation');
    return statuses[source] = SourceStatus.fromJson({
      'source': source,
      'operation': operation,
      'running': true,
    });
  }
}

void main() {
  test(
    'auto update starts only stale sources and does not repeat a recent failure',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = testStore(await SharedPreferences.getInstance());
      final repository = AutoUpdateRepository();
      final now = DateTime.now();
      final staleSource = store.sources.first.id;
      for (final source in store.sources) {
        repository.statuses[source.id] = SourceStatus.fromJson({
          'source': source.id,
          'updatedAt':
              (source.id == staleSource
                      ? now.subtract(const Duration(days: 2))
                      : now)
                  .toIso8601String(),
        });
      }
      final updater = LibraryUpdater(repository, store);
      await updater.refresh();
      expect(repository.operations, isEmpty);
      await store.setAutoUpdateSources(true);
      repository.statuses[staleSource] = SourceStatus.fromJson({
        'source': staleSource,
        'updatedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        'retryAt': now.add(const Duration(minutes: 1)).toIso8601String(),
      });
      await updater.refresh();
      expect(repository.operations, isEmpty);
      repository.statuses[staleSource] = SourceStatus.fromJson({
        'source': staleSource,
        'updatedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
      });
      await updater.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(repository.operations, ['$staleSource:update']);
      await updater.refresh();
      expect(repository.operations, ['$staleSource:update']);
      updater.dispose();

      repository.statuses[staleSource] = SourceStatus.fromJson({
        'source': staleSource,
        'updatedAt': now.subtract(const Duration(days: 2)).toIso8601String(),
        'operation': 'update',
        'finishedAt': now.toIso8601String(),
        'error': '合成访问失败',
      });
      final restarted = LibraryUpdater(repository, store);
      await restarted.refresh();
      expect(repository.operations, ['$staleSource:update']);
      restarted.dispose();
      store.dispose();
    },
  );
}
