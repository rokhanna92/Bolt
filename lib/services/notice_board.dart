import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/board.dart';

/// The owner's pushes for every phone, in notices.json in Bolt's repo, like
/// coaches.json. Phones read it when Bolt opens; the admin screen writes it
/// through GitHub with the owner's token.
const kNoticeBoard = 'https://raw.githubusercontent.com/rokhanna92/Bolt/main/notices.json';
const _api = 'https://api.github.com/repos/rokhanna92/Bolt/contents/notices.json';

class NoticeBoard {
  NoticeBoard({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;
  static const _wait = Duration(seconds: 15);

  /// The published board, or null when it cannot be read.
  Future<Board?> fetch() async {
    try {
      final req = await _client.getUrl(Uri.parse('$kNoticeBoard?t=${DateTime.now().millisecondsSinceEpoch}'));
      final res = await req.close().timeout(_wait);
      final body = await res.transform(utf8.decoder).join().timeout(_wait);
      return res.statusCode == 200 ? Board.fromJson(jsonDecode(body)) : null;
    } catch (_) {
      return null;
    }
  }

  /// Writes [b] to the repo as a commit. Null when it worked, otherwise
  /// what went wrong, for the screen.
  Future<String?> publish(Board b, String token) async {
    try {
      Future<HttpClientResponse> call(String method, [Object? json]) async {
        final req = await _client.openUrl(method, Uri.parse(_api)).timeout(_wait);
        req.headers
          ..set('Authorization', 'Bearer $token')
          ..set('Accept', 'application/vnd.github+json')
          ..set('User-Agent', 'Bolt');
        if (json != null) {
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(json));
        }
        return req.close().timeout(_wait);
      }

      final head = await call('GET');
      final current = await head.transform(utf8.decoder).join();
      if (head.statusCode == 401 || head.statusCode == 403) return 'token';
      final sha = head.statusCode == 200 ? (jsonDecode(current) as Map)['sha'] as String? : null;
      final text = '${const JsonEncoder.withIndent('  ').convert(b.toJson())}\n';
      final put = await call('PUT', {
        'message': 'Update notices',
        'content': base64Encode(utf8.encode(text)),
        'branch': 'main',
        'sha': ?sha,
      });
      await put.drain<void>();
      if (put.statusCode == 200 || put.statusCode == 201) return null;
      return put.statusCode == 401 || put.statusCode == 403 || put.statusCode == 404 ? 'token' : 'http';
    } catch (_) {
      return 'offline';
    }
  }

  /// The owner's GitHub token: in its own file on this phone, never in
  /// backups or shared plans.
  Future<File> _tokenFile() async => File('${(await getApplicationSupportDirectory()).path}/github_token');

  Future<String?> token() async {
    try {
      final f = await _tokenFile();
      final t = (await f.exists()) ? (await f.readAsString()).trim() : '';
      return t.isEmpty ? null : t;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String? t) async {
    try {
      final f = await _tokenFile();
      if (t == null || t.trim().isEmpty) {
        if (await f.exists()) await f.delete();
      } else {
        await f.writeAsString(t.trim());
      }
    } catch (_) {}
  }
}

final noticeBoardProvider = Provider<NoticeBoard>((ref) => NoticeBoard());
