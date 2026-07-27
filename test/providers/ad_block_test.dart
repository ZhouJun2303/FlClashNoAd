import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ad_block.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('AdBlockSetting provider', () {
    test('defaults to enabled with detailed logging off', () {
      final props = container.read(adBlockSettingProvider);

      expect(props.enabled, true);
      expect(props.detailedLog, false);
      expect(props.allowDomains, isEmpty);
      expect(props.blockDomains, isEmpty);
      expect(props.blockDomainSuffixes, isEmpty);
      expect(props.bypassPackages, isEmpty);
    });

    test('updates manual rule and bypass state', () {
      final notifier = container.read(adBlockSettingProvider.notifier);

      notifier.update(
        (state) => state.copyWith(
          allowDomains: ['allow.example.com'],
          blockDomains: ['block.example.com'],
          blockDomainSuffixes: ['tracker.example.com'],
          bypassPackages: ['com.example.app'],
          detailedLog: true,
        ),
      );

      final props = container.read(adBlockSettingProvider);
      expect(props.allowDomains, ['allow.example.com']);
      expect(props.blockDomains, ['block.example.com']);
      expect(props.blockDomainSuffixes, ['tracker.example.com']);
      expect(props.bypassPackages, ['com.example.app']);
      expect(props.detailedLog, true);
    });
  });

  group('AdBlockSnapshot provider', () {
    test('adds newest events first and caps at snapshot capacity', () {
      final notifier = container.read(adBlockSnapshotProvider.notifier);
      notifier.replace(const AdBlockSnapshot(capacity: 2));

      notifier.addEvent(_event('1', 'one.example.com'));
      notifier.addEvent(_event('2', 'two.example.com'));
      notifier.addEvent(_event('3', 'three.example.com'));

      final snapshot = container.read(adBlockSnapshotProvider);
      expect(snapshot.events.map((event) => event.id), ['3', '2']);
      expect(snapshot.totalBlocked, 3);
      expect(snapshot.sessionBlocked, 3);
    });

    test('clear removes memory events and resets counters', () {
      final notifier = container.read(adBlockSnapshotProvider.notifier);
      notifier.addEvent(_event('1', 'ads.example.com'));

      notifier.clear();

      final snapshot = container.read(adBlockSnapshotProvider);
      expect(snapshot.events, isEmpty);
      expect(snapshot.totalBlocked, 0);
      expect(snapshot.sessionBlocked, 0);
    });
  });
}

AdBlockEvent _event(String id, String host) {
  return AdBlockEvent(
    id: id,
    time: DateTime(2026),
    host: host,
    network: 'tcp',
    source: 'anti-ad',
    rule: 'RuleSet',
    ruleProvider: '__noad_anti_ad',
  );
}