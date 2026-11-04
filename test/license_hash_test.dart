import 'package:bolt/data/licenses.dart';
import 'package:flutter_test/flutter_test.dart';

/// Made-up codes, none of them a key. The expected values were worked out
/// with plain 64-bit FNV-1a, so this also runs in a browser (ints stop at 53
/// bits there) and catches any drift between the phone and the web.
const _vectors = {
  '': '062c1cd59ec08dc6',
  'ABC': '689c6229e7280c32',
  'not-a-key-1': '8e9246980df98614',
  'zzzz 9999': 'ae8bbd26d8131eea',
};

void main() {
  test('hashes match plain 64-bit FNV-1a', () {
    _vectors.forEach((code, hash) => expect(licenseHash(code), hash, reason: code));
  });

  test('case, spaces and dashes do not matter', () {
    expect(licenseHash('ab-c 12'), licenseHash('ABC12'));
  });

  test('made-up codes open nothing', () {
    for (final code in _vectors.keys) {
      expect(checkLicense(code), isNull);
      expect(keyName(code), isNull);
    }
  });
}
