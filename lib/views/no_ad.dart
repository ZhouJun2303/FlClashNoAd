import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoAdView extends StatelessWidget {
  const NoAdView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return DefaultTabController(
      length: 3,
      child: CommonScaffold(
        appBar: AppBar(
          title: const Text('NoAd'),
          bottom: TabBar(
            tabs: [
              Tab(text: appLocalizations.noAdOverview),
              Tab(text: appLocalizations.noAdBlocked),
              Tab(text: appLocalizations.noAdRules),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_NoAdOverviewTab(), _NoAdEventsTab(), _NoAdRulesTab()],
        ),
      ),
    );
  }
}

class _NoAdOverviewTab extends ConsumerWidget {
  const _NoAdOverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final props = ref.watch(adBlockSettingProvider);
    final snapshot = ref.watch(adBlockSnapshotProvider);
    final eventsCount = snapshot.events.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListItem.switchItem(
          leading: const Icon(Icons.block),
          title: Text(appLocalizations.noAdAdBlocking),
          subtitle: Text(appLocalizations.noAdAdBlockingDesc),
          delegate: SwitchDelegate(
            value: props.enabled,
            onChanged: (value) {
              ref
                  .read(adBlockSettingProvider.notifier)
                  .update((state) => state.copyWith(enabled: value));
              ref
                  .read(setupActionProvider.notifier)
                  .applyProfileDebounce(silence: true, force: true);
            },
          ),
        ),
        const Divider(height: 0),
        ListItem.switchItem(
          leading: const Icon(Icons.bug_report_outlined),
          title: Text(appLocalizations.noAdDetailedMihomoLogs),
          subtitle: Text(appLocalizations.noAdDetailedMihomoLogsDesc),
          delegate: SwitchDelegate(
            value: props.detailedLog,
            onChanged: (value) {
              ref
                  .read(adBlockSettingProvider.notifier)
                  .update((state) => state.copyWith(detailedLog: value));
              ref
                  .read(setupActionProvider.notifier)
                  .applyProfileDebounce(silence: true, force: true);
            },
          ),
        ),
        ...generateSection(
          title: appLocalizations.status,
          items: [
            _MetricItem(
              icon: Icons.shield_outlined,
              title: appLocalizations.noAdSessionBlocked,
              value: '${snapshot.sessionBlocked}',
            ),
            _MetricItem(
              icon: Icons.all_inclusive,
              title: appLocalizations.noAdTotalBlocked,
              value: '${snapshot.totalBlocked}',
            ),
            _MetricItem(
              icon: Icons.storage_outlined,
              title: appLocalizations.noAdInMemoryEvents,
              value: '$eventsCount / ${snapshot.capacity}',
            ),
            _MetricItem(
              icon: Icons.rule_folder_outlined,
              title: appLocalizations.noAdRuleVersion,
              value: snapshot.ruleVersion.isEmpty
                  ? adBlockDefaultRuleVersion
                  : snapshot.ruleVersion,
            ),
            _MetricItem(
              icon: Icons.update,
              title: appLocalizations.noAdLastRuleUpdate,
              value: props.lastUpdateAt == null
                  ? appLocalizations.unknown
                  : props.lastUpdateAt!.getLastUpdateTimeDesc(context),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(appLocalizations.noAdPrivacyNotice),
        ),
      ],
    );
  }
}

enum _NoAdEventFilter { all, domain, app }

extension _NoAdEventFilterExt on _NoAdEventFilter {
  String label(AppLocalizations appLocalizations) {
    return switch (this) {
      _NoAdEventFilter.all => appLocalizations.noAdFilterAll,
      _NoAdEventFilter.domain => appLocalizations.noAdFilterDomain,
      _NoAdEventFilter.app => appLocalizations.noAdFilterApp,
    };
  }
}

class _NoAdEventsTab extends ConsumerStatefulWidget {
  const _NoAdEventsTab();

  @override
  ConsumerState<_NoAdEventsTab> createState() => _NoAdEventsTabState();
}

class _NoAdEventsTabState extends ConsumerState<_NoAdEventsTab> {
  String _query = '';
  _NoAdEventFilter _filter = _NoAdEventFilter.all;

  List<AdBlockEvent> _filterEvents(List<AdBlockEvent> events) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return events;
    }
    return events.where((event) {
      final host = event.host.toLowerCase();
      final packageName = event.packageName?.toLowerCase() ?? '';
      final ruleProvider = event.ruleProvider.toLowerCase();
      final source = event.source.toLowerCase();
      final network = event.network.toLowerCase();
      return switch (_filter) {
        _NoAdEventFilter.domain => host.contains(query),
        _NoAdEventFilter.app => packageName.contains(query),
        _NoAdEventFilter.all =>
          host.contains(query) ||
              packageName.contains(query) ||
              ruleProvider.contains(query) ||
              source.contains(query) ||
              network.contains(query),
      };
    }).toList();
  }

  List<Widget> _buildActions(
    WidgetRef ref,
    bool hasEvents,
    AppLocalizations appLocalizations,
  ) {
    return [
      IconButton(
        tooltip: appLocalizations.refresh,
        onPressed: () async {
          ref
              .read(adBlockSnapshotProvider.notifier)
              .replace(await coreController.getAdBlockSnapshot());
        },
        icon: const Icon(Icons.refresh),
      ),
      IconButton(
        tooltip: appLocalizations.noAdExportDiagnostics,
        onPressed: !hasEvents ? null : () => _exportDiagnostics(ref),
        icon: const Icon(Icons.ios_share_outlined),
      ),
      IconButton(
        tooltip: appLocalizations.noAdExportRawJsonl,
        onPressed: !hasEvents ? null : () => _exportRawJsonl(ref),
        icon: const Icon(Icons.data_object_outlined),
      ),
      if (hasEvents)
        IconButton(
          tooltip: appLocalizations.delete,
          onPressed: () async {
            await coreController.clearAdBlockEvents();
            ref.read(adBlockSnapshotProvider.notifier).clear();
          },
          icon: const Icon(Icons.delete_outline),
        ),
    ];
  }

  Future<void> _exportDiagnostics(WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final snapshot = ref.read(adBlockSnapshotProvider);
    final diagnostics = {
      'type': 'noad-diagnostics',
      'generatedAt': DateTime.now().toIso8601String(),
      'ruleVersion': snapshot.ruleVersion,
      'totalBlocked': snapshot.totalBlocked,
      'sessionBlocked': snapshot.sessionBlocked,
      'capacity': snapshot.capacity,
      'eventCount': snapshot.events.length,
      'events': snapshot.events.map(_redactedEventJson).toList(),
    };
    await _saveExport(
      title: appLocalizations.noAdExportDiagnostics,
      fileName: 'noad-diagnostics.json',
      content: const JsonEncoder.withIndent('  ').convert(diagnostics),
    );
  }

  Future<void> _exportRawJsonl(WidgetRef ref) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await globalState.showMessage(
      title: appLocalizations.noAdExportRawBlockedEvents,
      message: TextSpan(text: appLocalizations.noAdRawExportWarning),
    );
    if (confirmed != true) {
      return;
    }
    final snapshot = ref.read(adBlockSnapshotProvider);
    final content = snapshot.events
        .map((event) => jsonEncode(event.toJson()))
        .join('\n');
    await _saveExport(
      title: appLocalizations.noAdExportRawJsonl,
      fileName: 'noad-blocked-events.jsonl',
      content: content,
    );
  }

  Map<String, Object?> _redactedEventJson(AdBlockEvent event) {
    return {
      'idHash': event.id.toMd5(),
      'time': event.time.toIso8601String(),
      'hostHash': event.host.toMd5(),
      'destinationIpPresent': event.destinationIp?.isNotEmpty == true,
      'destinationPort': event.destinationPort,
      'network': event.network,
      'packageHash': event.packageName?.toMd5(),
      'uidPresent': event.uid != null,
      'source': event.source,
      'rule': event.rule,
      'ruleProvider': event.ruleProvider,
      'ruleVersion': event.ruleVersion,
    };
  }

  Future<void> _saveExport({
    required String title,
    required String fileName,
    required String content,
  }) async {
    final appLocalizations = context.appLocalizations;
    final exported = await globalState.safeRun<bool>(() async {
      final tempFilePath = await appPath.tempFilePath;
      final file = File(tempFilePath);
      await file.safeWriteAsString(content);
      return await picker.saveFileWithPath(fileName, tempFilePath) != null;
    }, title: title);
    if (exported == true) {
      globalState.showMessage(
        title: 'NoAd',
        message: TextSpan(text: appLocalizations.noAdExportSaved),
      );
    }
  }

  Widget _buildSearchAndFilter(AppLocalizations appLocalizations) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: appLocalizations.noAdSearchBlockedEvents,
              helperText: appLocalizations.noAdSearchBlockedEventsDesc,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in _NoAdEventFilter.values)
                ChoiceChip(
                  label: Text(filter.label(appLocalizations)),
                  selected: filter == _filter,
                  onSelected: (_) {
                    setState(() {
                      _filter = filter;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final snapshot = ref.watch(adBlockSnapshotProvider);
    final hasEvents = snapshot.events.isNotEmpty;
    final events = _filterEvents(snapshot.events);
    if (!hasEvents) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListHeader(
            title: appLocalizations.noAdBlockedEvents,
            actions: _buildActions(ref, false, appLocalizations),
          ),
          _buildSearchAndFilter(appLocalizations),
          ListItem(
            leading: const Icon(Icons.inbox_outlined),
            title: Text(appLocalizations.noAdNoBlockedEvents),
            subtitle: Text(appLocalizations.noAdNoBlockedEventsDesc),
          ),
        ],
      );
    }
    if (events.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListHeader(
            title: appLocalizations.noAdBlockedEvents,
            actions: _buildActions(ref, true, appLocalizations),
          ),
          _buildSearchAndFilter(appLocalizations),
          ListItem(
            leading: const Icon(Icons.filter_alt_off_outlined),
            title: Text(appLocalizations.noAdNoFilteredEvents),
            subtitle: Text(appLocalizations.noAdNoFilteredEventsDesc),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: events.length + 2,
      separatorBuilder: (_, index) =>
          index < 2 ? const SizedBox.shrink() : const Divider(height: 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListHeader(
            title: appLocalizations.noAdBlockedEvents,
            actions: _buildActions(ref, true, appLocalizations),
          );
        }
        if (index == 1) {
          return _buildSearchAndFilter(appLocalizations);
        }
        final event = events[index - 2];
        return _AdBlockEventItem(event: event);
      },
    );
  }
}

class _NoAdRulesTab extends ConsumerStatefulWidget {
  const _NoAdRulesTab();

  @override
  ConsumerState<_NoAdRulesTab> createState() => _NoAdRulesTabState();
}

class _NoAdRulesTabState extends ConsumerState<_NoAdRulesTab> {
  AdBlockMatchResult? _lastMatch;

  Future<void> _addDomain({required bool allow}) async {
    final appLocalizations = context.appLocalizations;
    final value = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: allow
            ? appLocalizations.noAdAllowExactDomain
            : appLocalizations.noAdBlockExactDomain,
        value: '',
        validator: (value) {
          return value?.trim().isEmpty == true
              ? appLocalizations.noAdDomainRequired
              : null;
        },
      ),
    );
    if (value == null) {
      return;
    }
    final normalized = await coreController.normalizeAdBlockDomain(value);
    if (normalized.isEmpty) {
      globalState.showNotifier(appLocalizations.noAdInvalidDomain);
      return;
    }
    ref.read(adBlockSettingProvider.notifier).update((state) {
      final allowDomains = _updatedList(state.allowDomains, normalized, allow);
      final blockDomains = _updatedList(state.blockDomains, normalized, !allow);
      return state.copyWith(
        allowDomains: allowDomains,
        blockDomains: blockDomains,
      );
    });
    ref
        .read(setupActionProvider.notifier)
        .applyProfileDebounce(silence: true, force: true);
  }

  Future<void> _addSuffixDomain() async {
    final appLocalizations = context.appLocalizations;
    final value = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.noAdBlockDomainSuffix,
        value: '',
      ),
    );
    if (value == null) {
      return;
    }
    final normalized = await coreController.normalizeAdBlockDomain(value);
    if (normalized.isEmpty) {
      globalState.showNotifier(appLocalizations.noAdInvalidDomainSuffix);
      return;
    }
    final confirmed = await globalState.showMessage(
      title: appLocalizations.noAdConfirmSuffixBlocking,
      message: TextSpan(
        text:
            '${appLocalizations.noAdConfirmSuffixBlockingDesc}\n+.$normalized',
      ),
    );
    if (confirmed != true) {
      return;
    }
    ref
        .read(adBlockSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            blockDomainSuffixes: _updatedList(
              state.blockDomainSuffixes,
              normalized,
              true,
            ),
          ),
        );
    ref
        .read(setupActionProvider.notifier)
        .applyProfileDebounce(silence: true, force: true);
  }

  Future<void> _addBypassPackage() async {
    final appLocalizations = context.appLocalizations;
    final value = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.noAdBypassAppPackage,
        value: '',
      ),
    );
    final packageName = value?.trim();
    if (packageName == null || packageName.isEmpty) {
      return;
    }
    ref
        .read(adBlockSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            bypassPackages: _updatedList(
              state.bypassPackages,
              packageName,
              true,
            ),
          ),
        );
    ref
        .read(setupActionProvider.notifier)
        .applyProfileDebounce(silence: true, force: true);
  }

  Future<void> _testDomain() async {
    final appLocalizations = context.appLocalizations;
    final value = await globalState.showCommonDialog<String>(
      child: InputDialog(title: appLocalizations.noAdTestDomain, value: ''),
    );
    if (value == null) {
      return;
    }
    final result = await coreController.matchAdBlockDomain(value);
    setState(() {
      _lastMatch = result;
    });
  }

  Future<void> _updateRemoteRules() async {
    final appLocalizations = context.appLocalizations;
    final message = await coreController.updateExternalProvider(
      providerName: adBlockRemoteProviderName,
    );
    if (message.isNotEmpty) {
      final fallbackMessage = await coreController
          .sideLoadAdBlockFallbackRuleProvider();
      if (fallbackMessage.isEmpty) {
        _recordRuleUpdate();
        globalState.showNotifier(appLocalizations.noAdFallbackRulesLoaded);
        return;
      }
      globalState.showNotifier(
        '${appLocalizations.noAdRulesUpdateFailed}: $message',
      );
      return;
    }
    _recordRuleUpdate();
    globalState.showNotifier(appLocalizations.noAdRulesUpdated);
  }

  void _recordRuleUpdate() {
    ref
        .read(adBlockSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            ruleVersion: adBlockDefaultRuleVersion,
            lastUpdateAt: DateTime.now(),
          ),
        );
  }

  List<String> _updatedList(List<String> values, String value, bool add) {
    final next = values.toSet();
    if (add) {
      next.add(value);
    } else {
      next.remove(value);
    }
    return next.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final props = ref.watch(adBlockSettingProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListHeader(
          title: appLocalizations.noAdRuleActions,
          actions: [
            IconButton(
              tooltip: appLocalizations.noAdTest,
              onPressed: _testDomain,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: appLocalizations.noAdUpdateRemoteRules,
              onPressed: _updateRemoteRules,
              icon: const Icon(Icons.cloud_sync_outlined),
            ),
          ],
        ),
        if (_lastMatch != null)
          ListItem(
            leading: Icon(
              _lastMatch!.matched ? Icons.check_circle : Icons.cancel_outlined,
            ),
            title: Text(
              _lastMatch!.matched
                  ? appLocalizations.noAdMatchedNoAdRule
                  : appLocalizations.noAdNoNoAdMatch,
            ),
            subtitle: Text(
              [
                if (_lastMatch!.normalizedHost?.isNotEmpty == true)
                  _lastMatch!.normalizedHost!,
                if (_lastMatch!.source?.isNotEmpty == true)
                  '${appLocalizations.source}: ${_lastMatch!.source}',
                if (_lastMatch!.rule?.isNotEmpty == true)
                  '${appLocalizations.rule}: ${_lastMatch!.rule}',
              ].join(' · '),
            ),
          ),
        ...generateSection(
          title: appLocalizations.noAdManualRules,
          actions: [
            IconButton(
              tooltip: appLocalizations.noAdAllowDomain,
              onPressed: () => _addDomain(allow: true),
              icon: const Icon(Icons.verified_user_outlined),
            ),
            IconButton(
              tooltip: appLocalizations.noAdBlockDomain,
              onPressed: () => _addDomain(allow: false),
              icon: const Icon(Icons.block),
            ),
            IconButton(
              tooltip: appLocalizations.noAdBlockSuffix,
              onPressed: _addSuffixDomain,
              icon: const Icon(Icons.account_tree_outlined),
            ),
            IconButton(
              tooltip: appLocalizations.noAdBypassApp,
              onPressed: _addBypassPackage,
              icon: const Icon(Icons.apps_outlined),
            ),
          ],
          items: [
            _DomainListItem(
              title: appLocalizations.noAdAllowedExactDomains,
              values: props.allowDomains,
              emptyText: appLocalizations.noAdNoAllowlistDomains,
              onRemove: (value) {
                ref
                    .read(adBlockSettingProvider.notifier)
                    .update(
                      (state) => state.copyWith(
                        allowDomains: _updatedList(
                          state.allowDomains,
                          value,
                          false,
                        ),
                      ),
                    );
                ref
                    .read(setupActionProvider.notifier)
                    .applyProfileDebounce(silence: true, force: true);
              },
            ),
            _DomainListItem(
              title: appLocalizations.noAdBlockedExactDomains,
              values: props.blockDomains,
              emptyText: appLocalizations.noAdNoManualBlockDomains,
              onRemove: (value) {
                ref
                    .read(adBlockSettingProvider.notifier)
                    .update(
                      (state) => state.copyWith(
                        blockDomains: _updatedList(
                          state.blockDomains,
                          value,
                          false,
                        ),
                      ),
                    );
                ref
                    .read(setupActionProvider.notifier)
                    .applyProfileDebounce(silence: true, force: true);
              },
            ),
            _DomainListItem(
              title: appLocalizations.noAdBlockedDomainSuffixes,
              values: props.blockDomainSuffixes,
              emptyText: appLocalizations.noAdNoSuffixBlockDomains,
              valuePrefix: '+.',
              onRemove: (value) {
                ref
                    .read(adBlockSettingProvider.notifier)
                    .update(
                      (state) => state.copyWith(
                        blockDomainSuffixes: _updatedList(
                          state.blockDomainSuffixes,
                          value,
                          false,
                        ),
                      ),
                    );
                ref
                    .read(setupActionProvider.notifier)
                    .applyProfileDebounce(silence: true, force: true);
              },
            ),
            _DomainListItem(
              title: appLocalizations.noAdBypassedAppPackages,
              values: props.bypassPackages,
              emptyText: appLocalizations.noAdNoBypassedApps,
              onRemove: (value) {
                ref
                    .read(adBlockSettingProvider.notifier)
                    .update(
                      (state) => state.copyWith(
                        bypassPackages: _updatedList(
                          state.bypassPackages,
                          value,
                          false,
                        ),
                      ),
                    );
                ref
                    .read(setupActionProvider.notifier)
                    .applyProfileDebounce(silence: true, force: true);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(value),
    );
  }
}

class _AdBlockEventItem extends StatelessWidget {
  const _AdBlockEventItem({required this.event});

  final AdBlockEvent event;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final destination = [
      if (event.destinationIp?.isNotEmpty == true) event.destinationIp,
      if (event.destinationPort != null) '${event.destinationPort}',
    ].whereType<String>().join(':');
    final details = [
      event.network.toUpperCase(),
      if (destination.isNotEmpty) destination,
      if (event.packageName?.isNotEmpty == true) event.packageName!,
      event.ruleProvider,
    ].where((item) => item.isNotEmpty).join(' · ');
    return ListItem(
      leading: const Icon(Icons.block),
      title: Text(
        event.host.isEmpty ? appLocalizations.noAdUnknownHost : event.host,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(details, overflow: TextOverflow.ellipsis),
      trailing: Text(_timeLabel(event.time)),
    );
  }

  String _timeLabel(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _DomainListItem extends StatelessWidget {
  const _DomainListItem({
    required this.title,
    required this.values,
    required this.emptyText,
    required this.onRemove,
    this.valuePrefix = '',
  });

  final String title;
  final List<String> values;
  final String emptyText;
  final ValueChanged<String> onRemove;
  final String valuePrefix;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final subtitle = values.isEmpty
        ? emptyText
        : values.map((value) => '$valuePrefix$value').join('\n');
    return ListItem(
      title: Text(title),
      subtitle: Text(subtitle, overflow: TextOverflow.ellipsis, maxLines: 4),
      trailing: values.isEmpty
          ? null
          : PopupMenuButton<String>(
              onSelected: onRemove,
              itemBuilder: (_) {
                return [
                  for (final value in values)
                    PopupMenuItem(
                      value: value,
                      child: Text(
                        '${appLocalizations.remove} $valuePrefix$value',
                      ),
                    ),
                ];
              },
              icon: const Icon(Icons.more_vert),
            ),
    );
  }
}
