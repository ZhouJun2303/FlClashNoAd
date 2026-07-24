import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adBlockSettingProvider = NotifierProvider<AdBlockSetting, AdBlockProps>(
  AdBlockSetting.new,
  name: 'adBlockSettingProvider',
);

class AdBlockSetting extends Notifier<AdBlockProps> {
  @override
  AdBlockProps build() {
    return const AdBlockProps();
  }

  AdBlockProps get value => state;

  set value(AdBlockProps value) {
    state = value;
  }

  void update(AdBlockProps Function(AdBlockProps value) builder) {
    final next = builder(state);
    if (next == state) {
      return;
    }
    state = next;
  }
}

final adBlockSnapshotProvider =
    NotifierProvider<AdBlockSnapshotNotifier, AdBlockSnapshot>(
  AdBlockSnapshotNotifier.new,
  name: 'adBlockSnapshotProvider',
);

class AdBlockSnapshotNotifier extends Notifier<AdBlockSnapshot> {
  @override
  AdBlockSnapshot build() {
    return const AdBlockSnapshot();
  }

  void replace(AdBlockSnapshot snapshot) {
    state = snapshot;
  }

  void addEvent(AdBlockEvent event) {
    final events = [event, ...state.events].take(state.capacity).toList();
    state = state.copyWith(
      events: events,
      totalBlocked: state.totalBlocked + 1,
      sessionBlocked: state.sessionBlocked + 1,
    );
  }

  void clear() {
    state = state.copyWith(events: [], totalBlocked: 0, sessionBlocked: 0);
  }
}
