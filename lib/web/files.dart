import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// What a phone keeps in files, kept in the browser's IndexedDB. Everything is
/// read into memory once at startup, because Bolt reads its save synchronously.
abstract final class WebFiles {
  static const _store = 'files';
  static final _memory = <String, String>{};
  static web.IDBDatabase? _db;
  static Future<void>? _opening;

  /// Loads every saved file. Safe to call more than once. Without IndexedDB
  /// Bolt still runs, but nothing outlives the page.
  static Future<void> open() => _opening ??= _open();

  static Future<void> _open() async {
    try {
      final done = Completer<web.IDBDatabase>();
      final request = web.window.indexedDB.open('bolt', 1);
      request.onupgradeneeded = ((web.Event _) {
        (request.result as web.IDBDatabase).createObjectStore(_store);
      }).toJS;
      request.onsuccess = ((web.Event _) => done.complete(request.result as web.IDBDatabase)).toJS;
      request.onerror = ((web.Event _) => done.completeError('Could not open IndexedDB')).toJS;
      final db = await done.future;

      final store = db.transaction(_store.toJS).objectStore(_store);
      final keys = store.getAllKeys();
      final values = store.getAll();
      final loaded = Completer<void>();
      values.onsuccess = ((web.Event _) => loaded.complete()).toJS;
      values.onerror = ((web.Event _) => loaded.completeError('Could not read IndexedDB')).toJS;
      await loaded.future;
      final k = (keys.result as JSArray<JSString>).toDart;
      final v = (values.result as JSArray<JSString>).toDart;
      for (var i = 0; i < k.length; i++) {
        _memory[k[i].toDart] = v[i].toDart;
      }
      _db = db;
    } catch (_) {
      _db = null;
    }
  }

  static bool has(String path) => _memory.containsKey(path);

  static String? read(String path) => _memory[path];

  // Each change goes to IndexedDB at once rather than after an await, so a
  // phone closing Bolt straight after a save does not lose it.

  static void write(String path, String text) {
    _memory[path] = text;
    _writable()?.put(text.toJS, path.toJS);
  }

  static void delete(String path) {
    _memory.remove(path);
    _writable()?.delete(path.toJS);
  }

  /// One transaction, so the save is never half moved.
  static void move(String from, String to) {
    final text = _memory.remove(from);
    if (text == null) return;
    _memory[to] = text;
    _writable()
      ?..put(text.toJS, to.toJS)
      ..delete(from.toJS);
  }

  static web.IDBObjectStore? _writable() => _db?.transaction(_store.toJS, 'readwrite').objectStore(_store);
}
