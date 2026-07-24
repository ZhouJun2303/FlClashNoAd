class AdBlockProps {
  const AdBlockProps({
    this.enabled = true,
    this.allowDomains = const [],
    this.blockDomains = const [],
    this.blockDomainSuffixes = const [],
    this.bypassPackages = const [],
    this.detailedLog = false,
    this.ruleVersion = '',
    this.lastUpdateAt,
  });

  factory AdBlockProps.fromJson(Map<String, Object?>? json) {
    if (json == null) {
      return const AdBlockProps();
    }
    return AdBlockProps(
      enabled: json['enabled'] as bool? ?? true,
      allowDomains: _stringList(json['allowDomains']),
      blockDomains: _stringList(json['blockDomains']),
      blockDomainSuffixes: _stringList(json['blockDomainSuffixes']),
      bypassPackages: _stringList(json['bypassPackages']),
      detailedLog: json['detailedLog'] as bool? ?? false,
      ruleVersion: json['ruleVersion'] as String? ?? '',
      lastUpdateAt: _dateTime(json['lastUpdateAt']),
    );
  }

  final bool enabled;
  final List<String> allowDomains;
  final List<String> blockDomains;
  final List<String> blockDomainSuffixes;
  final List<String> bypassPackages;
  final bool detailedLog;
  final String ruleVersion;
  final DateTime? lastUpdateAt;

  AdBlockProps copyWith({
    bool? enabled,
    List<String>? allowDomains,
    List<String>? blockDomains,
    List<String>? blockDomainSuffixes,
    List<String>? bypassPackages,
    bool? detailedLog,
    String? ruleVersion,
    DateTime? lastUpdateAt,
  }) {
    return AdBlockProps(
      enabled: enabled ?? this.enabled,
      allowDomains: allowDomains ?? this.allowDomains,
      blockDomains: blockDomains ?? this.blockDomains,
      blockDomainSuffixes: blockDomainSuffixes ?? this.blockDomainSuffixes,
      bypassPackages: bypassPackages ?? this.bypassPackages,
      detailedLog: detailedLog ?? this.detailedLog,
      ruleVersion: ruleVersion ?? this.ruleVersion,
      lastUpdateAt: lastUpdateAt ?? this.lastUpdateAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'allowDomains': allowDomains,
      'blockDomains': blockDomains,
      'blockDomainSuffixes': blockDomainSuffixes,
      'bypassPackages': bypassPackages,
      'detailedLog': detailedLog,
      'ruleVersion': ruleVersion,
      'lastUpdateAt': lastUpdateAt?.toIso8601String(),
    };
  }
}

class AdBlockDomainRule {
  const AdBlockDomainRule({
    required this.value,
    required this.suffix,
  });

  factory AdBlockDomainRule.fromJson(Map<String, Object?> json) {
    return AdBlockDomainRule(
      value: json['value'] as String? ?? '',
      suffix: json['suffix'] as bool? ?? false,
    );
  }

  final String value;
  final bool suffix;

  Map<String, Object?> toJson() {
    return {
      'value': value,
      'suffix': suffix,
    };
  }
}

class AdBlockEvent {
  const AdBlockEvent({
    required this.id,
    required this.time,
    required this.host,
    this.destinationIp,
    this.destinationPort,
    required this.network,
    this.packageName,
    this.uid,
    required this.source,
    required this.rule,
    required this.ruleProvider,
    this.ruleVersion,
  });

  factory AdBlockEvent.fromJson(Map<String, Object?> json) {
    return AdBlockEvent(
      id: json['id'] as String? ?? '',
      time: _dateTime(json['time']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      host: json['host'] as String? ?? '',
      destinationIp: json['destinationIp'] as String?,
      destinationPort: (json['destinationPort'] as num?)?.toInt(),
      network: json['network'] as String? ?? '',
      packageName: json['packageName'] as String?,
      uid: (json['uid'] as num?)?.toInt(),
      source: json['source'] as String? ?? '',
      rule: json['rule'] as String? ?? '',
      ruleProvider: json['ruleProvider'] as String? ?? '',
      ruleVersion: json['ruleVersion'] as String?,
    );
  }

  final String id;
  final DateTime time;
  final String host;
  final String? destinationIp;
  final int? destinationPort;
  final String network;
  final String? packageName;
  final int? uid;
  final String source;
  final String rule;
  final String ruleProvider;
  final String? ruleVersion;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'time': time.toIso8601String(),
      'host': host,
      'destinationIp': destinationIp,
      'destinationPort': destinationPort,
      'network': network,
      'packageName': packageName,
      'uid': uid,
      'source': source,
      'rule': rule,
      'ruleProvider': ruleProvider,
      'ruleVersion': ruleVersion,
    };
  }
}

class AdBlockSnapshot {
  const AdBlockSnapshot({
    this.events = const [],
    this.totalBlocked = 0,
    this.sessionBlocked = 0,
    this.capacity = 500,
    this.ruleVersion = '',
  });

  factory AdBlockSnapshot.fromJson(Map<String, Object?> json) {
    final events = json['events'] as List? ?? const [];
    return AdBlockSnapshot(
      events: events
          .whereType<Map>()
          .map((event) => AdBlockEvent.fromJson(Map<String, Object?>.from(event)))
          .toList(),
      totalBlocked: (json['totalBlocked'] as num?)?.toInt() ?? 0,
      sessionBlocked: (json['sessionBlocked'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 500,
      ruleVersion: json['ruleVersion'] as String? ?? '',
    );
  }

  final List<AdBlockEvent> events;
  final int totalBlocked;
  final int sessionBlocked;
  final int capacity;
  final String ruleVersion;

  AdBlockSnapshot copyWith({
    List<AdBlockEvent>? events,
    int? totalBlocked,
    int? sessionBlocked,
    int? capacity,
    String? ruleVersion,
  }) {
    return AdBlockSnapshot(
      events: events ?? this.events,
      totalBlocked: totalBlocked ?? this.totalBlocked,
      sessionBlocked: sessionBlocked ?? this.sessionBlocked,
      capacity: capacity ?? this.capacity,
      ruleVersion: ruleVersion ?? this.ruleVersion,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'events': events.map((event) => event.toJson()).toList(),
      'totalBlocked': totalBlocked,
      'sessionBlocked': sessionBlocked,
      'capacity': capacity,
      'ruleVersion': ruleVersion,
    };
  }
}

class AdBlockMatchResult {
  const AdBlockMatchResult({
    required this.matched,
    this.source,
    this.rule,
    this.normalizedHost,
  });

  factory AdBlockMatchResult.fromJson(Map<String, Object?> json) {
    return AdBlockMatchResult(
      matched: json['matched'] as bool? ?? false,
      source: json['source'] as String?,
      rule: json['rule'] as String?,
      normalizedHost: json['normalizedHost'] as String?,
    );
  }

  final bool matched;
  final String? source;
  final String? rule;
  final String? normalizedHost;

  Map<String, Object?> toJson() {
    return {
      'matched': matched,
      'source': source,
      'rule': rule,
      'normalizedHost': normalizedHost,
    };
  }
}

List<String> _stringList(Object? value) {
  return (value as List? ?? const [])
      .whereType<String>()
      .where((item) => item.trim().isNotEmpty)
      .toList();
}

DateTime? _dateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
