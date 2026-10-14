import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/bolt_data.dart';

/// Keeps the whole app state in one JSON file on the device. Writes are
/// debounced and atomic (temp file + rename) so a crash never leaves half a
/// file behind.
class BoltRepository {
  BoltRepository(this._file);

  /// No persistence, for tests.
  BoltRepository.memory() : _file = null;

  final File? _file;
  Timer? _debounce;
  BoltData? _pending;

  static Future<BoltRepository> open() async {
    final dir = await getApplicationSupportDirectory();
    return BoltRepository(File('${dir.path}/bolt.json'));
  }

  BoltData? load() {
    final f = _file;
    if (f == null || !f.existsSync()) return null;
    try {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      // Version 1 only ever held the built-in demo; start those phones fresh.
      if (json['version'] != BoltData.version) return null;
      return BoltData.fromJson(json);
    } catch (e) {
      debugPrint('Bolt: could not read saved data, starting fresh ($e)');
      return null;
    }
  }

  void scheduleSave(BoltData d) {
    if (_file == null) return;
    _pending = d;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), flush);
  }

  /// Writes any pending change now, e.g. when the app goes to background.
  void flush() {
    _debounce?.cancel();
    final f = _file, d = _pending;
    if (f == null || d == null) return;
    _pending = null;
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(d.toJson()), flush: true);
    tmp.renameSync(f.path);
  }
}
