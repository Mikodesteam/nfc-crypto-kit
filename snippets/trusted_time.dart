// Excerpt from NFC Crypto (apps/nfc_crypto/lib/core/nfc/trusted_time.dart). Shown for illustration only.
// The full source code is available at https://store.mikodes.com/p/nfccrypto/
//
// Network time for waits that must not be skipped by changing the phone clock, such as the
// 72-hour "lost card" switch-off. It reads the Date header of a few HTTPS hosts and takes the
// median. If nothing answers it returns null and the caller refuses to finish the wait.

import 'dart:async';

import 'package:http/http.dart' as http;

/// Current time from the network, for waits that must not be skipped by
/// changing the phone's clock (the 72-hour "lost card" switch-off).
///
/// Reads the `Date` header of a few well-known HTTPS sites and takes the
/// median. Returns null when none answers: callers then refuse to finish the
/// wait rather than trust the device clock.
class TrustedTime {
  TrustedTime({http.Client? client, List<Uri>? sources})
      : _client = client,
        _sources = sources ?? _defaultSources;

  final http.Client? _client;
  final List<Uri> _sources;

  static final List<Uri> _defaultSources = <Uri>[
    Uri.parse('https://www.google.com/generate_204'),
    Uri.parse('https://www.cloudflare.com/'),
    Uri.parse('https://www.apple.com/'),
  ];

  Future<DateTime?> now() async {
    final client = _client ?? http.Client();
    try {
      final results = await Future.wait(
        _sources.map((uri) => _dateFrom(client, uri)),
      );
      final dates = results.whereType<DateTime>().toList()..sort();
      if (dates.isEmpty) return null;
      return dates[dates.length ~/ 2];
    } finally {
      if (_client == null) client.close();
    }
  }

  static Future<DateTime?> _dateFrom(http.Client client, Uri uri) async {
    try {
      final response =
          await client.head(uri).timeout(const Duration(seconds: 8));
      final header = response.headers['date'];
      return header == null ? null : parseHttpDate(header);
    } catch (_) {
      return null;
    }
  }

  // _months: the lowercase three-letter month names, jan to dec

  /// Parses an RFC 7231 IMF-fixdate: `Sun, 06 Nov 1994 08:49:37 GMT`.
  static DateTime? parseHttpDate(String value) {
    final m = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value.trim());
    if (m == null) return null;
    final month = _months.indexOf(m.group(2)!.toLowerCase()) + 1;
    if (month == 0) return null;
    return DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }
}
