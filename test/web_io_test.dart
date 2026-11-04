@TestOn('browser')
library;

import 'dart:convert';

import 'package:bolt/data/models/bolt_data.dart';
import 'package:bolt/data/repositories/bolt_repository.dart';
import 'package:bolt/data/seed/content.dart';
import 'package:bolt/web/files.dart';
import 'package:bolt/web/io.dart';
import 'package:bolt/web/paths.dart';
import 'package:flutter_test/flutter_test.dart';

// The browser's stand-ins for dart:io and path_provider. Run with
// flutter test --platform chrome test/web_io_test.dart

void main() {
  test('files save, rename and delete', () async {
    await WebFiles.open();
    final tmp = File('t/a.tmp');
    await tmp.writeAsString('hello');
    expect(tmp.existsSync(), isTrue);
    await tmp.rename('t/a');
    expect(tmp.existsSync(), isFalse);
    expect(File('t/a').readAsStringSync(), 'hello');
    await File('t/a').delete();
    expect(await File('t/a').exists(), isFalse);
  });

  test('the repository saves and loads through IndexedDB', () async {
    final repo = await BoltRepository.open();
    final BoltData data = freshData();
    repo.scheduleSave(data);
    repo.flush();
    await repo.saved;
    expect(File('support/bolt.json').existsSync(), isTrue);
    expect(repo.load(), isNotNull);
    expect(await getTemporaryDirectory(), isA<Directory>());
    await File('support/bolt.json').delete();
  });

  test('gzip is real gzip', () {
    final bytes = utf8.encode('bolt ' * 200);
    final packed = gzip.encode(bytes);
    expect(packed.length, lessThan(bytes.length));
    expect(packed.take(2), [0x1f, 0x8b]);
    expect(gzip.decode(packed), bytes);
  });

  test('HttpClient fetches', () async {
    final req = await HttpClient().getUrl(Uri.parse('data:text/plain,hello'));
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), 'hello');
  });
}
