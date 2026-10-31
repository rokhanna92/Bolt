import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Where Bolt's releases are published.
const kReleasesApi = 'https://api.github.com/repos/rokhanna92/Bolt/releases/latest';

/// A published release, reduced to what an update needs.
class Release {
  const Release({
    required this.title,
    required this.version,
    required this.build,
    required this.notes,
    required this.apkUrl,
    required this.apkBytes,
  });

  final String title;

  /// "1.2.0".
  final String version;

  /// Android versionCode from the tag's "+N"; null when the tag has none.
  final int? build;
  final String notes;
  final String apkUrl;
  final int apkBytes;
}

/// What is installed: version name and versionCode.
class Installed {
  const Installed(this.version, this.build);

  final String version;
  final int? build;

  String get label => version.isEmpty ? 'Bolt' : 'Bolt $version';
}

sealed class CheckResult {
  const CheckResult();
}

class UpToDate extends CheckResult {
  const UpToDate();
}

class UpdateFound extends CheckResult {
  const UpdateFound(this.release);

  final Release release;
}

/// [message] is written for the user.
class CheckFailed extends CheckResult {
  const CheckFailed(this.message);

  final String message;
}

class UpdateError implements Exception {
  const UpdateError(this.message);

  final String message;

  @override
  String toString() => message;
}

final _tag = RegExp(r'^v?(\d+(?:\.\d+)*)(?:\+(\d+))?$', caseSensitive: false);

/// "v1.2.0+3" -> ("1.2.0", 3). Null when the tag is not a version.
(String, int?)? parseTag(String tag) {
  final m = _tag.firstMatch(tag.trim());
  if (m == null) return null;
  return (m.group(1)!, m.group(2) == null ? null : int.parse(m.group(2)!));
}

/// Compares dotted versions as numbers, so 1.10.0 is newer than 1.9.0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [for (final p in v.split('.')) int.tryParse(p) ?? 0];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
    final l = i < x.length ? x[i] : 0, r = i < y.length ? y[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

/// Split-per-ABI APKs report versionCode as `abi * 1000 + build` (arm64 is
/// 2, so build 3 installs as 2003). The release tag carries the plain build.
int? plainBuild(int? versionCode) => versionCode == null ? null : versionCode % 1000;

/// The build number decides when both sides have one; otherwise the name.
bool isNewer(Release r, Installed i) {
  final mine = plainBuild(i.build);
  if (r.build != null && mine != null) return r.build! > mine;
  return compareVersions(r.version, i.version) > 0;
}

/// The APK to download from a release's assets: arm64 first (every current
/// phone), else the first APK.
({String url, int bytes})? pickApk(Object? assets) {
  if (assets is! List) return null;
  ({String url, int bytes})? first;
  for (final a in assets) {
    if (a is! Map) continue;
    final name = a['name'], url = a['browser_download_url'], size = a['size'];
    if (name is! String || url is! String || !name.toLowerCase().endsWith('.apk')) continue;
    final apk = (url: url, bytes: size is num ? size.toInt() : 0);
    if (name.toLowerCase().contains('arm64')) return apk;
    first ??= apk;
  }
  return first;
}

/// Release notes are Markdown; this keeps them readable as plain text.
String plainNotes(String md) {
  final lines = <String>[];
  for (var l in md.replaceAll('\r', '').split('\n')) {
    l = l.replaceAll('**', '').replaceAll('`', '').replaceFirst(RegExp(r'^#+\s*'), '');
    l = l.replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ');
    lines.add(l.trimRight());
  }
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Checks GitHub for a newer Bolt, downloads it and opens the installer.
class Updater {
  Updater({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;
  static const _channel = MethodChannel('bolt/updates');

  Future<Installed> installed() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return Installed(info.version, int.tryParse(info.buildNumber));
    } catch (_) {
      return const Installed('', null);
    }
  }

  Future<CheckResult> check() async {
    final mine = await installed();
    final Object? json;
    try {
      final req = await _client.getUrl(Uri.parse(kReleasesApi)).timeout(const Duration(seconds: 20));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 404) return const CheckFailed('No release is published yet.');
      if (res.statusCode == 403) return const CheckFailed('GitHub is busy right now. Try again in a few minutes.');
      if (res.statusCode != 200) return CheckFailed('GitHub answered ${res.statusCode}. Try again in a moment.');
      json = jsonDecode(body);
    } on TimeoutException {
      return const CheckFailed('No answer from GitHub. Check your connection and try again.');
    } catch (_) {
      return const CheckFailed('Could not reach GitHub. Check your connection and try again.');
    }
    if (json is! Map<String, dynamic>) return const CheckFailed('GitHub sent something Bolt could not read.');
    final tag = parseTag(json['tag_name'] as String? ?? '');
    if (tag == null) return const CheckFailed('The latest release has no version number Bolt can compare.');
    final apk = pickApk(json['assets']);
    final release = Release(
      title: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : 'Bolt ${tag.$1}',
      version: tag.$1,
      build: tag.$2,
      notes: plainNotes(json['body'] as String? ?? ''),
      apkUrl: apk?.url ?? '',
      apkBytes: apk?.bytes ?? 0,
    );
    if (!isNewer(release, mine)) return const UpToDate();
    if (apk == null) return CheckFailed('Version ${tag.$1} has no app file attached yet.');
    return UpdateFound(release);
  }

  /// Downloads into the cache folder the installer is allowed to read.
  Future<File> download(Release r, {void Function(double)? onProgress}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final file = File('${dir.path}/bolt-${r.version}.apk');
    try {
      final req = await _client.getUrl(Uri.parse(r.apkUrl)).timeout(const Duration(seconds: 30));
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw UpdateError('The download failed (${res.statusCode}). Try again.');
      }
      final total = res.contentLength > 0 ? res.contentLength : r.apkBytes;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress?.call((got / total).clamp(0, 1).toDouble());
      }
      await sink.close();
      final expected = r.apkBytes > 0 ? r.apkBytes : total;
      if (expected > 0 && got != expected) {
        throw UpdateError('The download stopped early ($got of $expected bytes). Try again.');
      }
      return file;
    } on UpdateError {
      if (file.existsSync()) file.deleteSync();
      rethrow;
    } catch (_) {
      if (file.existsSync()) file.deleteSync();
      throw const UpdateError('The download failed. Check your connection and try again.');
    }
  }

  /// Starts Android's daily check for a new version while Bolt is closed
  /// (UpdateCheckJob) and gives it the notification texts in the app
  /// language. Safe to call on every start.
  Future<bool> watch({required String title, required String body, required String channel}) =>
      _ask('watch', {'title': title, 'body': body, 'channel': channel});

  Future<bool> canInstall() => _ask('canInstall');

  Future<bool> openInstallSettings() => _ask('openInstallSettings');

  /// Opens Android's installer for [apk]; the user confirms there.
  Future<bool> install(File apk) => _ask('install', {'path': apk.path});

  Future<bool> _ask(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } catch (_) {
      return false;
    }
  }
}
