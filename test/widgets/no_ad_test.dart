import 'package:fl_clash/common/theme.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/no_ad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NoAd view renders overview, blocked, and rules tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => const Size(412, 915)),
        ],
        child: const _NoAdTestApp(child: NoAdView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NoAd'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('Ad blocking'), findsOneWidget);

    await tester.tap(find.text('Blocked'));
    await tester.pumpAndSettle();

    expect(find.text('Blocked events'), findsOneWidget);
    expect(find.text('No blocked events in memory'), findsOneWidget);

    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();

    expect(find.text('Manual rules'), findsOneWidget);
    expect(find.text('Allowed exact domains'), findsOneWidget);
  });

  testWidgets('NoAd blocked event list handles long hosts without overflow', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        viewSizeProvider.overrideWithBuild((_, _) => const Size(360, 800)),
      ],
    );
    addTearDown(container.dispose);
    container.read(adBlockSnapshotProvider.notifier).replace(
      AdBlockSnapshot(
        events: [
          AdBlockEvent(
            id: 'event-1',
            time: DateTime(2026),
            host:
                'very-long-ad-host-name-that-should-not-overflow.example.com',
            destinationIp: '203.0.113.10',
            destinationPort: 443,
            network: 'tcp',
            packageName: 'com.example.very.long.package.name',
            source: 'anti-ad',
            rule: 'RuleSet',
            ruleProvider: '__noad_anti_ad',
            ruleVersion: 'anti-ad:mihomo.mrs',
          ),
        ],
        totalBlocked: 1,
        sessionBlocked: 1,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _NoAdTestApp(child: NoAdView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blocked'));
    await tester.pumpAndSettle();

    expect(find.text('Blocked events'), findsOneWidget);
    expect(
      find.text('very-long-ad-host-name-that-should-not-overflow.example.com'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _NoAdTestApp extends StatelessWidget {
  const _NoAdTestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalState.navigatorKey,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      builder: (context, child) {
        globalState.theme = CommonTheme.of(context, 1);
        return child!;
      },
      home: child,
    );
  }
}