import 'files.dart';
import 'io.dart';

// Stands in for path_provider, which has no browser version. Paths are only
// names here: the files live in IndexedDB, opened by the first call.

Future<Directory> getApplicationSupportDirectory() async {
  await WebFiles.open();
  return Directory('support');
}

Future<Directory> getTemporaryDirectory() async => Directory('temp');
