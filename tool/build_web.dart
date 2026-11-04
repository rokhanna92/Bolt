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
    '--wasm', // Falls back to JavaScript by itself on browsers without WasmGC.
    '--no-web-resources-cdn', // The engine ships with Bolt, for working offline.
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

/// Only what can be needed up front: web/sw.js picks one engine from these.
/// Anything else is fetched and kept if a browser ever asks for it.
bool _skip(String path) {
  const engines = {
    'canvaskit/canvaskit.js',
    'canvaskit/canvaskit.wasm',
    'canvaskit/chromium/canvaskit.js',
    'canvaskit/chromium/canvaskit.wasm',
    'canvaskit/skwasm.js',
    'canvaskit/skwasm.wasm',
    'canvaskit/skwasm_heavy.js',
    'canvaskit/skwasm_heavy.wasm',
  };
  if (path.startsWith('canvaskit/')) return !engines.contains(path);
  return const {
        'flutter.js',
        'flutter_service_worker.js',
        'version.json',
        '.last_build_id',
        '_headers',
        'assets/NOTICES',
      }.contains(path) ||
      path.startsWith('assets/packages/flutter_local_notifications_web/');
}
