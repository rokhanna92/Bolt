import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:web/web.dart' as web;

import 'files.dart';

// The parts of dart:io that Bolt uses, for the browser, where dart:io does not
// exist. Files importing dart:io swap to this with a conditional import, so
// the Android code stays exactly as it was. File and gzip work for real, and
// HttpClient goes through fetch. What only the APK updater needs throws: the
// updater never runs here.

abstract final class Platform {
  static const isAndroid = false;
}

/// Same format as dart:io's gzip, so codes pass between phones and browsers.
const gzip = _WebGzip();

class _WebGzip {
  const _WebGzip();

  List<int> encode(List<int> bytes) => GZipEncoder().encodeBytes(bytes);

  List<int> decode(List<int> bytes) => GZipDecoder().decodeBytes(bytes);
}

class File {
  File(this.path);

  final String path;

  bool existsSync() => WebFiles.has(path);

  String readAsStringSync() => WebFiles.read(path) ?? (throw StateError('No file at $path'));

  Future<bool> exists() async => existsSync();

  Future<String> readAsString() async => readAsStringSync();

  Future<File> writeAsString(String text, {bool flush = false}) async {
    WebFiles.write(path, text);
    return this;
  }

  Future<File> rename(String to) async {
    WebFiles.move(path, to);
    return File(to);
  }

  Future<File> delete() async {
    deleteSync();
    return this;
  }

  void deleteSync() => WebFiles.delete(path);

  /// Bytes only ever go to temporary files on a phone: see sharePng.
  Future<File> writeAsBytes(List<int> bytes) => throw UnsupportedError('No byte files in the browser');

  /// Only the APK updater writes in pieces.
  StreamSink<List<int>> openWrite() => throw UnsupportedError('No APK downloads in the browser');
}

/// Only the APK updater uses folders, and a browser's files need none.
class Directory {
  Directory(this.path);

  final String path;

  bool existsSync() => false;

  void deleteSync({bool recursive = false}) {}

  void createSync({bool recursive = false}) {}
}

abstract final class HttpHeaders {
  static const acceptHeader = 'accept';
}

class ContentType {
  const ContentType._(this.value);

  final String value;

  static const json = ContentType._('application/json; charset=utf-8');
}

class RequestHeaders {
  final _values = <String, String>{};

  void set(String name, Object value) => _values[name] = '$value';

  set contentType(ContentType? type) {
    if (type != null) _values['content-type'] = type.value;
  }
}

class HttpClient {
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  Future<HttpClientRequest> openUrl(String method, Uri url) async => HttpClientRequest._(method, url);
}

class HttpClientRequest {
  HttpClientRequest._(this._method, this._url);

  final String _method;
  final Uri _url;
  final headers = RequestHeaders();
  final _body = StringBuffer();

  void write(Object? text) => _body.write(text);

  Future<HttpClientResponse> close() async {
    final head = web.Headers();
    headers._values.forEach((name, value) {
      // Browsers send their own User-Agent.
      if (name.toLowerCase() != 'user-agent') head.append(name, value);
    });
    final res = await web.window
        .fetch(
          _url.toString().toJS,
          web.RequestInit(method: _method, headers: head, body: _body.isEmpty ? null : _body.toString().toJS),
        )
        .toDart;
    final bytes = await res.arrayBuffer().toDart;
    return HttpClientResponse._(res.status, bytes.toDart.asUint8List());
  }
}

class HttpClientResponse extends Stream<List<int>> {
  HttpClientResponse._(this.statusCode, this._bytes);

  final int statusCode;
  final Uint8List _bytes;

  int get contentLength => _bytes.length;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}
