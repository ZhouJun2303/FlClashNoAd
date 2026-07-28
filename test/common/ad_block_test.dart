import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/ad_block.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('injectAdBlockConfig', () {
    test('injects remote provider and preserves user rules in rule mode', () {
      final config = _withInjection(
        logicalMode: Mode.rule,
        props: const AdBlockProps(),
        rawConfig: {
          'mode': 'rule',
          'rules': ['DOMAIN,example.com,DIRECT', 'MATCH,PROXY'],
        },
      );

      injectAdBlockConfig(config);

      expect(config['mode'], 'rule');
      expect(
        config['rule-providers'][adBlockRemoteProviderName]['url'],
        adBlockRemoteRuleUrl,
      );
      expect(config['rules'], [
        'RULE-SET,$adBlockRemoteProviderName,REJECT',
        'DOMAIN,example.com,DIRECT',
        'MATCH,PROXY',
      ]);
    });

    test('maps logical global and direct modes to rule mode with final MATCH', () {
      final globalConfig = _withInjection(logicalMode: Mode.global);
      final directConfig = _withInjection(logicalMode: Mode.direct);

      injectAdBlockConfig(globalConfig);
      injectAdBlockConfig(directConfig);

      expect(globalConfig['mode'], 'rule');
      expect(globalConfig['rules'].last, 'MATCH,GLOBAL');
      expect(directConfig['mode'], 'rule');
      expect(directConfig['rules'].last, 'MATCH,DIRECT');
    });

    test('orders bypass and allow rules before NoAd blocking', () {
      final config = _withInjection(
        props: const AdBlockProps(
          allowDomains: ['allow.example.com'],
          blockDomains: ['block.example.com'],
          blockDomainSuffixes: ['suffix.example.com'],
          bypassPackages: ['com.example.app'],
        ),
      );

      injectAdBlockConfig(config);

      expect(config['rules'].take(4), [
        'PROCESS-NAME,com.example.app,PASS-RULE',
        'RULE-SET,$adBlockAllowProviderName,PASS-RULE',
        'RULE-SET,$adBlockLocalBlockProviderName,REJECT',
        'RULE-SET,$adBlockRemoteProviderName,REJECT',
      ]);
      expect(
        config['rule-providers'][adBlockAllowProviderName]['behavior'],
        'classical',
      );
      expect(
        config['rule-providers'][adBlockLocalBlockProviderName]['behavior'],
        'classical',
      );
      expect(
        config['rule-providers'][adBlockAllowProviderName]['payload'],
        ['DOMAIN,allow.example.com'],
      );
      expect(
        config['rule-providers'][adBlockLocalBlockProviderName]['payload'],
        ['DOMAIN,block.example.com', 'DOMAIN-SUFFIX,suffix.example.com'],
      );
    });

    test('is idempotent for reserved providers and rules', () {
      final config = _withInjection(
        props: const AdBlockProps(
          allowDomains: ['allow.example.com'],
          bypassPackages: ['com.example.app'],
        ),
      );

      injectAdBlockConfig(config);
      final first = jsonDecode(jsonEncode(config));
      config[adBlockInternalConfigKey] = {
        ...const AdBlockProps(
          allowDomains: ['allow.example.com'],
          bypassPackages: ['com.example.app'],
        ).toJson(),
        'remoteRulePath': 'providers/noad/anti-ad.mrs',
        'logicalMode': Mode.rule.name,
      };
      injectAdBlockConfig(config);

      expect(jsonDecode(jsonEncode(config)), first);
    });

    test('replaces managed bypass rules when settings change', () {
      final config = _withInjection(
        props: const AdBlockProps(bypassPackages: ['com.example.old']),
        rawConfig: {'rules': ['DOMAIN,example.com,DIRECT']},
      );

      injectAdBlockConfig(config);
      config[adBlockInternalConfigKey] = {
        ...const AdBlockProps(
          bypassPackages: ['com.example.new'],
        ).toJson(),
        'remoteRulePath': 'providers/noad/anti-ad.mrs',
        'logicalMode': Mode.rule.name,
      };
      injectAdBlockConfig(config);

      expect(config['rules'], [
        'PROCESS-NAME,com.example.new,PASS-RULE',
        _remoteRejectRule,
        'DOMAIN,example.com,DIRECT',
      ]);
    });

    test('remote provider includes offline fallback path and update interval', () {
      final config = _withInjection(
        remoteRulePath: 'providers/noad/anti-ad.mrs',
      );

      injectAdBlockConfig(config);

      final provider = config['rule-providers'][adBlockRemoteProviderName];
      expect(provider['type'], 'http');
      expect(provider['behavior'], 'domain');
      expect(provider['format'], 'mrs');
      expect(provider['url'], adBlockRemoteRuleUrl);
      expect(provider['path'], 'providers/noad/anti-ad.mrs');
      expect(provider['interval'], adBlockRuleUpdateIntervalSeconds);
    });

    test('bundles anti-AD MRS snapshot and MIT license notice', () {
      expect(File(adBlockFallbackRuleAssetPath).existsSync(), true);
      expect(File(adBlockFallbackRuleAssetPath).lengthSync(), greaterThan(0));
      expect(File(adBlockFallbackLicenseAssetPath).existsSync(), true);
      expect(
        File(adBlockFallbackLicenseAssetPath).readAsStringSync(),
        contains('MIT'),
      );
    });

    test('blocked event JSON excludes URL, query, header, body, and source IP', () {
      final json = AdBlockEvent(
        id: 'event',
        time: DateTime(2026),
        host: 'ads.example.com',
        destinationIp: '203.0.113.10',
        destinationPort: 443,
        network: 'tcp',
        packageName: 'com.example.app',
        uid: 10001,
        source: 'anti-ad',
        rule: 'RuleSet',
        ruleProvider: adBlockRemoteProviderName,
        ruleVersion: adBlockDefaultRuleVersion,
      ).toJson();

      expect(json.keys, isNot(contains('url')));
      expect(json.keys, isNot(contains('path')));
      expect(json.keys, isNot(contains('query')));
      expect(json.keys, isNot(contains('headers')));
      expect(json.keys, isNot(contains('body')));
      expect(json.keys, isNot(contains('sourceIp')));
      expect(json['host'], 'ads.example.com');
      expect(json['destinationIp'], '203.0.113.10');
    });
    test('disabled mode removes reserved NoAd config without injecting', () {
      final config = _withInjection(props: const AdBlockProps(enabled: false));
      config['rule-providers'] = {
        adBlockRemoteProviderName: {'type': 'http'},
        'user': {'type': 'inline'},
      };
      config['rules'] = [
        'RULE-SET,$adBlockRemoteProviderName,REJECT',
        'MATCH,DIRECT',
      ];

      injectAdBlockConfig(config);

      expect(config['rule-providers'], {
        'user': {'type': 'inline'},
      });
      expect(config['rules'], ['MATCH,DIRECT']);
    });

    test('detailed log switch overrides generated log level to debug', () {
      final config = _withInjection(
        props: const AdBlockProps(detailedLog: true),
        rawConfig: {'log-level': 'info'},
      );

      injectAdBlockConfig(config);

      expect(config['log-level'], 'debug');
    });
  });
}

const _remoteRejectRule = 'RULE-SET,$adBlockRemoteProviderName,REJECT';

Map<String, dynamic> _withInjection({
  AdBlockProps props = const AdBlockProps(),
  Mode logicalMode = Mode.rule,
  Map<String, dynamic> rawConfig = const {},
  String remoteRulePath = 'providers/noad/anti-ad.mrs',
}) {
  return withAdBlockInjectionConfig(
    rawConfig: Map<String, dynamic>.from(rawConfig),
    props: props,
    remoteRulePath: remoteRulePath,
    logicalMode: logicalMode,
  );
}
