# NoAd Privacy And Security Boundaries

NoAd blocks known advertising and tracking domains through the FLClash VPN/TUN rule layer. It does not install a user CA certificate, does not perform HTTPS man-in-the-middle decryption, and does not proxy traffic through a NoAd-operated cloud service.

## What NoAd can record

Blocked-event records are intentionally limited to operational metadata needed to explain a NoAd rule hit:

- event ID and timestamp;
- target host/domain;
- target IP and port when the core exposes them;
- TCP/UDP network type;
- Android package name and UID when available;
- block source, rule provider, and rule version.

## What NoAd must not record

NoAd blocked-event records must not include:

- full URLs;
- URL paths or query strings;
- request or response headers;
- request or response bodies;
- subscription URLs, tokens, or proxy credentials;
- source device IP/port.

HTTPS entries therefore show the destination host, IP, port, app, and rule hit only. They do not show page paths, query parameters, headers, or content.

## Retention

The Go core keeps a 500-entry in-memory ring buffer for NoAd blocked events. Flutter mirrors snapshots in memory for the UI. Events are not written to disk by default and are cleared when the core/VPN service shuts down.

Detailed Mihomo logging is controlled by the user-facing NoAd switch. When enabled, NoAd applies debug log level through the generated runtime configuration. When disabled, the original log-level setting from the user configuration is used again. Logs remain bounded by the existing in-memory log list.

## Exports and crash reporting

Diagnostics export hashes event IDs, hosts, and package names. Raw JSONL export requires explicit user confirmation and is created locally through the system file picker.

Firebase Analytics and Crashlytics are present for compatibility with the Android app, but Android metadata disables collection by default. NoAd must not upload blocked-event records in normal builds or runtime flows.

## Known limitations

NoAd does not promise 100% ad removal. It cannot reliably block first-party ads, native in-app ads that share application domains, server-side inserted ads, or traffic hidden behind application-specific DoH/DoT behavior when the visible domain cannot be matched by the VPN/TUN rule layer.