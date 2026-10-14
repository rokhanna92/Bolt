import 'dart:convert';
import 'dart:io' show gzip;

/// Plans and updates travel between phones as a short code inside a normal
/// message (WhatsApp, email, anything that carries text). There is no server:
/// the coach shares a plan, the trainee pastes it into Bolt, and their update
/// goes back the same way.
abstract final class ShareCode {
  static const _prefix = 'BOLT1.';
  static final _pattern = RegExp(r'BOLT1\.[A-Za-z0-9_\-]+=*');

  static String encode(Map<String, dynamic> packet) =>
      _prefix + base64Url.encode(gzip.encode(utf8.encode(jsonEncode(packet))));

  /// Finds and decodes the first code in [text], or null if there is none or
  /// it is damaged.
  static Map<String, dynamic>? decode(String text) {
    final m = _pattern.firstMatch(text);
    if (m == null) return null;
    try {
      final raw = gzip.decode(base64Url.decode(m.group(0)!.substring(_prefix.length)));
      final json = jsonDecode(utf8.decode(raw));
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  static bool contains(String text) => _pattern.hasMatch(text);
}
