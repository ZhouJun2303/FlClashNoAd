import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
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
    return DefaultTabController(
      length: 3,
      child: CommonScaffold(
        appBar: AppBar(
          title: const Text('NoAd'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Blocked'),
              Tab(text: 'Rules'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _NoAdOverviewTab(),
            _NoAdEventsTab(),
            _NoAdRulesTab(),
          ],
        ),
      ),
    );
  }
}

class _NoAdOverviewTab extends ConsumerWidget {
  const _NoAdOverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final props = ref.watch(adBlockSettingProvider);
    final snapshot = ref.watch(adBlockSnapshotProvider);
    final eventsCount = snapshot.events.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListItem.switchItem(
          leading: const Icon(Icons.block),
          title: const Text('Ad blocking'),
          subtitle: const Text(
            'Blocks known ad and tracking domains through the VPN/TUN rule layer.',
          ),
          delegate: SwitchDelegate(
            value: props.enabled,
            onChanged: (value) {
              ref
                  .read(adBlockSettingProvider.notifier)
                  .update((state) => state.copyWith(enabled: value));
              ref.read(setupActionProvider.notifier).applyProfileDebounce(
                    silence: true,
                    force: true,
                  );
            },
          ),
        ),
        const Divider(height: 0),
        ListItem.switchItem(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Detailed Mihomo logs'),
          subtitle: const Text(
            'Temporarily switches generated config to debug logging. Logs stay in memory.',
          ),
          delegate: SwitchDelegate(
            value: props.detailedLog,
            onChanged: (value) {
              ref
                  .read(adBlockSettingProvider.notifier)
                  .update((state) => state.copyWith(detailedLog: value));
              ref.read(setupActionProvider.notifier).applyProfileDebounce(
                    silence: true,
                    force: true,
                  );
            },
          ),
        ),
        ...generateSection(
          title: 'Status',
          items: [
            _MetricItem(
              icon: Icons.shield_outlined,
              title: 'Session blocked',
              value: '${snapshot.sessionBlocked}',
            ),
            _MetricItem(
              icon: Icons.all_inclusive,
              title: 'Total blocked',
              value: '${snapshot.totalBlocked}',
            ),
            _MetricItem(
              icon: Icons.storage_outlined,
              title: 'In-memory events',
              value: '$eventsCount / ${snapshot.capacity}',
            ),
            _MetricItem(
              icon: Icons.rule_folder_outlined,
              title: 'Rule version',
              value: snapshot.ruleVersion.isEmpty
                  ? adBlockDefaultRuleVersion
                  : snapshot.ruleVersion,
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'NoAd does not install a CA certificate and does not decrypt HTTPS. HTTPS entries only show domain/IP/port/app/rule metadata.',
          ),
        ),
      ],
    );
  }
}

class _NoAdEventsTab extends ConsumerWidget {
  const _NoAdEventsTab();

  List<Widget> _buildActions(WidgetRef ref, bool hasEvents) {
    return [
      IconButton(
        tooltip: 'Refresh',
        onPressed: () async {
          ref
              .read(adBlockSnapshotProvider.notifier)
              .replace(await coreController.getAdBlockSnapshot());
        },
        icon: const Icon(Icons.refresh),
      ),
      IconButton(
        tooltip: 'Export diagnostics',
        onPressed: !hasEvents ? null : () => _exportDiagnostics(ref),
        icon: const Icon(Icons.ios_share_outlined),
      ),
      IconButton(
        tooltip: 'Export raw JSONL',
        onPressed: !hasEvents ? null : () => _exportRawJsonl(ref),
        icon: const Icon(Icons.data_object_outlined),
      ),
      if (hasEvents)
        IconButton(
          tooltip: 'Clear',
          onPressed: () async {
            await coreController.clearAdBlockEvents();
            ref.read(adBlockSnapshotProvider.notifier).clear();
          },
          icon: const Icon(Icons.delete_outline),
        ),
    ];
  }

  Future<void> _exportDiagnostics(WidgetRef ref) async {
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
      title: 'Export NoAd diagnostics',
      fileName: 'noad-diagnostics.json',
      content: const JsonEncoder.withIndent('  ').convert(diagnostics),
    );
  }

  Future<void> _exportRawJsonl(WidgetRef ref) async {
    final confirmed = await globalState.showMessage(
      title: 'Export raw blocked events',
      message: const TextSpan(
        text: 'Raw JSONL includes blocked domains, destination IP/port, package names, UIDs, and rule metadata. It does not include URLs, headers, or traffic content. Export only if you intend to share these values.',
      ),
    );
    if (confirmed != true) {
      return;
    }
    final snapshot = ref.read(adBlockSnapshotProvider);
    final content = snapshot.events
        .map((event) => jsonEncode(event.toJson()))
        .join('\n');
    await _saveExport(
      title: 'Export raw NoAd JSONL',
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
    final exported = await globalState.safeRun<bool>(() async {
      final tempFilePath = await appPath.tempFilePath;
      final file = File(tempFilePath);
      await file.safeWriteAsString(content);
      return await picker.saveFileWithPath(fileName, tempFilePath) != null;
    }, title: title);
    if (exported == true) {
      globalState.showMessage(
        title: 'NoAd',
        message: const TextSpan(text: 'Export saved'),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(adBlockSnapshotProvider);
    final hasEvents = snapshot.events.isNotEmpty;
    if (!hasEvents) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListHeader(
            title: 'Blocked events',
            actions: _buildActions(ref, false),
          ),
          const ListItem(
            leading: Icon(Icons.inbox_outlined),
            title: Text('No blocked events in memory'),
            subtitle: Text(
              'Events are kept only while the VPN/core session is active.',
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: snapshot.events.length + 1,
      separatorBuilder: (_, index) => index == 0
          ? const SizedBox.shrink()
          : const Divider(height: 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ListHeader(
            title: 'Blocked events',
            actions: _buildActions(ref, true),
          );
        }
        final event = snapshot.events[index - 1];
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
    final value = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: allow ? 'Allow exact domain' : 'Block exact domain',
        value: '',
        validator: (value) {
          return value?.trim().isEmpty == true ? 'Domain is required' : null;
        },
      ),
    );
    if (value == null) {
      return;
    }
    final normalized = await coreController.normalizeAdBlockDomain(value);
    if (normalized.isEmpty) {
      globalState.showNotifier('Invalid domain');
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
    ref.read(setupActionProvider.notifier).applyProfileDebounce(
          silence: true,
          force: true,
        );
  }

  Future<void> _addSuffixDomain() async {
    final value = await globalState.showCommonDialog<String>(
      child: const InputDialog(title: 'Block domain suffix', value: ''),
    );
    if (value == null) {
      return;
    }
    final normalized = await coreController.normalizeAdBlockDomain(value);
    if (normalized.isEmpty) {
      globalState.showNotifier('Invalid domain suffix');
      return;
    }
    final confirmed = await globalState.showMessage(
      title: 'Confirm suffix blocking',
      message: TextSpan(
        text: 'Block this domain and all subdomains?\n+.$normalized',
      ),
    );
    if (confirmed != true) {
      return;
    }
    ref.read(adBlockSettingProvider.notifier).update(
          (state) => state.copyWith(
            blockDomainSuffixes: _updatedList(
              state.blockDomainSuffixes,
              normalized,
              true,
            ),
          ),
        );
    ref.read(setupActionProvider.notifier).applyProfileDebounce(
          silence: true,
          force: true,
        );
  }

  Future<void> _addBypassPackage() async {
    final value = await globalState.showCommonDialog<String>(
      child: const InputDialog(title: 'Bypass app package', value: ''),
    );
    final packageName = value?.trim();
    if (packageName == null || packageName.isEmpty) {
      return;
    }
    ref.read(adBlockSettingProvider.notifier).update(
          (state) => state.copyWith(
            bypassPackages: _updatedList(
              state.bypassPackages,
              packageName,
              true,
            ),
          ),
        );
    ref.read(setupActionProvider.notifier).applyProfileDebounce(
          silence: true,
          force: true,
        );
  }

  Future<void> _testDomain() async {
    final value = await globalState.showCommonDialog<String>(
      child: const InputDialog(title: 'Test domain', value: ''),
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
    final message = await coreController.updateExternalProvider(
      providerName: adBlockRemoteProviderName,
    );
    if (message.isNotEmpty) {
      globalState.showNotifier(message);
      return;
    }
    globalState.showNotifier('NoAd rules updated');
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
    final props = ref.watch(adBlockSettingProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ListHeader(
          title: 'Rule actions',
          actions: [
            IconButton(
              tooltip: 'Test',
              onPressed: _testDomain,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: 'Update remote rules',
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
              _lastMatch!.matched ? 'Matched NoAd rule' : 'No NoAd match',
            ),
            subtitle: Text(
              [
                if (_lastMatch!.normalizedHost?.isNotEmpty == true)
                  _lastMatch!.normalizedHost!,
                if (_lastMatch!.source?.isNotEmpty == true)
                  'source: ${_lastMatch!.source}',
                if (_lastMatch!.rule?.isNotEmpty == true)
                  'rule: ${_lastMatch!.rule}',
              ].join(' · '),
            ),
          ),
        ...generateSection(
          title: 'Manual rules',
          actions: [
            IconButton(
              tooltip: 'Allow domain',
              onPressed: () => _addDomain(allow: true),
              icon: const Icon(Icons.verified_user_outlined),
            ),
            IconButton(
              tooltip: 'Block domain',
              onPressed: () => _addDomain(allow: false),
              icon: const Icon(Icons.block),
            ),
            IconButton(
              tooltip: 'Block suffix',
              onPressed: _addSuffixDomain,
              icon: const Icon(Icons.account_tree_outlined),
            ),
            IconButton(
              tooltip: 'Bypass app',
              onPressed: _addBypassPackage,
              icon: const Icon(Icons.apps_outlined),
            ),
          ],
          items: [
            _DomainListItem(
              title: 'Allowed exact domains',
              values: props.allowDomains,
              emptyText: 'No allowlist domains',
              onRemove: (value) {
                ref.read(adBlockSettingProvider.notifier).update(
                      (state) => state.copyWith(
                        allowDomains: _updatedList(
                          state.allowDomains,
                          value,
                          false,
                        ),
                      ),
                    );
                ref.read(setupActionProvider.notifier).applyProfileDebounce(
                      silence: true,
                      force: true,
                    );
              },
            ),
            _DomainListItem(
              title: 'Blocked exact domains',
              values: props.blockDomains,
              emptyText: 'No manual block domains',
              onRemove: (value) {
                ref.read(adBlockSettingProvider.notifier).update(
                      (state) => state.copyWith(
                        blockDomains: _updatedList(
                          state.blockDomains,
                          value,
                          false,
                        ),
                      ),
                    );
                ref.read(setupActionProvider.notifier).applyProfileDebounce(
                      silence: true,
                      force: true,
                    );
              },
            ),
            _DomainListItem(
              title: 'Blocked domain suffixes',
              values: props.blockDomainSuffixes,
              emptyText: 'No suffix block domains',
              valuePrefix: '+.',
              onRemove: (value) {
                ref.read(adBlockSettingProvider.notifier).update(
                      (state) => state.copyWith(
                        blockDomainSuffixes: _updatedList(
                          state.blockDomainSuffixes,
                          value,
                          false,
                        ),
                      ),
                    );
                ref.read(setupActionProvider.notifier).applyProfileDebounce(
                      silence: true,
                      force: true,
                    );
              },
            ),
            _DomainListItem(
              title: 'Bypassed app packages',
              values: props.bypassPackages,
              emptyText: 'No bypassed apps',
              onRemove: (value) {
                ref.read(adBlockSettingProvider.notifier).update(
                      (state) => state.copyWith(
                        bypassPackages: _updatedList(
                          state.bypassPackages,
                          value,
                          false,
                        ),
                      ),
                    );
                ref.read(setupActionProvider.notifier).applyProfileDebounce(
                      silence: true,
                      force: true,
                    );
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
        event.host.isEmpty ? '<unknown host>' : event.host,
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
                      child: Text('Remove $valuePrefix$value'),
                    ),
                ];
              },
              icon: const Icon(Icons.more_vert),
            ),
    );
  }
}