import 'dart:convert';

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

Map<String, dynamic> _withInjection({
  AdBlockProps props = const AdBlockProps(),
  Mode logicalMode = Mode.rule,
  Map<String, dynamic> rawConfig = const {},
}) {
  return withAdBlockInjectionConfig(
    rawConfig: Map<String, dynamic>.from(rawConfig),
    props: props,
    remoteRulePath: 'providers/noad/anti-ad.mrs',
    logicalMode: logicalMode,
  );
}