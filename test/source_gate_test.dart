import 'package:duanju_app/app_build.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/source_gate_dialog.dart';
import 'package:duanju_app/source_gate_taps.dart';
import 'package:duanju_app/portable_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ���������˸���ö������������̶���걣֤ pump ������Ԥ�ڡ�
  EditableText.debugDeterministicCursor = true;
  Future<LocalStore> create([
    Map<String, Object> initial = const {},
    TargetPlatform platform = TargetPlatform.android,
  ]) async {
    SharedPreferences.setMockInitialValues(Map.of(initial));
    final preferences = await SharedPreferences.getInstance();
    debugDefaultTargetPlatformOverride = platform;
    late final LocalStore store;
    try {
      store = testStore(preferences);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    addTearDown(store.dispose);
    return store;
  }

  test('default visibility hides restricted sources', () async {
    final store = await create();
    expect(store.sourceGateEnabled, isFalse);
    expect(store.sourcesUnlocked, isFalse);
    expect(
      store.sources.map((site) => site.id),
      allSourcesEnabled ? ['hongguo', 'hanxiaoquan', 'sorani'] : ['hongguo'],
    );
    expect(store.allowsSource('huangdou'), isFalse);
    expect(store.allowsSource('hongguo'), isTrue);
    // δ����������ʱ�޴��������룬��Ҫ���ڵ��������á�
    await expectLater(store.unlockSources('666'), throwsStateError);
    expect(store.sourcesUnlocked, isFalse);
  });

  test('fresh portable storage shows every compiled source', () async {
    portableStorageEnabled = true;
    addTearDown(() => portableStorageEnabled = false);
    final store = await create();
    expect(store.sourceGateOff, isTrue);
    expect(store.sources.length, allSourcesEnabled ? 10 : 1);
  });

  test('fresh Windows all-source build shows every compiled source', () async {
    final store = await create(const {}, TargetPlatform.windows);
    expect(store.sources.length, allSourcesEnabled ? 10 : 1);
    expect(store.allowsSource('guipian'), isFalse);
  });

  test('existing Windows source password still hides restricted sources', () async {
    final store = await create(await gatePreferences(), TargetPlatform.windows);
    expect(store.sourceGateEnabled, isTrue);
    expect(store.sources.length, allSourcesEnabled ? 3 : 1);
  });

  test('enabling the gate hides restricted sources and unlocks once', () async {
    final store = await create();
    await store.enableSourceGate('666');
    expect(store.sourceGateEnabled, isTrue);
    expect(store.sourcesUnlocked, isTrue);
    expect(store.sources.length, allSourcesEnabled ? 10 : 1);

    store.lockSources();
    expect(store.sourcesUnlocked, isFalse);
    expect(store.sources.length, allSourcesEnabled ? 3 : 1);
    expect(store.allowsSource('huangdou'), isFalse);
    expect(store.allowsSource('hongguo'), isTrue);
    if (allSourcesEnabled) expect(store.allowsSource('sorani'), isTrue);

    await expectLater(store.unlockSources('777'), throwsStateError);
    expect(store.sourcesUnlocked, isFalse);
    await store.unlockSources('666');
    expect(store.sourcesUnlocked, isTrue);
    expect(store.sources.length, allSourcesEnabled ? 10 : 1);
  });

  test('a saved gate hides sources again after restart', () async {
    final store = await create();
    await store.enableSourceGate('666');
    store.lockSources();
    final restarted = testStore(store.preferences);
    addTearDown(restarted.dispose);
    expect(restarted.sourceGateEnabled, isTrue);
    expect(restarted.sourcesUnlocked, isFalse);
    expect(restarted.sources.length, allSourcesEnabled ? 3 : 1);
    await restarted.unlockSources('666');
    expect(restarted.sourcesUnlocked, isTrue);
  });

  test('disabling the gate restores every compiled source', () async {
    final store = await create();
    await store.enableSourceGate('666');
    store.lockSources();
    await store.disableSourceGate();
    expect(store.sourceGateEnabled, isFalse);
    expect(store.sourcesUnlocked, isTrue);
    expect(store.sources.length, allSourcesEnabled ? 10 : 1);
  });

  test('an invalid pin must be 3 to 12 digits', () async {
    final store = await create();
    await expectLater(store.enableSourceGate('12'), throwsStateError);
    await expectLater(store.enableSourceGate('abcdef'), throwsStateError);
    await expectLater(
      store.enableSourceGate('1234567890123'),
      throwsStateError,
    );
    expect(store.sourceGateEnabled, isFalse);
  });

  test('repeated taps on one entry only fire after six in a row', () {
    final gate = RepeatTapGate();
    for (var i = 0; i < 5; i++) {
      expect(gate.register(2), isFalse);
    }
    expect(gate.register(2), isTrue);
    expect(gate.register(2), isFalse);
    gate.reset();
    for (var i = 0; i < 5; i++) {
      expect(gate.register(2), isFalse);
    }
    // �л���ڻ���������������󴥷���
    expect(gate.register(0), isFalse);
    for (var i = 0; i < 5; i++) {
      expect(gate.register(2), isFalse);
    }
    expect(gate.register(2), isTrue);
  });

  test('a damaged gate record keeps hiding restricted sources', () async {
    final store = await create({
      'sourceGateEnabled': true,
      'sourceGateSalt': 'bad',
      'sourceGateHash': 'bad',
    });
    expect(store.configurationError, isNull);
    expect(store.sourceGateEnabled, isFalse);
    expect(store.sourcesUnlocked, isFalse);
    expect(store.sources.length, allSourcesEnabled ? 3 : 1);
  });

  test('a user-disabled gate keeps every compiled source visible', () async {
    final store = await create({
      'sourceGateEnabled': false,
      'sourceGateOff': true,
    });
    expect(store.sourceGateEnabled, isFalse);
    expect(store.sourcesUnlocked, isTrue);
    expect(store.sources.length, allSourcesEnabled ? 10 : 1);
  });

  // �������������������첽�ص����ù̶��������� pumpAndSettle��
  // ���ⲻ�����Ķ����ò��Թҵ� 10 ����Ĭ�ϳ�ʱ��
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('the gate dialog offers enabling, unlocking and locking', (
    tester,
  ) async {
    final store = await create();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSourceGateDialog(context, store),
              child: const Text('��'),
            ),
          ),
        ),
      ),
    );

    // δ����ʱ���û�����������������ѡ��
    await tester.tap(find.text('��'));
    await settle(tester);
    expect(find.text('վԴ������'), findsOneWidget);
    expect(find.text('����������'), findsOneWidget);
    expect(find.text('����'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '666');
    await tester.enterText(find.byType(TextField).last, '666');
    await tester.tap(find.text('����������'));
    await settle(tester);
    expect(store.sourceGateEnabled, isTrue);
    expect(store.sourcesUnlocked, isTrue);

    // ���������ѽ���ʱ�ṩ�������������롸�ر����빦�ܡ���
    await tester.tap(find.text('��'));
    await settle(tester);
    expect(find.text('��������'), findsOneWidget);
    expect(find.text('�ر����빦��'), findsOneWidget);
    await tester.tap(find.text('��������'));
    await settle(tester);
    expect(store.sourcesUnlocked, isFalse);

    // ������Ҫ������������ܽ�����
    await tester.tap(find.text('��'));
    await settle(tester);
    expect(find.text('����'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '666');
    await tester.tap(find.text('����'));
    await settle(tester);
    expect(store.sourcesUnlocked, isTrue);

    // �Կɹر����빦�ܣ��ָ�ȫ��վԴ�ɼ���
    await tester.tap(find.text('��'));
    await settle(tester);
    await tester.tap(find.text('�ر����빦��'));
    await settle(tester);
    expect(store.sourceGateEnabled, isFalse);
    expect(store.sourcesUnlocked, isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
