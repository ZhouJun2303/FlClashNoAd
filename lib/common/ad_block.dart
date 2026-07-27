import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:path/path.dart';

const adBlockConfigKey = 'adBlockProps';
const adBlockInternalConfigKey = '__noad';
const adBlockRemoteProviderName = '__noad_anti_ad';
const adBlockAllowProviderName = '__noad_allow';
const adBlockLocalBlockProviderName = '__noad_local_block';
const adBlockRemoteRuleUrl = 'https://anti-ad.net/mihomo.mrs';
const adBlockFallbackRuleAssetPath = 'assets/data/noad/anti-ad.mrs';
const adBlockFallbackLicenseAssetPath = 'assets/data/noad/ANTI_AD_LICENSE.txt';
const adBlockDefaultRuleVersion = 'anti-ad:mihomo.mrs';
const adBlockRuleUpdateIntervalSeconds = 24 * 60 * 60;

const _reservedRuleProviders = {
  adBlockRemoteProviderName,
  adBlockAllowProviderName,
  adBlockLocalBlockProviderName,
};

String getAdBlockRemoteRulePath(String profilesPath) {
  return join(profilesPath, 'providers', 'noad', 'anti-ad.mrs');
}

Map<String, dynamic> withAdBlockInjectionConfig({
  required Map<String, dynamic> rawConfig,
  required AdBlockProps props,
  required String remoteRulePath,
  required Mode logicalMode,
}) {
  return Map<String, dynamic>.from(rawConfig)
    ..[adBlockInternalConfigKey] = {
      ...props.toJson(),
      'remoteRulePath': remoteRulePath,
      'logicalMode': logicalMode.name,
    };
}

void injectAdBlockConfig(Map<String, dynamic> rawConfig) {
  final injected = rawConfig.remove(adBlockInternalConfigKey);
  if (injected is! Map) {
    return;
  }

  final injectionMap = Map<String, Object?>.from(injected);
  final props = AdBlockProps.fromJson(injectionMap);
  final remoteRulePath = injectionMap['remoteRulePath'] as String? ?? '';
  final logicalMode = _modeFromName(injectionMap['logicalMode'] as String?);

  _removeReservedNoAdConfig(rawConfig);
  if (!props.enabled) {
    return;
  }

  if (props.detailedLog) {
    rawConfig['log-level'] = LogLevel.debug.name;
  }

  final ruleProviders = _ensureMap(rawConfig, 'rule-providers');
  ruleProviders[adBlockRemoteProviderName] = {
    'type': 'http',
    'behavior': 'domain',
    'format': 'mrs',
    'url': adBlockRemoteRuleUrl,
    if (remoteRulePath.isNotEmpty) 'path': remoteRulePath,
    'interval': adBlockRuleUpdateIntervalSeconds,
  };

  final allowPayload = _classicalDomainPayload('DOMAIN', props.allowDomains);
  if (allowPayload.isNotEmpty) {
    ruleProviders[adBlockAllowProviderName] = {
      'type': 'inline',
      'behavior': 'classical',
      'payload': allowPayload,
    };
  }

  final localBlockPayload = [
    ..._classicalDomainPayload('DOMAIN', props.blockDomains),
    ..._classicalDomainPayload('DOMAIN-SUFFIX', props.blockDomainSuffixes),
  ];
  if (localBlockPayload.isNotEmpty) {
    ruleProviders[adBlockLocalBlockProviderName] = {
      'type': 'inline',
      'behavior': 'classical',
      'payload': localBlockPayload,
    };
  }

  final userRules = _rules(
    rawConfig['rules'],
  ).where((rule) => !_isReservedNoAdRule(rule)).toList();
  final noAdRules = <String>[
    for (final package in _normalizedItems(props.bypassPackages))
      'PROCESS-NAME,$package,PASS-RULE',
    if (allowPayload.isNotEmpty) 'RULE-SET,$adBlockAllowProviderName,PASS-RULE',
    if (localBlockPayload.isNotEmpty)
      'RULE-SET,$adBlockLocalBlockProviderName,REJECT',
    'RULE-SET,$adBlockRemoteProviderName,REJECT',
  ];

  rawConfig['mode'] = Mode.rule.name;
  rawConfig['rules'] = switch (logicalMode) {
    Mode.global => [...noAdRules, 'MATCH,GLOBAL'],
    Mode.direct => [...noAdRules, 'MATCH,DIRECT'],
    Mode.rule => [...noAdRules, ...userRules],
  };
}

void _removeReservedNoAdConfig(Map<String, dynamic> rawConfig) {
  final ruleProviders = rawConfig['rule-providers'];
  if (ruleProviders is Map) {
    for (final name in _reservedRuleProviders) {
      ruleProviders.remove(name);
    }
    if (ruleProviders.isEmpty) {
      rawConfig.remove('rule-providers');
    }
  }
  rawConfig['rules'] = _rules(
    rawConfig['rules'],
  ).where((rule) => !_isReservedNoAdRule(rule)).toList();
}

Map _ensureMap(Map<String, dynamic> rawConfig, String key) {
  final current = rawConfig[key];
  if (current is Map) {
    return current;
  }
  final next = <String, dynamic>{};
  rawConfig[key] = next;
  return next;
}

List<String> _rules(Object? value) {
  return (value as List? ?? const []).map((item) => '$item').toList();
}

bool _isReservedNoAdRule(String rule) {
  return _reservedRuleProviders.any(rule.contains);
}

List<String> _classicalDomainPayload(String type, List<String> domains) {
  return _normalizedItems(domains).map((domain) => '$type,$domain').toList();
}

List<String> _normalizedItems(List<String> items) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final item in items) {
    final value = item.trim().toLowerCase();
    if (value.isEmpty || seen.contains(value)) {
      continue;
    }
    seen.add(value);
    normalized.add(value);
  }
  normalized.sort();
  return normalized;
}

Mode _modeFromName(String? name) {
  return Mode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => Mode.rule,
  );
}
