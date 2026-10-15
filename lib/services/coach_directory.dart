import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Licensed coaches, listed by the app's owner in coaches.json in Bolt's
/// repo. Editing that file updates every phone's list without a release.
const kCoachDirectory = 'https://raw.githubusercontent.com/rokhanna92/Bolt/main/coaches.json';

class ListedCoach {
  const ListedCoach(this.name, this.specialty);

  final String name;

  /// Empty when the list gives none.
  final String specialty;
}

/// Coaches with a name, in file order. Anything else is skipped.
List<ListedCoach> parseCoaches(Object? json) => [
  if (json is List)
    for (final c in json)
      if (c is Map && c['name'] is String && (c['name'] as String).trim().isNotEmpty)
        ListedCoach((c['name'] as String).trim(), c['specialty'] is String ? (c['specialty'] as String).trim() : ''),
];

class CoachDirectory {
  CoachDirectory({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  /// The list, or null when it cannot be loaded.
  Future<List<ListedCoach>?> fetch() async {
    try {
      const wait = Duration(seconds: 15);
      final req = await _client.getUrl(Uri.parse(kCoachDirectory)).timeout(wait);
      final res = await req.close().timeout(wait);
      final body = await res.transform(utf8.decoder).join().timeout(wait);
      return res.statusCode == 200 ? parseCoaches(jsonDecode(body)) : null;
    } catch (_) {
      return null;
    }
  }
}

final coachDirectoryProvider = Provider<CoachDirectory>((ref) => CoachDirectory());

/// Fetched while a screen shows it, again on the next visit.
final listedCoachesProvider = FutureProvider.autoDispose<List<ListedCoach>?>(
  (ref) => ref.read(coachDirectoryProvider).fetch(),
);
