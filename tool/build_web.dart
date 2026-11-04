import 'dart:convert';
import 'dart:io';

/// Builds the PWA into build/web and fills in its service worker with this
/// build's files and a version made from their contents.
///
///   dart run tool/build_web.dart
Future<void> main() async {
  final flutter = await Process.start('flutter', [
    'build',
    'web',
    '--release',
    '--no-web-resources-cdn', // CanvasKit ships with Bolt, for working offline.
    '--pwa-strategy=none', // Flutter's own service worker is deprecated; web/sw.js replaces it.
  ], mode: ProcessStartMode.inheritStdio);
  final code = await flutter.exitCode;
  if (code != 0) exit(code);

  final root = Directory('build/web');
  final files = <String>[];
  var version = 0xcbf29ce484222325;
  void hash(List<int> bytes) {
    for (final b in bytes) {
      version = (version ^ b) * 0x100000001b3;
    }
  }

  final entries = root.listSync(recursive: true).whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final f in entries) {
    final path = f.path.substring(root.path.length + 1).replaceAll(r'\', '/');
    if (path == 'sw.js') continue;
    hash(utf8.encode(path));
    hash(f.readAsBytesSync());
    if (_skip(path)) continue;
    files.add(path);
  }

  final worker = File('build/web/sw.js');
  worker.writeAsStringSync(
    worker
        .readAsStringSync()
        .replaceFirst('__BOLT_VERSION__', version.toRadixString(36))
        .replaceFirst("['__BOLT_FILES__']", const JsonEncoder.withIndent('  ').convert(files)),
  );
  stdout.writeln('Service worker ${version.toRadixString(36)} with ${files.length} files.');
}

/// The worker fetches one CanvasKit, the plain one or Chrome's. The other
/// variants belong to the WebAssembly build, which Bolt does not use.
bool _skip(String path) =>
    path == 'flutter.js' ||
    path == '.last_build_id' ||
    path.endsWith('.symbols') ||
    (path.startsWith('canvaskit/') &&
        path != 'canvaskit/canvaskit.js' &&
        path != 'canvaskit/canvaskit.wasm' &&
        !path.startsWith('canvaskit/chromium/'));
